--[[
  Trackside dashboard widget.

  Layout is a grid of boxes, in the style of the rfsuite dashboard. Phase 2
  swaps this for a themeable engine (pre-race / racing / post-race layouts).

  Hot-path rules (see CLAUDE.md, same as rfsuite/wfsuite):
    - wakeup reads numbers, quantises them, and only formats a string when the
      shown value changes; paint only draws cached strings.
    - lcd.invalidate() only when something visible changed.
    - box rectangles are computed once per window size.
]]

local core = trackside.core
local settings = trackside.settings
local telemetry = trackside.telemetry
local battery = trackside.battery

local floor, abs = math.floor, math.abs
local format = string.format

local COLS, ROWS, PAD = 12, 8, 4
local TEXT_EVERY = 0.2      -- s, numbers and labels
local SCOPE_EVERY = 0.05    -- s, live throttle/steer bar
local THEME_EVERY = 1.0     -- s, re-read Ethos theme colours

-- Screen size never changes at runtime: read it once.
local LCD_W, LCD_H
do
    local v = system.getVersion()
    LCD_W, LCD_H = v.lcdWidth or 800, v.lcdHeight or 480
end

-- Like the rfsuite dashboard: the header row only shows when the widget fills
-- the whole screen. Otherwise Ethos already shows the model name and status.
local function isFullScreen(W, H)
    return W >= LCD_W - 4 and H >= LCD_H - 4
end

-- --- colours ---------------------------------------------------------------
local C = { letter = {} }

local function themed(key, fallback)
    if lcd.themeColor and key then
        local ok, c = pcall(lcd.themeColor, key)
        if ok and c then return c end
    end
    return fallback
end

-- Returns true if any surface colour changed (theme switched).
local function colors()
    local bg = themed(THEME_PAGE_BGCOLOR, lcd.RGB(16, 18, 22))
    local changed = bg ~= C.bg
    C.bg = bg
    C.box = themed(THEME_DEFAULT_BGCOLOR, lcd.RGB(32, 36, 44))
    C.title = themed(THEME_SECONDARY_COLOR, lcd.RGB(150, 156, 168))
    C.text = themed(THEME_DEFAULT_COLOR, lcd.RGB(240, 240, 240))
    C.off = themed(THEME_DISABLE_COLOR, lcd.RGB(70, 74, 84))
    -- Status colours are ours: they mean the same thing on every theme.
    C.throttle = lcd.RGB(64, 210, 110)
    C.brake = lcd.RGB(235, 70, 60)
    C.warn = lcd.RGB(255, 176, 32)
    C.letter.A = C.brake                      -- ABS
    C.letter.T = C.throttle                   -- traction
    C.letter.S = C.warn                       -- steer cut
    C.letter.C = lcd.RGB(200, 110, 255)       -- corner brake
    C.letter.D = lcd.RGB(60, 170, 255)        -- steer limit
    return changed
end

-- Battery % colour: green, amber under 50%, red under 20%.
local function battColor()
    local p = battery.pct
    if not p then return nil end
    if p < 20 then return C.brake elseif p < 50 then return C.warn end
    return C.throttle
end

-- --- boxes -------------------------------------------------------------------
-- src returns a number (or string) or nil; q = display step used for change
-- detection; pattern formats the number. Text is rebuilt only on change.
local function modelName() return (model.name and model.name()) or "VX10" end
local function cellsLabel() return battery.cells end

local boxes = {
    -- header (full screen only)
    { c = 0, r = 0, w = 6, h = 1, header = true, font = FONT_L, left = true, src = modelName },
    { c = 6, r = 0, w = 2, h = 1, header = true, font = FONT_STD, title = "LQ", src = function() return telemetry.get("lq") end, q = 1, pattern = "%d%%" },
    { c = 8, r = 0, w = 2, h = 1, header = true, font = FONT_STD, title = "TX", src = function() return telemetry.get("txbatt") end, q = 0.1, pattern = "%.1fV" },
    { c = 10, r = 0, w = 2, h = 1, header = true, font = FONT_STD, title = "PWR", src = function() return telemetry.get("txpower") end, q = 1, pattern = "%dmW" },

    -- left: battery
    { c = 0, r = 1, w = 6, h = 3, title = "PACK", font = FONT_XXL, color = battColor,
      src = function() return battery.pack end, q = 0.01, pattern = "%.2fV",
      sub = cellsLabel, subPattern = "%dS" },
    { c = 0, r = 4, w = 2, h = 2, title = "CELL", src = function() return battery.cell end, q = 0.01, pattern = "%.2f" },
    { c = 2, r = 4, w = 2, h = 2, title = "BATT", color = battColor, src = function() return battery.pct end, q = 1, pattern = "%d%%" },
    { c = 4, r = 4, w = 2, h = 2, title = "MIN", src = function() return battery.min end, q = 0.01, pattern = "%.2f" },

    -- right: laps (lap timer not built yet)
    { c = 6, r = 1, w = 6, h = 3, title = "CUR", font = FONT_XXL, src = function() return "0:00.0" end },
    { c = 6, r = 4, w = 2, h = 2, title = "L1" },
    { c = 8, r = 4, w = 2, h = 2, title = "BEST" },
    { c = 10, r = 4, w = 2, h = 2, title = "LAP", src = function() return 0 end, q = 1, pattern = "%d" },

    -- footer: aid letters (or timer) + live scope
    { c = 0, r = 6, w = 6, h = 2, kind = "letters" },
    { c = 6, r = 6, w = 6, h = 2, kind = "scope" },
}

for _, b in ipairs(boxes) do
    b.text = "--"
    b.key = false        -- last quantised value shown
    b.subText = nil
    b.subKey = false
end

-- Quantise a value so tiny changes (sensor noise) don't cause a redraw.
local function quantise(v, q)
    if type(v) ~= "number" or not q then return v end
    return floor(v / q + 0.5)
end

-- Update one box's cached text. Returns true if it changed.
local function refreshBox(b)
    local changed = false
    if b.src then
        local v = b.src()
        local k = quantise(v, b.q)
        if k ~= b.key then
            b.key = k
            if v == nil then
                b.text = "--"
            elseif type(v) == "number" then
                -- k * q keeps integers integral, so "%d" patterns are safe
                b.text = format(b.pattern or "%s", b.q and k * b.q or v)
            else
                b.text = v
            end
            changed = true
        end
    end
    if b.sub then
        local v = b.sub()
        if v ~= b.subKey then
            b.subKey = v
            b.subText = v and format(b.subPattern or "%s", v) or nil
            changed = true
        end
    end
    if b.color then
        local c = b.color()
        if c ~= b.colorKey then
            b.colorKey = c
            changed = true
        end
    end
    return changed
end

-- --- layout (once per window size) ------------------------------------------
local layoutW, layoutH, layoutFull = nil, nil, nil

local function layout(W, H)
    if W == layoutW and H == layoutH then return end
    layoutW, layoutH = W, H
    layoutFull = isFullScreen(W, H)
    local rowShift = layoutFull and 0 or 1
    local rows = ROWS - rowShift
    local cw, rh = W / COLS, H / rows
    for _, b in ipairs(boxes) do
        local r = b.r - rowShift
        b.x = floor(b.c * cw) + PAD
        b.y = floor(r * rh) + PAD
        b.w = floor(b.w0 * cw) - 2 * PAD
        b.h = floor(b.h0 * rh) - 2 * PAD
    end
end

for _, b in ipairs(boxes) do b.w0, b.h0 = b.w, b.h end

-- --- drawing -----------------------------------------------------------------
local function drawValueBox(b)
    local x, y, w, h = b.x, b.y, b.w, b.h
    lcd.color(C.box)
    lcd.drawFilledRectangle(x, y, w, h)
    local ty = y
    lcd.font(FONT_S)
    if b.title then
        lcd.color(C.title)
        lcd.drawText(x + 6, y + 2, b.title)
        local _, th = lcd.getTextSize(b.title)
        ty = y + th
    end
    if b.subText then
        lcd.color(C.title)
        local sw = lcd.getTextSize(b.subText)
        lcd.drawText(x + w - sw - 6, y + 2, b.subText)
    end
    lcd.font(b.font or FONT_XL)
    lcd.color(b.colorKey or C.text)
    local tw, th = lcd.getTextSize(b.text)
    local cy = ty + floor((y + h - ty - th) / 2)
    if b.left then
        lcd.drawText(x + 8, cy, b.text)
    else
        lcd.drawText(x + floor((w - tw) / 2), cy, b.text)
    end
end

local LETTERS = { "A", "T", "S", "C", "D" }

local function drawLetters(b)
    local x, y, w, h = b.x, b.y, b.w, b.h
    lcd.color(C.box)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.font(FONT_XL)
    local cell = w / #LETTERS
    for i = 1, #LETTERS do
        local l = LETTERS[i]
        lcd.color(core.flags[l] and C.letter[l] or C.off)
        local tw, th = lcd.getTextSize(l)
        lcd.drawText(x + floor((i - 0.5) * cell - tw / 2), y + floor((h - th) / 2), l)
    end
end

-- Processed throttle/brake fill from centre (green throttle, red brake),
-- steering tick underneath.
local function drawScope(b)
    local x, y, w, h = b.x, b.y, b.w, b.h
    lcd.color(C.box)
    lcd.drawFilledRectangle(x, y, w, h)
    local mid = x + floor(w / 2)
    local barY, barH = y + floor(h * 0.25), floor(h * 0.35)
    local half = floor(w / 2) - 8

    local thr = core.proc.thr
    -- Brake Direction: NEG (1) means negative stick is brake
    local braking = (settings.get("brakeDir") == 1) == (thr < 0)
    lcd.color(braking and C.brake or C.throttle)
    local len = floor(abs(thr) * half)
    if thr >= 0 then
        lcd.drawFilledRectangle(mid, barY, len, barH)
    else
        lcd.drawFilledRectangle(mid - len, barY, len, barH)
    end

    lcd.color(C.text)
    lcd.drawLine(mid, y + 4, mid, y + h - 4)

    local steer = core.input.steer
    if settings.get("graphDir") == 2 then steer = -steer end
    local sx = mid + floor(steer * half)
    lcd.drawFilledRectangle(sx - 3, barY + barH + 6, 6, 8)
end

-- --- widget callbacks --------------------------------------------------------
local SLIDE_HOLD = 0.35     -- s after the last touch move before redraws resume

local scopeBox, lettersBox
for _, b in ipairs(boxes) do
    if b.kind == "scope" then scopeBox = b elseif b.kind == "letters" then lettersBox = b end
end

local function create()
    colors()
    return { textAt = -math.huge, scopeAt = -math.huge, themeAt = os.clock(),
             thrKey = false, steerKey = false, flagKey = false,
             visible = false, slidingUntil = 0, full = true, pending = {} }
end

local function flagKey()
    local f = core.flags
    return (f.A and 1 or 0) + (f.T and 2 or 0) + (f.S and 4 or 0) + (f.C and 8 or 0) + (f.D and 16 or 0)
end

-- Queue one box for redraw. Boxes are only invalidated as rectangles, never the
-- whole window, so a moving steering tick doesn't repaint the full screen.
local function markBox(widget, b)
    if b.header and not layoutFull then return end
    widget.pending[b] = true
end

local function flush(widget)
    if widget.full then
        widget.full = false
        for b in pairs(widget.pending) do widget.pending[b] = nil end
        lcd.invalidate()
        return
    end
    if not layoutW then return end            -- not laid out yet: first paint is full anyway
    for b in pairs(widget.pending) do
        widget.pending[b] = nil
        lcd.invalidate(b.x, b.y, b.w, b.h)
    end
end

local function wakeup(widget)
    -- Same rule as the rfsuite dashboard: no work while another screen is shown.
    -- The drive aids keep running from the Lua sources regardless.
    if not lcd.isVisible() then
        widget.visible = false
        return
    end
    if not widget.visible then
        widget.visible = true
        widget.full = true                    -- came back into view: redraw everything once
    end

    core.update()
    local now = os.clock()

    if now - widget.themeAt >= THEME_EVERY then
        widget.themeAt = now
        if colors() then widget.full = true end
    end

    if now - widget.textAt >= TEXT_EVERY then
        widget.textAt = now
        battery.update()
        for i = 1, #boxes do
            local b = boxes[i]
            if b.src or b.sub or b.color then
                if refreshBox(b) then markBox(widget, b) end
            end
        end
    end

    if now - widget.scopeAt >= SCOPE_EVERY then
        widget.scopeAt = now
        local t = floor(core.proc.thr * 100 + 0.5)
        local s = floor(core.input.steer * 100 + 0.5)
        if t ~= widget.thrKey or s ~= widget.steerKey then
            widget.thrKey, widget.steerKey = t, s
            markBox(widget, scopeBox)
        end
        local f = flagKey()
        if f ~= widget.flagKey then
            widget.flagKey = f
            markBox(widget, lettersBox)
        end
    end

    -- Hold redraws while the screen is being swiped; flush once it settles.
    if now < widget.slidingUntil then return end
    flush(widget)
end

-- Note touch slides (screen swipes) so wakeup can pause redraws. Never consumes
-- the event: Ethos still handles the swipe.
local function event(widget, category, value, x, y)
    if category == EVT_TOUCH then
        if value == TOUCH_MOVE then
            widget.slidingUntil = os.clock() + SLIDE_HOLD
        elseif value == TOUCH_END then
            widget.slidingUntil = os.clock() + 0.1
        end
    end
    return false
end

-- Set trackside.DEBUG_PAINT = true (main.lua) to log paints per second.
local paintCount, paintLogAt = 0, 0

local function paint(widget)
    if trackside.DEBUG_PAINT then
        paintCount = paintCount + 1
        local now = os.clock()
        if now - paintLogAt >= 2 then
            print(format("[trackside] paints/s %.1f", paintCount / (now - paintLogAt)))
            paintCount, paintLogAt = 0, now
        end
    end
    local W, H = lcd.getWindowSize()
    layout(W, H)
    lcd.color(C.bg)
    lcd.drawFilledRectangle(0, 0, W, H)
    for i = 1, #boxes do
        local b = boxes[i]
        if not (b.header and not layoutFull) then
            if b.kind == "letters" then
                drawLetters(b)
            elseif b.kind == "scope" then
                drawScope(b)
            else
                drawValueBox(b)
            end
        end
    end
end

-- Configure page: all Trackside settings (saved per model, not per widget).
-- The form module is only loaded the first time Configure opens.
local function configure(widget)
    settings.ensureModel(true)
    trackside.getForm().build()
end

local function write(widget)
    trackside.getForm().save()
end

return {
    key = "tshome",
    name = "Trackside",
    create = create,
    wakeup = wakeup,
    paint = paint,
    event = event,
    configure = configure,
    write = write,
    title = false,
}

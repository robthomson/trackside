--[[
  Drive-aid core. Shared by the Throttle Aid / Steer Aid sources and the
  Trackside widget.

  Model mixes keep a raw stick ADD line and multiply it by our output:
      throttle channel: Throttle (Add) x Throttle Aid (Multiply)
      steering channel: Steering (Add) x Steer Aid (Multiply)
  If the script stops, the stick still drives the car directly.

  Processing order (fixed):
      Traction Control -> Steer Cut Throttle -> Corner Brake -> ABS -> Steer Limit

  BOOTSTRAP: every stage is a pass-through for now. The flags/outputs are
  wired so the dashboard and scope can be built against them.
]]

local settings = trackside.settings

local core = {}

-- Live state, read by the dashboard.
core.input = { thr = 0, steer = 0 }          -- raw sticks, -1..1
core.proc = { thr = 0, steer = 0 }           -- after the aid pipeline, -1..1
core.out = { drive = 1.0, strmul = 1.0 }     -- multipliers for the mixes
core.flags = { A = false, T = false, S = false, C = false, D = false }

local STICK_MAX = 1024
local lastTick = nil

local function readStick(key)
    local src = settings.source(key)
    if not src then return 0 end
    local v = src:value() or 0
    v = v / STICK_MAX
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    return v
end

-- Stage stubs: each takes the working state and may set its flag.
local function tractionControl(st) core.flags.T = false end
local function steerCutThrottle(st) core.flags.S = false end
local function cornerBrake(st) core.flags.C = false end
local function absStage(st, now) core.flags.A = false end
local function steerLimit(st) core.flags.D = false end

local function ratio(processed, raw)
    if raw > -0.01 and raw < 0.01 then return 1.0 end
    return processed / raw
end

-- Both sources and the widget call update(); the pipeline runs at most once
-- per MIN_STEP so it isn't repeated within one Ethos loop.
local MIN_STEP = 0.004
local st = { thr = 0, steer = 0, dt = 0 }   -- reused every run (no per-tick allocation)

function core.update()
    local now = os.clock()
    if lastTick and now - lastTick < MIN_STEP then return end
    st.dt = lastTick and (now - lastTick) or 0
    lastTick = now

    settings.ensureModel()

    local thr = readStick("throttleSrc")
    local steer = readStick("steerSrc")
    core.input.thr, core.input.steer = thr, steer

    st.thr, st.steer = thr, steer
    tractionControl(st)
    steerCutThrottle(st)
    cornerBrake(st)
    absStage(st, now)
    steerLimit(st)

    core.proc.thr, core.proc.steer = st.thr, st.steer
    core.out.drive = ratio(st.thr, thr)
    core.out.strmul = ratio(st.steer, steer)
end

return core

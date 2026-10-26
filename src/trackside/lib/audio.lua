--[[
  Spoken alerts. Phrases are WAVs made by bin/audio/generate.py from
  bin/audio/phrases.json; numbers use Ethos's own voice (system.playNumber).

  A phrase is looked up, first match wins:
    SCRIPTS:/trackside.user/audio/<file>        your own recording
    SCRIPTS:/trackside/audio/<radio voice>/<file>   e.g. en/gb
    SCRIPTS:/trackside/audio/en/default/<file>
  The result is cached per phrase, so the file checks happen once.

  audio.say("battery_low")
  audio.number(3.5, UNIT_VOLT, 2)    -- real value; decimals = digits spoken ("3.50 volts")
]]

local BASE = trackside.BASE .. "audio/"
local USER = "SCRIPTS:/trackside.user/audio/"

local audio = {}
local paths = {}      -- phrase -> resolved path (false = none found)
local voice = nil

local function exists(path)
    local f = io.open(path, "r")
    if not f then return false end
    f:close()
    return true
end

local function radioVoice()
    if voice then return voice end
    local v = system.getAudioVoice and system.getAudioVoice() or nil
    v = tostring(v or "en/default")
    v = v:gsub("SD:", ""):gsub("RADIO:", ""):gsub("AUDIO:", ""):gsub("VOICE[1-4]:", ""):gsub("audio/", "")
    if v:sub(1, 1) == "/" then v = v:sub(2) end
    if v == "" then v = "en/default" end
    voice = v
    return v
end

local function resolve(name)
    local p = paths[name]
    if p ~= nil then return p end
    local file = name .. ".wav"
    local candidates = { USER .. file, BASE .. radioVoice() .. "/" .. file, BASE .. "en/default/" .. file }
    p = false
    for i = 1, #candidates do
        if exists(candidates[i]) then
            p = candidates[i]
            break
        end
    end
    paths[name] = p
    return p
end

function audio.say(name)
    local p = resolve(name)
    if p and system.playFile then system.playFile(p) end
end

function audio.number(value, unit, decimals)
    if system.playNumber then system.playNumber(value, unit, decimals) end
end

function audio.haptic(pattern)
    if system.playHaptic then system.playHaptic(pattern) end
end

return audio

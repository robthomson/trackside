--[[
  Telemetry sensors that Trackside makes itself (Ethos DIY sensors), so logic
  switches, alerts, logs and other widgets can read Trackside values.

  diysensor.new(appId, name, opts) -> s
  s:set(v)   push a value; only sent when it changes or every REFRESH seconds
             (Ethos marks a sensor lost ~4 s after its last value)
  s:set(nil) stop sending (the sensor goes lost)

  The sensor is looked up by appId every push, so a model switch finds (or
  creates) the new model's own sensor. appIds are saved in models: never change.
]]

local REFRESH = 1.0

local useRawValue = nil   -- Ethos 26.1+ wants rawValue(), older value()

local function rawSupported()
    if useRawValue == nil then
        local v = system.getVersion()
        useRawValue = v.major > 26 or (v.major == 26 and v.minor >= 1)
    end
    return useRawValue
end

local Sensor = {}
Sensor.__index = Sensor

function Sensor:set(v)
    if v == nil then
        self.last = nil
        return
    end
    local now = os.clock()
    if v == self.last and now - self.at < REFRESH then return end
    local s = system.getSource(self.query)
    if not s then
        s = model.createSensor({ type = SENSOR_TYPE_DIY })
        s:name(self.name)
        s:appId(self.appId)
        s:physId(0)
        s:module(0)
        if self.unit then
            s:unit(self.unit)
            s:protocolUnit(self.unit)
        end
        if self.decimals then
            s:decimals(self.decimals)
            s:protocolDecimals(self.decimals)
        end
        s:minimum(self.min)
        s:maximum(self.max)
    end
    if rawSupported() then s:rawValue(v) else s:value(v) end
    self.last, self.at = v, now
end

local diysensor = {}

function diysensor.new(appId, name, opts)
    opts = opts or {}
    return setmetatable({
        appId = appId,
        name = name,
        unit = opts.unit,
        decimals = opts.decimals,
        min = opts.min or 0,
        max = opts.max or 100,
        query = { category = CATEGORY_TELEMETRY_SENSOR, appId = appId },
        last = nil,
        at = -REFRESH,
    }, Sensor)
end

return diysensor

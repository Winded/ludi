--[[

The MIT License (MIT)

Copyright (c) 2020 Antton Hytönen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

--]]

local function sliceTable(tbl, first, last, step)
    local sliced = {}

    for i = first or 1, last or #tbl, step or 1 do
        sliced[#sliced+1] = tbl[i]
    end

    return sliced
end

local C = {}
C.__index = C

local LIFECYCLE = {
    SINGLETON = 0,
    TRANSIENT = 1,
}

function C.new()
    local c = {
        _config = {},
        _instances = {},
        _transientInstances = {},
    }
    setmetatable(c, C)
    return c
end

function C:_get(name)
    if self._instances[name] ~= nil then
        return self._instances[name]
    end
    if self._transientInstances[name] ~= nil then
        return self._transientInstances[name]
    end

    local config = self._config[name]
    if config == nil then
        error("Dependency not found: " .. name)
    end

    local deps = sliceTable(config, 2)
    local depInstances = {}
    for _, dep in pairs(deps) do
        table.insert(depInstances, self:_get(dep))
    end

    local instance = config[1](unpack(depInstances))

    if config.lifecycle == LIFECYCLE.SINGLETON then
        self._instances[name] = instance
    elseif config.lifecycle == LIFECYCLE.TRANSIENT then
        self._transientInstances[name] = instance
    end

    return instance
end

function C:addConfig(config)
    for k, v in pairs(config) do
        if v.lifecycle == nil then
            v.lifecycle = LIFECYCLE.SINGLETON
        end
        self._config[k] = v
    end
end

function C:get(name)
    local instance = self:_get(name)

    for k, _ in pairs(self._transientInstances) do
        self._transientInstances[k] = nil
    end

    return instance
end

return {
    newContainer = C.new,
    LIFECYCLE = LIFECYCLE,
}
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

local Lifecycle = {
    Singleton = 0,
    Transient = 1,
    AlwaysUnique = 2,
}

local RE = {}
RE.__index = RE

function RE.new()
    local re = {
        lifecycle = Lifecycle.Singleton,
    }
    setmetatable(re, RE)
    return re
end

function RE:use(value)
    local t = type(value)
    if t == "function" then
        self.func = value
    elseif t == "table" and value.__depends ~= nil then
        self.table = value
        if self.table.__lifecycle ~= nil then
            self.lifecycle = self.table.__lifecycle
        end
    else
        if self.lifecycle ~= Lifecycle.Singleton then
            error("Value-based entry can only be singleton")
        end
        self.value = value
    end

    return self
end

function RE:withLifecycle(lifecycle)
    self.lifecycle = lifecycle
    return self
end

function RE:singleton()
    return self:withLifecycle(Lifecycle.Singleton)
end

function RE:transient()
    if self.value ~= nil then
        error("Value-based entry can only be singleton")
    end

    self.lifecycle = Lifecycle.Transient
    return self
end

function RE:alwaysUnique()
    if self.value ~= nil then
        error("Value-based entry can only be singleton")
    end

    self.lifecycle = Lifecycle.AlwaysUnique
    return self
end

local R = {}
R.__index = R

function R.new()
    local r = {
        _entries = {},
        _defaultEntry = nil,
    }
    setmetatable(r, R)

    return r
end

function R:getEntry(name)
    local entry = self._entries[name]
    if entry == nil then
        return self._defaultEntry
    end
    return entry
end

function R:forType(name)
    if self._entries[name] ~= nil then
        return self._entries[name]
    end

    local entry = RE.new()
    self._entries[name] = entry
    return entry
end

function R:forward(nameFrom, nameTo)
    local entry = self:getEntry(nameTo)
    if entry == nil then
        error("Entry not found: " .. nameTo)
    end

    return self:forType(nameFrom):use(function(ctx)
        return ctx:get(nameTo)
    end):withLifecycle(entry.lifecycle)
end

function R:default()
    if self._defaultEntry ~= nil then
        return self._defaultEntry
    end

    local entry = RE.new()
    self._defaultEntry = entry
    return entry
end

local C = {}
C.__index = C

function C.new(registry)
    local c = {
        _registry = registry,
        _instances = {},
        _transientInstances = {},
        _chainDepth = 0,
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

    local entry = self._registry:getEntry(name)
    if entry == nil then
        error("Dependency not found: " .. name)
    end

    local instance = nil
    if entry.value ~= nil then
        instance = entry.value
    elseif entry.func ~= nil then
        instance = entry.func(self)
    elseif entry.table ~= nil then
        local deps = entry.table.__depends
        local depInstances = {}
        for _, depName in ipairs(deps) do
            table.insert(depInstances, self:get(depName))
        end
        instance = entry.table.__new(unpack(depInstances))
    else
        error("Registry entry is not properly configured: " .. name)
    end

    if entry.lifecycle == Lifecycle.Singleton then
        self._instances[name] = instance
    elseif entry.lifecycle == Lifecycle.Transient then
        self._transientInstances[name] = instance
    end

    return instance
end

function C:get(name)
    self._chainDepth = self._chainDepth + 1

    local instance = self:_get(name)

    self._chainDepth = self._chainDepth - 1
    if self._chainDepth <= 0 then
        for k, _ in pairs(self._transientInstances) do
            self._transientInstances[k] = nil
        end
    end

    return instance
end

return {
    RegistryEntry = RE,
    Registry = R,
    Container = C,
    Lifecycle = Lifecycle,
}
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
    local sliced = {};

    for i = first or 1, last or #tbl, step or 1 do
        sliced[#sliced+1] = tbl[i];
    end

    return sliced;
end

local C = {};
C.__index = C;

function C.new()
    local c = {
        _config = {},
        _instances = {},
    };
    setmetatable(c, C);
    return c;
end

function C:_create(name)
    local config = self._config[name];
    if config == nil then
        error("Dependency not found: " .. name);
    end

    local deps = sliceTable(config, 2);
    local depInstances = {};
    for _, dep in pairs(deps) do
        table.insert(depInstances, self:get(dep));
    end

    local instance = config[1](unpack(depInstances));
    self._instances[name] = instance;
    return instance;
end

function C:addConfig(config)
    for k, v in pairs(config) do
        self._config[k] = v;
    end
end

function C:get(name)
    if self._instances[name] ~= nil then
        return self._instances[name];
    end

    return self:_create(name);
end

return {
    newContainer = C.new
}
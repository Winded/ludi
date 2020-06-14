local Ludi = require("ludi")
local lu = require("luaunit")

TestLudi = {}

function TestLudi:test_dependencyTypes()
    local r = Ludi.Registry.new()

    local valueDep = "static string value"
    local tableMeta = {}
    tableMeta.__index = tableMeta
    tableMeta.__depends = { "Func" }
    tableMeta.__new = function(func)
        local t = {
            _func = func
        }
        setmetatable(t, tableMeta)
        return t
    end
    tableMeta.getFunc = function(self)
        return self._func
    end
    r:forType("Value"):use(valueDep)
    r:forType("Func"):use(function(ctx)
        return {
            value = ctx:get("Value")
        }
    end)
    r:forType("Table"):use(tableMeta)
    local c = Ludi.Container.new(r)
    
    local t = c:get("Table")
    lu.assertNotNil(t)
    local f = t:getFunc()
    lu.assertNotNil(f)
    lu.assertEquals(valueDep, f.value)
end

function TestLudi:test_lifecycles()
    local r = Ludi.Registry.new()
    r:forType("SingletonDep"):use({ "Singleton dependency" }):singleton()
    r:forType("TransientDep"):use({
        __depends = {},
        __lifecycle = Ludi.Lifecycle.Transient,
        __new = function()
            return { "Transient dependency" }
        end,
    })
    r:forType("UniqueDep"):use(function(ctx)
        return { "Unique dependency" }
    end):alwaysUnique()
    r:forType("DepUser"):use(function(ctx)
        return {
            singleton1 = ctx:get("SingletonDep"),
            singleton2 = ctx:get("SingletonDep"),
            transient1 = ctx:get("TransientDep"),
            transient2 = ctx:get("TransientDep"),
            unique1 = ctx:get("UniqueDep"),
            unique2 = ctx:get("UniqueDep"),
        }
    end):alwaysUnique()
    local c = Ludi.Container.new(r)
    
    local i1 = c:get("DepUser")
    local i2 = c:get("DepUser")
    lu.assertNotNil(i1)
    lu.assertNotNil(i2)
    lu.assertTrue(i1.singleton1 == i1.singleton2)
    lu.assertTrue(i1.transient1 == i1.transient2)
    lu.assertTrue(i1.singleton1 == i2.singleton1)
    lu.assertFalse(i1.transient1 == i2.transient1)
    lu.assertFalse(i1.unique1 == i1.unique2)
    lu.assertFalse(i1.unique1 == i2.unique1)
end

function TestLudi:test_forwarding()
    local r = Ludi.Registry.new()
    r:forType("Dep"):use({ "A dependency" })
    r:forward("ForwardDep", "Dep")
    local c = Ludi.Container.new(r)
    
    local forward = c:get("ForwardDep")
    lu.assertEquals(forward[1], "A dependency")
end

function TestLudi:test_defaultEntry()
    local r = Ludi.Registry.new()
    r:default():use({ "Default dependency" })
    r:forType("Dep"):use(function(ctx)
        return {
            defaultDep = ctx:get("UndefinedDep")
        }
    end)
    local c = Ludi.Container.new(r)
    
    local dep = c:get("Dep")
    lu.assertEquals(dep.defaultDep[1], "Default dependency")
end

local runner = lu.LuaUnit.new()
runner:setOutputType("tap")
os.exit(runner:runSuite())
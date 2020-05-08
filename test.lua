local Ludi = require("ludi");
local lu = require("luaunit");

TestLudi = {};

function TestLudi:test_createContainer()
    local c = Ludi.newContainer();
    lu.assertNotNil(c);
end

function TestLudi:test_sameDependency()
    local c = Ludi.newContainer();

    c:addConfig({
        Dep = {
            function()
                return {
                    value = "Hello world!"
                }
            end
        },
        ConsumerOne = {
            function(dep)
                return {
                    dep = dep,
                    getValue = function(self) return "1:" .. self.dep.value end
                }
            end,
            "Dep",
        },
        ConsumerTwo = {
            function(dep)
                return {
                    dep = dep,
                    getAnotherValue = function(self) return "2:" .. self.dep.value end
                }
            end,
            "Dep",
        },
    });

    local consumerOne = c:get("ConsumerOne");
    local consumerTwo = c:get("ConsumerTwo");

    lu.assertEquals(consumerOne:getValue(), "1:Hello world!");
    lu.assertEquals(consumerTwo:getAnotherValue(), "2:Hello world!");
end

function TestLudi:test_failCircularDependency()
    local c = Ludi.newContainer();

    c:addConfig({
        DepOne = {
            function(dep)
                return {
                    dep = dep,
                }
            end,
            "DepTwo",
        },
        DepTwo = {
            function(dep)
                return {
                    dep = dep,
                }
            end,
            "DepOne",
        },
    });

    local err = nil;
    xpcall(function() c:get("DepOne"); end, function(e) err = e; end);
    lu.assertStrContains(err, "stack overflow");
end

local runner = lu.LuaUnit.new();
runner:setOutputType("tap");
os.exit(runner:runSuite());
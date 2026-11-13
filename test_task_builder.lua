local Scheduler = require("scheduler")
local TaskBuilder = require("task_builder")

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("FAIL %s: expected %s, got %s", msg, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, msg)
    if not value then
        error("FAIL " .. msg)
    end
end

local s = Scheduler.new()
local results = {}
local t = TaskBuilder.new(s):run(function() results[#results + 1] = "ran" end):after(0):priority(5):tag("X"):schedule()
assert_true(t.id ~= nil, "builder task id")
s:update(0)
assert_eq(#results, 1, "builder ran")
assert_eq(#s:get_tasks_by_tag("X"), 1, "builder tag")

local s2 = Scheduler.new()
local r2 = {}
TaskBuilder.new(s2):run(function() r2[#r2 + 1] = "now" end):now()
s2:update(0)
assert_eq(#r2, 1, "builder now")

local ok = pcall(function() TaskBuilder.new(s2):schedule() end)
assert_true(not ok, "builder requires callback")

print("task builder tests passed")

local Scheduler = require("scheduler")

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

-- Basic creation and initial state
local s = Scheduler.new()
assert_eq(s:get_time(), 0, "initial time")
assert_eq(s:total_tasks(), 0, "initial total tasks")
assert_eq(s:pending_tasks(), 0, "initial pending tasks")

-- Adding and running a task
local results = {}
local task = s:add_task(function() results[#results + 1] = "ran" end, 0)
assert_eq(s:total_tasks(), 1, "total after add")
assert_eq(s:pending_tasks(), 1, "pending after add")
assert_true(task.id ~= nil, "task has id")

s:update(0)
assert_eq(#results, 1, "task ran")
assert_eq(results[1], "ran", "task result")

-- Lookup by id
local found = s:get_task_by_id(task.id)
assert_true(found == task, "get_task_by_id")

-- Cancellation
local s2 = Scheduler.new()
local cancelled = s2:add_task(function() end, 10)
s2:cancel_task(cancelled)
assert_eq(s2:pending_tasks(), 0, "pending after cancel")

-- Removal
local s3 = Scheduler.new()
local removed = s3:add_task(function() end, 10)
local ok = s3:remove_task(removed)
assert_true(ok, "remove_task success")
assert_eq(s3:total_tasks(), 0, "total after remove")

-- Tag filtering
local s4 = Scheduler.new()
s4:add_task(function() end, 1, nil, 0, nil, "A")
s4:add_task(function() end, 2, nil, 0, nil, "A")
s4:add_task(function() end, 3, nil, 0, nil, "B")
local tagged = s4:get_tasks_by_tag("A")
assert_eq(#tagged, 2, "tasks by tag")

-- Time control
local s5 = Scheduler.new()
s5:set_time(50)
assert_eq(s5:get_time(), 50, "set_time")

-- Pause and resume
local s6 = Scheduler.new()
local paused_results = {}
s6:add_task(function() paused_results[#paused_results + 1] = "x" end, 0)
s6:pause()
s6:update(1)
assert_eq(#paused_results, 0, "no run while paused")
s6:resume()
s6:update(0)
assert_eq(#paused_results, 1, "run after resume")

-- Clear
local s7 = Scheduler.new()
s7:add_task(function() end, 0)
s7:clear()
assert_eq(s7:total_tasks(), 0, "clear")

print("smoke tests passed")

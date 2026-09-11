local Scheduler = require("scheduler")

local sched = Scheduler.new()
local results = {}

-- Test 1: Immediate task
sched:add_task(function(t) results[#results+1] = "Task A at " .. t end, 0)

-- Test 2: Delayed task
sched:add_task(function(t) results[#results+1] = "Task B at " .. t end, 2)

-- Test 3: Recurring task
local recurring = sched:add_task(function(t) results[#results+1] = "Task C at " .. t end, 1, 1)

print("Updating scheduler...")
sched:update(0.5)
print("T=0.5: " .. #results .. " tasks run")

sched:update(1.0)
print("T=1.5: " .. #results .. " tasks run")

-- Test 4: Cancel the recurring task using API
sched:cancel_task(recurring)
print("Task C cancelled at T=1.5")

sched:update(1.0)
print("T=2.5: " .. #results .. " tasks run")

for i, v in ipairs(results) do
    print(i .. ": " .. v)
end

-- Test 5: Clear tasks
print("Clearing scheduler...")
sched:clear()
sched:add_task(function(t) results[#results+1] = "Task D at " .. t end, 0)
sched:update(0)
print("T=2.5 (after clear): " .. #results .. " tasks run")

for i, v in ipairs(results) do
    print(i .. ": " .. v)
end
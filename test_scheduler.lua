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

-- Test 6: Priority check
print("Testing priority...")
results = {}
local p_sched = Scheduler.new()
p_sched:add_task(function(t) results[#results+1] = "Low Priority" end, 0, nil, 0)
p_sched:add_task(function(t) results[#results+1] = "High Priority" end, 0, nil, 10)
p_sched:update(0)
print("Priority result 1: " .. results[1])
print("Priority result 2: " .. results[2])

-- Test 7: pending_tasks count
print("Testing pending_tasks count...")
sched:clear()
sched:add_task(function() end, 1)
sched:add_task(function() end, 2)
local t_can = sched:add_task(function() end, 3)
sched:cancel_task(t_can)
print("Pending tasks (should be 2): " .. sched:pending_tasks())

-- Test 8: Error handling
print("Testing error handling...")
results = {}
local e_sched = Scheduler.new()
e_sched:add_task(function() error("Boom!") end, 0)
e_sched:add_task(function() results[#results+1] = "Survivor" end, 0)
e_sched:update(0)
print("Survivor task ran: " .. (results[1] == "Survivor" and "Yes" or "No"))

-- Test 9: Task arguments
print("Testing task arguments...")
results = {}
local a_sched = Scheduler.new()
a_sched:add_task(function(t, args) results[#results+1] = args.name .. " at " .. t end, 0, nil, 0, {name = "ArgTask"})
a_sched:update(0)
print("Arg result: " .. (results[1] == "ArgTask at 0" and "Success" or "Failure"))

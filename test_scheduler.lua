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

-- Test 10: Pruning cancelled tasks
print("Testing pruning...")
local prune_sched = Scheduler.new()
prune_sched:add_task(function() end, 10)
prune_sched:add_task(function() end, 20)
local t_to_prune = prune_sched:add_task(function() end, 30)
prune_sched:cancel_task(t_to_prune)

print("Total tasks before prune: " .. prune_sched:total_tasks())
prune_sched:prune_cancelled()
print("Total tasks after prune: " .. prune_sched:total_tasks())

prune_sched:add_task(function(t) results[#results+1] = "PruneTest" end, 0)
prune_sched:update(0)
print("Active task after prune ran: " .. (results[#results] == "PruneTest" and "Yes" or "No"))

-- Test 11: remove_task
print("Testing remove_task...")
local rm_sched = Scheduler.new()
local t_rm = rm_sched:add_task(function() end, 10)
print("Total tasks before remove: " .. rm_sched:total_tasks())
local removed = rm_sched:remove_task(t_rm)
print("Remove successful: " .. (removed and "Yes" or "No"))
print("Total tasks after remove: " .. rm_sched:total_tasks())

-- Test 12: reschedule_task
print("Testing reschedule_task...")
results = {}
local res_sched = Scheduler.new()
local t_res = res_sched:add_task(function(t) results[#results+1] = "Rescheduled Task at " .. t end, 10)

-- Push it further back
res_sched:reschedule_task(t_res, 20)
res_sched:update(15)
print("Tasks run at T=15 (should be 0): " .. #results)

res_sched:update(5)
print("Tasks run at T=20 (should be 1): " .. #results)
print("Reschedule result: " .. (results[1] == "Rescheduled Task at 20" and "Success" or "Failure"))

-- Test 13: peek_next_task
print("Testing peek_next_task...")
local peek_sched = Scheduler.new()
local t_next = peek_sched:add_task(function() end, 5)
local t_later = peek_sched:add_task(function() end, 10)

local peeked = peek_sched:peek_next_task()
print("Peeked task is correct: " .. (peeked == t_next and "Yes" or "No"))

peek_sched:cancel_task(t_next)
peeked = peek_sched:peek_next_task()
print("Peeked task after cancellation is correct: " .. (peeked == t_later and "Yes" or "No"))

-- Test 14: Pause/Resume
print("Testing pause/resume...")
results = {}
local p_sched_pause = Scheduler.new()
p_sched_pause:add_task(function(t) results[#results+1] = "Paused Task at " .. t end, 1)

p_sched_pause:pause()
p_sched_pause:update(2)
print("Tasks run while paused (should be 0): " .. #results)

p_sched_pause:resume()
p_sched_pause:update(0)
print("Tasks run after resume (should be 1): " .. #results)
print("Pause result: " .. (results[1] == "Paused Task at 0" and "Success" or "Failure"))

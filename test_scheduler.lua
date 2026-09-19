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

-- Test 15: Max Execution Time
print("Testing max execution time...")
results = {}
local limit_sched = Scheduler.new()
for i = 1, 10 do
    limit_sched:add_task(function() 
        -- Simulate work
        local start = os.clock()
        while os.clock() - start < 0.01 do end
        results[#results+1] = "Work"
    end, 0)
end

-- Set a very small limit that should cut off some tasks
limit_sched:update(0, 0.02)
print("Tasks run with limit (should be < 10): " .. #results)

-- Test 16: Task Tagging
print("Testing task tagging...")
local tag_sched = Scheduler.new()
tag_sched:add_task(function() end, 1, nil, 0, nil, "AI")
tag_sched:add_task(function() end, 2, nil, 0, nil, "AI")
tag_sched:add_task(function() end, 3, nil, 0, nil, "Network")

local ai_tasks = tag_sched:get_tasks_by_tag("AI")
print("AI tasks found (should be 2): " .. #ai_tasks)

local cancelled_count = tag_sched:cancel_tasks_by_tag("AI")
print("AI tasks cancelled (should be 2): " .. cancelled_count)
print("Total pending (should be 1): " .. tag_sched:pending_tasks())

-- Test 17: update_task
print("Testing update_task...")
results = {}
local up_sched = Scheduler.new()
local t_up = up_sched:add_task(function(t) results[#results+1] = "Updated" end, 10)

-- Change delay to 0 and priority
up_sched:update_task(t_up, {delay = 0, priority = 100})
up_sched:update(0)
print("Update result: " .. (results[1] == "Updated" and "Success" or "Failure"))

-- Test 18: remove_tasks_by_tag
print("Testing remove_tasks_by_tag...")
local rm_tag_sched = Scheduler.new()
rm_tag_sched:add_task(function() end, 1, nil, 0, nil, "Temp")
rm_tag_sched:add_task(function() end, 2, nil, 0, nil, "Temp")
rm_tag_sched:add_task(function() end, 3, nil, 0, nil, "Keep")

local removed_count = rm_tag_sched:remove_tasks_by_tag("Temp")
print("Tasks removed by tag (should be 2): " .. removed_count)
print("Total tasks remaining (should be 1): " .. rm_tag_sched:total_tasks())

-- Test 19: Dynamic control from callback
print("Testing dynamic control...")
results = {}
local dyn_sched = Scheduler.new()
local count = 0
dyn_sched:add_task(function(t)
    count = count + 1
    results[#results+1] = "Dyn " .. count
    if count >= 3 then
        return { cancel = true }
    end
    return { next_delay = count }
end, 0)

for i = 1, 10 do dyn_sched:update(1) end
print("Dynamic tasks run (should be 3): " .. #results)
print("Final count correct: " .. (count == 3 and "Yes" or "No"))

-- Test 20: Task ID and get_task_by_id
print("Testing task IDs...")
local id_sched = Scheduler.new()
local t_id1 = id_sched:add_task(function() end, 1)
local t_id2 = id_sched:add_task(function() end, 2)

print("Task 1 ID correct: " .. (t_id1.id == 1 and "Yes" or "No"))
print("Task 2 ID correct: " .. (t_id2.id == 2 and "Yes" or "No"))

local found = id_sched:get_task_by_id(2)
print("Task found by ID: " .. (found == t_id2 and "Yes" or "No"))

local not_found = id_sched:get_task_by_id(99)
print("Non-existent task not found: " .. (not_found == nil and "Yes" or "No"))

-- Test 21: get_time and set_time
print("Testing get_time and set_time...")
local time_sched = Scheduler.new()
print("Initial time (should be 0): " .. time_sched:get_time())

time_sched:set_time(100)
print("Set time (should be 100): " .. time_sched:get_time())

time_sched:add_task(function() end, 10)
-- Task should be scheduled for 110
local next_task = time_sched:peek_next_task()
print("Next task run time (should be 110): " .. next_task.next_run)

-- Test 22: execute_due
print("Testing execute_due...")
results = {}
local ex_sched = Scheduler.new()
ex_sched:add_task(function() results[#results+1] = "Due" end, 0)
ex_sched:pause()
-- update() would do nothing because it's paused, but execute_due should run it
ex_sched:execute_due()
print("Execute due while paused ran: " .. (results[1] == "Due" and "Yes" or "No"))

-- Test 23: get_active_tasks
print("Testing get_active_tasks...")
local act_sched = Scheduler.new()
act_sched:add_task(function() end, 1)
local t_can_act = act_sched:add_task(function() end, 2)
act_sched:cancel_task(t_can_act)
local active = act_sched:get_active_tasks()
print("Active tasks count (should be 1): " .. #active)
print("Correct task is active: " .. (active[1] ~= t_can_act and "Yes" or "No"))

-- Test 24: get_task_remaining_time
print("Testing get_task_remaining_time...")
local rem_sched = Scheduler.new()
local t_rem = rem_sched:add_task(function() end, 10)
print("Remaining time (should be 10): " .. rem_sched:get_task_remaining_time(t_rem))

rem_sched:update(4)
print("Remaining time after update (should be 6): " .. rem_sched:get_task_remaining_time(t_rem))

rem_sched:update(7)
print("Remaining time after overdue (should be 0): " .. rem_sched:get_task_remaining_time(t_rem))

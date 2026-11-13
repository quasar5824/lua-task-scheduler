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

-- Recurring task
local sr = Scheduler.new()
local rcount = 0
local rtask = sr:add_task(function() rcount = rcount + 1 end, 0, 1)
sr:update(0)
assert_eq(rcount, 1, "recurring first")
sr:update(1)
assert_eq(rcount, 2, "recurring second")
sr:cancel_task(rtask)
sr:update(1)
assert_eq(rcount, 2, "recurring cancelled")

-- Priority ordering
local sp = Scheduler.new()
local prio_order = {}
sp:add_task(function() prio_order[#prio_order + 1] = "low" end, 0, nil, 0)
sp:add_task(function() prio_order[#prio_order + 1] = "high" end, 0, nil, 10)
sp:update(0)
assert_eq(prio_order[1], "high", "priority high first")
assert_eq(prio_order[2], "low", "priority low second")

-- cancel_tasks_by_tag
local sct = Scheduler.new()
sct:add_task(function() end, 1, nil, 0, nil, "A")
sct:add_task(function() end, 2, nil, 0, nil, "A")
sct:add_task(function() end, 3, nil, 0, nil, "B")
assert_eq(sct:cancel_tasks_by_tag("A"), 2, "cancel by tag count")
assert_eq(sct:pending_tasks(), 1, "pending after cancel by tag")

-- remove_tasks_by_tag
local srt = Scheduler.new()
srt:add_task(function() end, 1, nil, 0, nil, "T")
srt:add_task(function() end, 2, nil, 0, nil, "T")
srt:add_task(function() end, 3, nil, 0, nil, "K")
assert_eq(srt:remove_tasks_by_tag("T"), 2, "remove by tag count")
assert_eq(srt:total_tasks(), 1, "total after remove by tag")

-- reschedule_task
local sres = Scheduler.new()
local rres = {}
local tr = sres:add_task(function(t) rres[#rres + 1] = t end, 10)
sres:reschedule_task(tr, 20)
sres:update(15)
assert_eq(#rres, 0, "reschedule no run at 15")
sres:update(5)
assert_eq(#rres, 1, "reschedule run at 20")
assert_eq(rres[1], 20, "reschedule time")

-- peek_next_task
local spk = Scheduler.new()
local a = spk:add_task(function() end, 5)
local b = spk:add_task(function() end, 2)
assert_true(spk:peek_next_task() == b, "peek earliest")
spk:cancel_task(b)
assert_true(spk:peek_next_task() == a, "peek after cancel")

-- update_task
local sup = Scheduler.new()
local rup = {}
local tup = sup:add_task(function(t) rup[#rup + 1] = "U" end, 10)
sup:update_task(tup, {delay = 0, priority = 5})
sup:update(0)
assert_eq(#rup, 1, "update_task ran")

-- get_task_status
local sst = Scheduler.new()
local tp = sst:add_task(function() end, 10)
local te = sst:add_task(function() end, 0)
local tc = sst:add_task(function() end, 5)
sst:cancel_task(tc)
sst:update(0)
assert_eq(sst:get_task_status(tp), "pending", "status pending")
assert_eq(sst:get_task_status(te), "executed", "status executed")
assert_eq(sst:get_task_status(tc), "cancelled", "status cancelled")
local trm = sst:add_task(function() end, 1)
sst:remove_task(trm)
assert_eq(sst:get_task_status(trm), "removed", "status removed")

-- get_task_remaining_time
local srm = Scheduler.new()
local trm2 = srm:add_task(function() end, 10)
assert_eq(srm:get_task_remaining_time(trm2), 10, "remaining initial")
srm:update(4)
assert_eq(srm:get_task_remaining_time(trm2), 6, "remaining after 4")
srm:update(7)
assert_eq(srm:get_task_remaining_time(trm2), 0, "remaining overdue")

-- is_task_pending
local sip = Scheduler.new()
local tip = sip:add_task(function() end, 10)
assert_true(sip:is_task_pending(tip), "pending yes")
sip:cancel_task(tip)
assert_true(not sip:is_task_pending(tip), "pending no after cancel")
local tip2 = sip:add_task(function() end, 0)
sip:update(0)
assert_true(not sip:is_task_pending(tip2), "pending no after exec")

-- get_next_task_time
local snt = Scheduler.new()
assert_true(snt:get_next_task_time() == nil, "next time nil")
snt:add_task(function() end, 5)
assert_eq(snt:get_next_task_time(), 5, "next time 5")
snt:add_task(function() end, 2)
assert_eq(snt:get_next_task_time(), 2, "next time 2")

-- execute_due while paused
local sex = Scheduler.new()
local rex = {}
sex:add_task(function() rex[#rex + 1] = "D" end, 0)
sex:pause()
sex:execute_due()
assert_eq(#rex, 1, "execute_due paused")
assert_true(sex:is_paused(), "still paused")

-- max tasks limit
local smt = Scheduler.new()
local rmt = {}
for i = 1, 5 do smt:add_task(function() rmt[#rmt + 1] = "T" end, 0) end
smt:update(0, nil, 3)
assert_eq(#rmt, 3, "max tasks first")
smt:update(0, nil, 3)
assert_eq(#rmt, 5, "max tasks second")

-- flush_due
local sfl = Scheduler.new()
local rfl = {}
sfl:add_task(function() rfl[#rfl + 1] = "F1" end, 0)
sfl:add_task(function() rfl[#rfl + 1] = "F2" end, 0)
sfl:add_task(function() rfl[#rfl + 1] = "F3" end, 1)
sfl:flush_due()
assert_eq(#rfl, 2, "flush first")
sfl:update(1)
sfl:flush_due()
assert_eq(#rfl, 3, "flush second")

-- wait_until
local sw = Scheduler.new()
local rw = {}
sw:wait_until(50, function(t) rw[#rw + 1] = "A at " .. t end)
sw:update(40)
assert_eq(#rw, 0, "wait no run 40")
sw:update(10)
assert_eq(#rw, 1, "wait run 50")
assert_eq(rw[1], "A at 50", "wait value")

-- dependencies
local sdep = Scheduler.new()
local rdep = {}
local t1 = sdep:add_task(function() rdep[#rdep + 1] = "Task 1" end, 0)
local t2 = sdep:add_task(function() rdep[#rdep + 1] = "Task 2" end, 0)
sdep:add_dependency(t2, t1)
sdep:update(0)
assert_eq(rdep[1], "Task 1", "dep order 1")
assert_eq(rdep[2], "Task 2", "dep order 2")

-- on_complete
local soc = Scheduler.new()
local rcc = {}
local done = false
soc:add_task(function(t) rcc[#rcc + 1] = "ran"; return "Finished" end, 0, nil, 0, nil, nil, nil, function(t, task, res) done = true; rcc[#rcc + 1] = "Completed with " .. res end)
soc:update(0)
assert_true(done, "on_complete ran")
assert_eq(rcc[1], "ran", "oc order 1")
assert_eq(rcc[2], "Completed with Finished", "oc order 2")

-- recurring conversion via return repeat=false
local src = Scheduler.new()
local rsrc = {}
local scount = 0
src:add_task(function(t) scount = scount + 1; rsrc[#rsrc + 1] = "Run " .. scount; if scount == 2 then return { ["repeat"] = false } end end, 0, 1)
src:update(0)
src:update(1)
src:update(1)
assert_eq(#rsrc, 2, "recurring conversion count")

-- timeout
local sto = Scheduler.new()
local rto = {}
local tto = sto:add_task(function() rto[#rto + 1] = "Too late" end, 10, nil, 0, nil, nil, 5)
sto:update(17)
assert_eq(#rto, 0, "timeout no run")
assert_true(tto.cancelled, "timeout cancelled")

-- groups
local sgrp = Scheduler.new()
local rgrp = {}
local g1 = sgrp:add_task(function() rgrp[#rgrp + 1] = "G1" end, 0)
local g2 = sgrp:add_task(function() rgrp[#rgrp + 1] = "Other" end, 0)
sgrp:add_task_to_group(g1, "grp")
sgrp:pause_group("grp")
sgrp:update(0)
assert_eq(#rgrp, 1, "group paused count")
assert_eq(rgrp[1], "Other", "group paused correct")
rgrp = {}
sgrp:resume_group("grp")
sgrp:update(0)
assert_eq(#rgrp, 1, "group resumed count")

-- weighted selection
local sws = Scheduler.new()
local th = sws:add_task(function() end, 0, nil, 0, nil, nil, nil, nil, 100)
local tl = sws:add_task(function() end, 0, nil, 0, nil, nil, nil, nil, 1)
local hc, lc = 0, 0
for i = 1, 200 do
    local sel = sws:weighted_select_due()
    if sel == th then hc = hc + 1 elseif sel == tl then lc = lc + 1 end
end
assert_true(hc > lc, "weighted heavier")

-- get_tasks_by_execution_range
local sre = Scheduler.new()
local a1 = sre:add_task(function() end, 0, 1)
local a2 = sre:add_task(function() end, 0, 1)
local a3 = sre:add_task(function() end, 0, 1)
sre:update(0)
sre:update(1)
sre:update(1)
a1.execution_count = 1
local r12 = sre:get_tasks_by_execution_range(1, 2)
local r23 = sre:get_tasks_by_execution_range(2, 3)
assert_eq(#r12, 1, "range 1-2")
assert_eq(#r23, 2, "range 2-3")

-- execution count tracking
local sec = Scheduler.new()
local tec = sec:add_task(function() end, 0, 1)
sec:update(0)
sec:update(1)
sec:update(1)
assert_eq(tec.execution_count, 3, "exec count")
local det = sec:get_task_details(tec)
assert_eq(det.execution_count, 3, "details count")

-- get_active_tasks
local sac = Scheduler.new()
sac:add_task(function() end, 1)
local tc2 = sac:add_task(function() end, 2)
sac:cancel_task(tc2)
local act = sac:get_active_tasks()
assert_eq(#act, 1, "active count")

-- get_tasks_by_callback / remove_tasks_by_callback
local scb = Scheduler.new()
local f1 = function() end
local f2 = function() end
scb:add_task(f1, 1)
scb:add_task(f1, 2)
scb:add_task(f2, 3)
assert_eq(#scb:get_tasks_by_callback(f1), 2, "cb find")
assert_eq(#scb:get_tasks_by_callback(function() end), 0, "cb none")
assert_eq(scb:remove_tasks_by_callback(f1), 2, "cb remove count")
assert_eq(scb:total_tasks(), 1, "cb remaining")

-- execute_all_due
local sea = Scheduler.new()
local rea = {}
for i = 1, 10 do sea:add_task(function() rea[#rea + 1] = "A" end, 0) end
sea:execute_all_due()
assert_eq(#rea, 10, "execute all due")

-- get_tasks
local sgt = Scheduler.new()
sgt:add_task(function() end, 0)
sgt:add_task(function() end, 0)
assert_eq(#sgt:get_tasks(), 2, "get_tasks")

-- serialization
local sser = Scheduler.new()
local res_ser = {}
local cb1 = function(t) res_ser[#res_ser + 1] = "S1 at " .. t end
local cb2 = function(t) res_ser[#res_ser + 1] = "S2 at " .. t end
sser:add_task(cb1, 1)
sser:add_task(cb2, 2)
local state = sser:serialize({ [cb1] = "task1", [cb2] = "task2" })
local nser = Scheduler.new()
nser:deserialize(state, { task1 = cb1, task2 = cb2 })
assert_eq(nser:total_tasks(), 2, "deserialize count")
nser:update(2)
assert_eq(#res_ser, 2, "deserialize run")

-- performance report
local sperf = Scheduler.new()
local p1 = sperf:add_task(function() local st = os.clock(); while os.clock() - st < 0.02 do end end, 0)
local p2 = sperf:add_task(function() local st = os.clock(); while os.clock() - st < 0.01 do end end, 0)
sperf:update(0)
local rep = sperf:get_performance_report()
assert_eq(rep.total_executions, 2, "perf total exec")
assert_true(p1.avg_execution_time > 0, "perf task avg")

print("smoke tests passed")

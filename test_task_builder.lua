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

do
    local ss = Scheduler.new()
    local order = {}
    local dependency = ss:add_task(function() order[#order + 1] = "dep" end, 0)
    TaskBuilder.new(ss)
        :run(function() order[#order + 1] = "task" end)
        :depends_on(dependency)
        :schedule()
    ss:update(0)
    assert_eq(order[1], "dep", "builder dependency order 1")
    assert_eq(order[2], "task", "builder dependency order 2")

    local grouped_scheduler = Scheduler.new()
    local grouped = {}
    TaskBuilder.new(grouped_scheduler)
        :run(function() grouped[#grouped + 1] = "grouped" end)
        :group("g")
        :schedule()
    grouped_scheduler:pause_group("g")
    grouped_scheduler:update(0)
    assert_eq(#grouped, 0, "builder group paused")
    grouped_scheduler:resume_group("g")
    grouped_scheduler:update(0)
    assert_eq(#grouped, 1, "builder group resumed")

    local timeout_scheduler = Scheduler.new()
    local timed = {}
    local timed_task = TaskBuilder.new(timeout_scheduler)
        :run(function() timed[#timed + 1] = "late" end)
        :after(10)
        :timeout(5)
        :schedule()
    timeout_scheduler:update(17)
    assert_eq(#timed, 0, "builder timeout no run")
    assert_true(timed_task.cancelled, "builder timeout cancelled")

    local complete_scheduler = Scheduler.new()
    local complete_results = {}
    local completed = false
    TaskBuilder.new(complete_scheduler)
        :run(function() complete_results[#complete_results + 1] = "ran"; return "ok" end)
        :on_complete(function(t, task, result)
            completed = true
            complete_results[#complete_results + 1] = "done " .. result
        end)
        :schedule()
    complete_scheduler:update(0)
    assert_true(completed, "builder on_complete ran")
    assert_eq(complete_results[1], "ran", "builder on_complete order 1")
    assert_eq(complete_results[2], "done ok", "builder on_complete order 2")

    local weighted_scheduler = Scheduler.new()
    local heavy = TaskBuilder.new(weighted_scheduler):run(function() end):weight(100):schedule()
    local light = TaskBuilder.new(weighted_scheduler):run(function() end):weight(1):schedule()
    local heavy_count, light_count = 0, 0
    for i = 1, 100 do
        local selected = weighted_scheduler:weighted_select_due()
        if selected == heavy then
            heavy_count = heavy_count + 1
        elseif selected == light then
            light_count = light_count + 1
        end
    end
    assert_true(heavy_count > light_count, "builder weighted selection")

    local alias_scheduler = Scheduler.new()
    local alias_results = {}
    TaskBuilder.new(alias_scheduler)
        :run(function() alias_results[#alias_results + 1] = "alias" end)
        :delay(0)
        :build()
    alias_scheduler:update(0)
    assert_eq(#alias_results, 1, "builder aliases")

    local absolute_scheduler = Scheduler.new()
    absolute_scheduler:set_time(10)
    local absolute_results = {}
    TaskBuilder.new(absolute_scheduler)
        :run(function() absolute_results[#absolute_results + 1] = "absolute" end)
        :schedule_at(12)
    absolute_scheduler:update(1)
    assert_eq(#absolute_results, 0, "builder schedule_at no early run")
    absolute_scheduler:update(1)
    assert_eq(#absolute_results, 1, "builder schedule_at run")

    local at_time_scheduler = Scheduler.new()
    at_time_scheduler:set_time(5)
    local at_time_results = {}
    TaskBuilder.new(at_time_scheduler)
        :run(function() at_time_results[#at_time_results + 1] = "at time" end)
        :at_time(7)
        :schedule()
    at_time_scheduler:update(1)
    assert_eq(#at_time_results, 0, "builder at_time no early run")
    at_time_scheduler:update(1)
    assert_eq(#at_time_results, 1, "builder at_time run")

    local dependency_scheduler = Scheduler.new()
    local dependency_results = {}
    local dependency_one = dependency_scheduler:add_task(function() dependency_results[#dependency_results + 1] = "dep one" end, 0)
    local dependency_two = dependency_scheduler:add_task(function() dependency_results[#dependency_results + 1] = "dep two" end, 0)
    TaskBuilder.new(dependency_scheduler)
        :run(function() dependency_results[#dependency_results + 1] = "dependent" end)
        :depends_on(dependency_one, dependency_two)
        :schedule()
    dependency_scheduler:update(0)
    assert_eq(dependency_results[1], "dep one", "builder varargs dependency order 1")
    assert_eq(dependency_results[2], "dep two", "builder varargs dependency order 2")
    assert_eq(dependency_results[3], "dependent", "builder varargs dependency order 3")

    local group_scheduler = Scheduler.new()
    local group_results = {}
    TaskBuilder.new(group_scheduler)
        :run(function() group_results[#group_results + 1] = "grouped task" end)
        :group("left", "right")
        :schedule()
    group_scheduler:pause_group("left")
    group_scheduler:update(0)
    assert_eq(#group_results, 0, "builder varargs group paused")
    group_scheduler:resume_group("left")
    group_scheduler:update(0)
    assert_eq(#group_results, 1, "builder varargs group resumed")
end

print("task builder tests passed")

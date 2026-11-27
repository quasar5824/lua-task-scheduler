local TaskBuilder = {}
TaskBuilder.__index = TaskBuilder

local function is_task(value)
    return type(value) == "table" and value.id ~= nil
end

local function append_unique(list, value)
    for i = 1, #list do
        if list[i] == value then
            return
        end
    end
    list[#list + 1] = value
end

local function collect_indices(value)
    local indices = {}
    for key in pairs(value) do
        if type(key) == "number" and key > 0 and key == math.floor(key) then
            indices[#indices + 1] = key
        end
    end
    table.sort(indices)
    return indices
end

local function sorted_keys(value)
    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then
            return ta < tb
        end
        if ta == "number" then
            return a < b
        end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function collect_values(values)
    local result = {}
    local visited = {}

    if values == nil then
        return result
    end

    local function visit(value)
        if value == nil then
            return
        end

        if type(value) ~= "table" or is_task(value) then
            result[#result + 1] = value
            return
        end

        if visited[value] then
            return
        end
        visited[value] = true

        local indices = collect_indices(value)
        if #indices > 0 then
            for i = 1, #indices do
                visit(value[indices[i]])
            end
        else
            -- Empty tables represent empty collections, not values to schedule.
            if next(value) == nil then
                visited[value] = nil
                return
            end

            -- Boolean-valued tables are treated as sets, using their keys as items.
            local set_style = true
            for _, item in pairs(value) do
                if item ~= true and item ~= false and item ~= nil then
                    set_style = false
                    break
                end
            end

            if set_style then
                for _, key in ipairs(sorted_keys(value)) do
                    visit(key)
                end
            else
                -- Support map-style collections in addition to arrays.
                for _, key in ipairs(sorted_keys(value)) do
                    visit(value[key])
                end
            end
        end

        visited[value] = nil
    end

    local top_indices = collect_indices(values)
    if #top_indices > 0 then
        for i = 1, #top_indices do
            visit(values[top_indices[i]])
        end
    else
        -- Allow a bare collection to be passed without an outer wrapper.
        if next(values) ~= nil and not visited[values] then
            visit(values)
        end
    end

    return result
end

local function first_present(options, keys)
    for i = 1, #keys do
        local value = options[keys[i]]
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function has_any(options, keys)
    for i = 1, #keys do
        if options[keys[i]] ~= nil then
            return true
        end
    end
    return false
end

local function apply_options(builder, options)
    if type(options) ~= "table" then
        return builder
    end

    local callback_keys = { "callback", "run", "action", "job", "work", "fn", "func", "handler", "task", "execute", "invoke" }
    if has_any(options, callback_keys) then
        local callback_value = first_present(options, callback_keys)
        if type(callback_value) == "function" then
            builder:run(callback_value)
        end
    end

    local delay_keys = { "delay", "after", "delay_for", "wait_for", "start_in", "with_delay", "delayFor", "waitFor", "startIn", "withDelay" }
    if has_any(options, delay_keys) then
        builder:after(first_present(options, delay_keys))
    end

    local time_keys = { "run_at", "at_time", "time", "schedule_at", "at", "start_at", "delay_until", "schedule_at_time", "run_at_time", "schedule_for", "at_timestamp", "wait_until", "runAt", "atTime", "scheduleAt", "startAt", "delayUntil", "scheduleAtTime", "runAtTime", "scheduleFor", "atTimestamp", "waitUntil" }
    if has_any(options, time_keys) then
        builder:at_time(first_present(options, time_keys))
    end

    local interval_keys = { "interval", "every", "recurring", "repeat_every", "with_interval", "repeatEvery", "withInterval" }
    if has_any(options, interval_keys) then
        builder:every(first_present(options, interval_keys))
    end

    local priority_keys = { "priority", "prio", "with_priority", "withPriority" }
    if has_any(options, priority_keys) then
        builder:priority(first_present(options, priority_keys))
    end

    local args_keys = { "args", "arguments", "params", "with_args", "withArgs" }
    if has_any(options, args_keys) then
        builder:with_args(first_present(options, args_keys))
    end

    local tag_keys = { "tag", "with_tag", "tagged", "named", "withTag" }
    if has_any(options, tag_keys) then
        builder:tag(first_present(options, tag_keys))
    end

    local timeout_keys = { "timeout", "ttl", "with_timeout", "expires_after", "withTimeout", "expiresAfter" }
    if has_any(options, timeout_keys) then
        builder:timeout(first_present(options, timeout_keys))
    end

    local on_complete_keys = { "on_complete", "onComplete" }
    for i = 1, #on_complete_keys do
        local value = options[on_complete_keys[i]]
        if type(value) == "function" then
            builder:on_complete(value)
            break
        end
    end

    local weight_keys = { "weight", "cost", "with_weight", "withWeight" }
    if has_any(options, weight_keys) then
        builder:weight(first_present(options, weight_keys))
    end

    local dependency_keys = { "dependencies", "depends_on", "depends", "dependsOn", "requires", "needs", "with_dependencies", "withDependencies", "dependency", "depend", "required", "require", "prerequisite", "prerequisites" }
    if has_any(options, dependency_keys) then
        builder:depends_on(first_present(options, dependency_keys))
    end

    local group_keys = { "groups", "group", "with_group", "with_groups", "in_group", "inGroup", "grouped", "withGroup", "withGroups", "group_name", "group_names" }
    if has_any(options, group_keys) then
        builder:group(first_present(options, group_keys))
    end

    return builder
end

function TaskBuilder.new(scheduler, callback, options)
    local constructor_opts = nil

    if type(scheduler) == "table" and type(scheduler.add_task) ~= "function" then
        constructor_opts = scheduler
        scheduler = constructor_opts.scheduler or constructor_opts.sched or constructor_opts.queue or constructor_opts.engine or constructor_opts.runner or constructor_opts.task_scheduler or constructor_opts.taskScheduler or constructor_opts.instance or constructor_opts.target or constructor_opts.context
        callback = constructor_opts.callback or constructor_opts.run or constructor_opts.action or constructor_opts.job or constructor_opts.work or constructor_opts.fn or constructor_opts.func or constructor_opts.handler or constructor_opts.task or constructor_opts.execute or constructor_opts.invoke or callback
    end

    if type(scheduler) ~= "table" or type(scheduler.add_task) ~= "function" then
        error("TaskBuilder.new requires a scheduler instance")
    end

    local builder = setmetatable({
        _scheduler = scheduler,
        _callback = (type(callback) == "function") and callback or nil,
        _delay = 0,
        _run_at = nil,
        _interval = nil,
        _priority = 0,
        _args = nil,
        _tag = nil,
        _timeout = nil,
        _on_complete = nil,
        _weight = nil,
        _dependencies = {},
        _groups = {},
    }, TaskBuilder)

    if type(callback) == "table" then
        apply_options(builder, callback)
    end
    if type(constructor_opts) == "table" then
        apply_options(builder, constructor_opts)
    end
    if type(options) == "table" then
        apply_options(builder, options)
    end

    return builder
end

function TaskBuilder:run(callback)
    self._callback = callback
    return self
end

function TaskBuilder:after(delay)
    self._delay = delay or 0
    self._run_at = nil
    return self
end

function TaskBuilder:at_time(time)
    self._run_at = time
    if time ~= nil then
        self._delay = 0
    end
    return self
end

function TaskBuilder:every(interval)
    self._interval = interval
    return self
end

function TaskBuilder:priority(priority)
    self._priority = priority or 0
    return self
end

function TaskBuilder:with_args(args)
    self._args = args
    return self
end

function TaskBuilder:tag(tag)
    self._tag = tag
    return self
end

function TaskBuilder:timeout(timeout)
    self._timeout = timeout
    return self
end

function TaskBuilder:on_complete(callback)
    self._on_complete = callback
    return self
end

function TaskBuilder:weight(weight)
    self._weight = weight
    return self
end

function TaskBuilder:depends_on(dependency, ...)
    local dependencies = collect_values({dependency, ...})

    for i = 1, #dependencies do
        if not is_task(dependencies[i]) then
            error("TaskBuilder:depends_on expects task objects")
        end
        append_unique(self._dependencies, dependencies[i])
    end
    return self
end

function TaskBuilder:group(name, ...)
    local groups = collect_values({name, ...})

    for i = 1, #groups do
        append_unique(self._groups, groups[i])
    end
    return self
end

function TaskBuilder:options(options)
    return apply_options(self, options)
end

function TaskBuilder:schedule()
    if type(self._callback) ~= "function" then
        error("TaskBuilder: a callback is required; call :run(callback) first")
    end

    local delay = self._delay
    if self._run_at ~= nil then
        delay = self._run_at - self._scheduler:get_time()
        if delay < 0 then
            delay = 0
        end
    end
    self._run_at = nil

    local task = self._scheduler:add_task(
        self._callback,
        delay,
        self._interval,
        self._priority,
        self._args,
        self._tag,
        self._timeout,
        self._on_complete,
        self._weight
    )

    for i = 1, #self._dependencies do
        if type(self._scheduler.add_dependency) ~= "function" then
            error("TaskBuilder: scheduler does not support dependencies")
        end
        self._scheduler:add_dependency(task, self._dependencies[i])
    end

    for i = 1, #self._groups do
        if type(self._scheduler.add_task_to_group) ~= "function" then
            error("TaskBuilder: scheduler does not support task groups")
        end
        self._scheduler:add_task_to_group(task, self._groups[i])
    end

    return task
end

function TaskBuilder:schedule_at(time)
    self._run_at = time
    if time ~= nil then
        self._delay = 0
    end
    return self:schedule()
end

function TaskBuilder:now()
    self._delay = 0
    self._run_at = nil
    return self:schedule()
end

local aliases = {
    callback = "run",
    action = "run",
    job = "run",
    work = "run",
    fn = "run",
    func = "run",
    handler = "run",
    task = "run",
    execute = "run",
    invoke = "run",
    delay = "after",
    with_delay = "after",
    delay_for = "after",
    wait_for = "after",
    start_in = "after",
    wait = "after",
    withDelay = "after",
    delayFor = "after",
    waitFor = "after",
    startIn = "after",
    at = "at_time",
    run_at = "at_time",
    start_at = "at_time",
    delay_until = "at_time",
    schedule_at_time = "schedule_at",
    run_at_time = "schedule_at",
    schedule_for = "schedule_at",
    at_timestamp = "at_time",
    wait_until = "at_time",
    runAt = "at_time",
    atTime = "at_time",
    startAt = "at_time",
    delayUntil = "at_time",
    scheduleAtTime = "schedule_at",
    runAtTime = "schedule_at",
    scheduleFor = "schedule_at",
    atTimestamp = "at_time",
    waitUntil = "at_time",
    interval = "every",
    recurring = "every",
    repeat_every = "every",
    with_interval = "every",
    repeatEvery = "every",
    withInterval = "every",
    with_priority = "priority",
    prio = "priority",
    withPriority = "priority",
    args = "with_args",
    arguments = "with_args",
    params = "with_args",
    with_args = "with_args",
    withArgs = "with_args",
    with_tag = "tag",
    tagged = "tag",
    named = "tag",
    withTag = "tag",
    with_timeout = "timeout",
    expires_after = "timeout",
    ttl = "timeout",
    withTimeout = "timeout",
    expiresAfter = "timeout",
    onComplete = "on_complete",
    with_weight = "weight",
    cost = "weight",
    withWeight = "weight",
    depends = "depends_on",
    dependsOn = "depends_on",
    requires = "depends_on",
    needs = "depends_on",
    with_dependencies = "depends_on",
    dependencies = "depends_on",
    withDependencies = "depends_on",
    in_group = "group",
    inGroup = "group",
    with_group = "group",
    withGroup = "group",
    with_groups = "group",
    groups = "group",
    grouped = "group",
    withGroups = "group",
    immediately = "now",
    asap = "now",
    right_now = "now",
    build = "schedule",
    submit = "schedule",
    enqueue = "schedule",
    create = "schedule",
    add = "schedule",
    register = "schedule",
    push = "schedule",
    configure = "options",
    with_options = "options",
    set_options = "options",
    options = "options",
}

for alias, canonical in pairs(aliases) do
    if TaskBuilder[alias] == nil then
        TaskBuilder[alias] = function(self, ...)
            return self[canonical](self, ...)
        end
    end
end

return TaskBuilder

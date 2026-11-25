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

local function apply_options(builder, options)
    if type(options) ~= "table" then
        return builder
    end

    if options.callback ~= nil or options.run ~= nil or options.action ~= nil or options.job ~= nil or options.work ~= nil or options.fn ~= nil or options.func ~= nil or options.handler ~= nil then
        builder:run(options.callback or options.run or options.action or options.job or options.work or options.fn or options.func or options.handler)
    end
    if options.delay ~= nil or options.after ~= nil or options.delay_for ~= nil or options.wait_for ~= nil or options.start_in ~= nil or options.with_delay ~= nil then
        builder:after(options.delay or options.after or options.delay_for or options.wait_for or options.start_in or options.with_delay)
    end
    if options.run_at ~= nil or options.at_time ~= nil or options.time ~= nil or options.schedule_at ~= nil or options.at ~= nil or options.start_at ~= nil or options.delay_until ~= nil or options.schedule_at_time ~= nil or options.run_at_time ~= nil or options.schedule_for ~= nil or options.at_timestamp ~= nil or options.wait_until ~= nil then
        builder:at_time(options.run_at or options.at_time or options.time or options.schedule_at or options.at or options.start_at or options.delay_until or options.schedule_at_time or options.run_at_time or options.schedule_for or options.at_timestamp or options.wait_until)
    end
    if options.interval ~= nil or options.every ~= nil or options.recurring ~= nil or options.repeat_every ~= nil or options.with_interval ~= nil then
        builder:every(options.interval or options.every or options.recurring or options.repeat_every or options.with_interval)
    end
    if options.priority ~= nil or options.prio ~= nil or options.with_priority ~= nil then
        builder:priority(options.priority or options.prio or options.with_priority)
    end
    if options.args ~= nil or options.arguments ~= nil or options.params ~= nil or options.with_args ~= nil then
        builder:with_args(options.args or options.arguments or options.params or options.with_args)
    end
    if options.tag ~= nil or options.with_tag ~= nil or options.tagged ~= nil or options.named ~= nil then
        builder:tag(options.tag or options.with_tag or options.tagged or options.named)
    end
    if options.timeout ~= nil or options.ttl ~= nil or options.with_timeout ~= nil or options.expires_after ~= nil then
        builder:timeout(options.timeout or options.ttl or options.with_timeout or options.expires_after)
    end
    if type(options.on_complete) == "function" or type(options.onComplete) == "function" then
        builder:on_complete(options.on_complete or options.onComplete)
    end
    if options.weight ~= nil or options.cost ~= nil or options.with_weight ~= nil then
        builder:weight(options.weight or options.cost or options.with_weight)
    end
    if options.dependencies ~= nil or options.depends_on ~= nil or options.depends ~= nil or options.dependsOn ~= nil or options.requires ~= nil or options.needs ~= nil or options.with_dependencies ~= nil then
        builder:depends_on(options.dependencies or options.depends_on or options.depends or options.dependsOn or options.requires or options.needs or options.with_dependencies)
    end
    if options.groups ~= nil or options.group ~= nil or options.with_group ~= nil or options.with_groups ~= nil or options.in_group ~= nil or options.inGroup ~= nil or options.grouped ~= nil then
        builder:group(options.groups or options.group or options.with_group or options.with_groups or options.in_group or options.inGroup or options.grouped)
    end

    return builder
end

function TaskBuilder.new(scheduler, callback, options)
    local constructor_opts = nil

    if type(scheduler) == "table" and type(scheduler.add_task) ~= "function" then
        constructor_opts = scheduler
        scheduler = constructor_opts.scheduler or constructor_opts.sched or constructor_opts.queue
        callback = constructor_opts.callback or constructor_opts.run or constructor_opts.action or constructor_opts.job or constructor_opts.work or constructor_opts.fn or constructor_opts.func or constructor_opts.handler or callback
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
    delay = "after",
    with_delay = "after",
    delay_for = "after",
    wait_for = "after",
    start_in = "after",
    at = "at_time",
    run_at = "at_time",
    start_at = "at_time",
    delay_until = "at_time",
    schedule_at_time = "schedule_at",
    run_at_time = "schedule_at",
    schedule_for = "schedule_at",
    at_timestamp = "at_time",
    wait_until = "at_time",
    interval = "every",
    recurring = "every",
    repeat_every = "every",
    with_interval = "every",
    with_priority = "priority",
    prio = "priority",
    args = "with_args",
    arguments = "with_args",
    params = "with_args",
    with_args = "with_args",
    with_tag = "tag",
    tagged = "tag",
    named = "tag",
    with_timeout = "timeout",
    expires_after = "timeout",
    ttl = "timeout",
    onComplete = "on_complete",
    with_weight = "weight",
    cost = "weight",
    depends = "depends_on",
    dependsOn = "depends_on",
    requires = "depends_on",
    needs = "depends_on",
    with_dependencies = "depends_on",
    dependencies = "depends_on",
    in_group = "group",
    inGroup = "group",
    with_group = "group",
    withGroup = "group",
    with_groups = "group",
    groups = "group",
    grouped = "group",
    immediately = "now",
    asap = "now",
    right_now = "now",
    build = "schedule",
    submit = "schedule",
    enqueue = "schedule",
}

for alias, canonical in pairs(aliases) do
    if TaskBuilder[alias] == nil then
        TaskBuilder[alias] = function(self, ...)
            return self[canonical](self, ...)
        end
    end
end

return TaskBuilder

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

function TaskBuilder.new(scheduler)
    if type(scheduler) ~= "table" or type(scheduler.add_task) ~= "function" then
        error("TaskBuilder.new requires a scheduler instance")
    end
    return setmetatable({
        _scheduler = scheduler,
        _callback = nil,
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
    local dependencies = {dependency, ...}
    if #dependencies == 1 and type(dependency) == "table" and not is_task(dependency) then
        dependencies = dependency
    end

    for i = 1, #dependencies do
        if not is_task(dependencies[i]) then
            error("TaskBuilder:depends_on expects task objects")
        end
        append_unique(self._dependencies, dependencies[i])
    end
    return self
end

function TaskBuilder:group(name, ...)
    local groups = {name, ...}
    if #groups == 1 and type(groups[1]) == "table" then
        groups = groups[1]
    end

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
    return self:schedule()
end

function TaskBuilder:now()
    self._delay = 0
    self._run_at = nil
    return self:schedule()
end

local aliases = {
    delay = "after",
    with_delay = "after",
    at = "at_time",
    run_at = "at_time",
    start_at = "at_time",
    delay_until = "at_time",
    schedule_at_time = "schedule_at",
    run_at_time = "schedule_at",
    interval = "every",
    repeat_every = "every",
    with_interval = "every",
    with_priority = "priority",
    args = "with_args",
    with_tag = "tag",
    tagged = "tag",
    with_timeout = "timeout",
    expires_after = "timeout",
    onComplete = "on_complete",
    with_weight = "weight",
    depends = "depends_on",
    dependsOn = "depends_on",
    requires = "depends_on",
    with_dependencies = "depends_on",
    in_group = "group",
    inGroup = "group",
    with_group = "group",
    withGroup = "group",
    with_groups = "group",
    immediately = "now",
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

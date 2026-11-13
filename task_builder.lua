local TaskBuilder = {}
TaskBuilder.__index = TaskBuilder

function TaskBuilder.new(scheduler)
    if type(scheduler) ~= "table" or type(scheduler.add_task) ~= "function" then
        error("TaskBuilder.new requires a scheduler instance")
    end
    return setmetatable({
        _scheduler = scheduler,
        _callback = nil,
        _delay = 0,
        _interval = nil,
        _priority = 0,
        _args = nil,
        _tag = nil,
        _timeout = nil,
        _on_complete = nil,
        _weight = nil,
    }, TaskBuilder)
end

function TaskBuilder:run(callback)
    self._callback = callback
    return self
end

function TaskBuilder:after(delay)
    self._delay = delay or 0
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

function TaskBuilder:schedule()
    if type(self._callback) ~= "function" then
        error("TaskBuilder: a callback is required; call :run(callback) first")
    end
    return self._scheduler:add_task(
        self._callback,
        self._delay,
        self._interval,
        self._priority,
        self._args,
        self._tag,
        self._timeout,
        self._on_complete,
        self._weight
    )
end

function TaskBuilder:now()
    self._delay = 0
    return self:schedule()
end

return TaskBuilder

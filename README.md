# Lua Task Scheduler

A simple, efficient priority-based task scheduler for Lua. It supports one-time delayed tasks and recurring intervals.

## Usage

```lua
local Scheduler = require("scheduler")
local sched = Scheduler.new()

-- Add a task to run after 2 seconds
sched:add_task(function(currentTime, args)
    print("Hello " .. args.name .. " at " .. currentTime)
end, 2, nil, 0, {name = "World"})

-- Add a recurring task every 1 second
sched:add_task(function(currentTime)
    print("Tick at " .. currentTime)
end, 0, 1)

-- In your main loop
while true do
    local dt = 0.1 -- simulated delta time
    sched:update(dt)
    -- sleep or wait
end
```

## API

- `new()`: Creates a new scheduler instance.
- `add_task(callback, delay, interval, priority, args)`: Schedules a task.
- `cancel_task(task)`: Marks a task as cancelled.
- `remove_task(task)`: Immediately removes a task from the queue.
- `reschedule_task(task, new_delay)`: Changes the execution time of a task.
- `update(deltaTime)`: Advances the scheduler clock and executes due tasks.
- `prune_cancelled()`: Removes cancelled tasks from the internal list.
- `pending_tasks()`: Returns count of non-cancelled tasks.
- `total_tasks()`: Returns total count of tasks in the queue.
- `get_tasks()`: Returns a list of all current task objects.
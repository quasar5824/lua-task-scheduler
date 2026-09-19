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
- `add_task(callback, delay, interval, priority, args, tag)`: Schedules a task.
- `cancel_task(task)`: Marks a task as cancelled.
- `cancel_tasks_by_tag(tag)`: Marks all tasks with the given tag as cancelled.
- `remove_task(task)`: Immediately removes a task from the queue.
- `remove_tasks_by_tag(tag)`: Immediately removes all tasks with the given tag.
- `reschedule_task(task, new_delay)`: Changes the execution time of a task.
- `update_task(task, updates)`: Updates task properties (delay, priority, etc.).
- `update(deltaTime, maxExecutionTime)`: Advances clock and executes due tasks. `maxExecutionTime` limits execution budget.
- `execute_due(maxExecutionTime)`: Manually triggers execution of due tasks.
- `prune_cancelled()`: Removes cancelled tasks from the internal list.
- `clear()`: Removes all tasks and resets task IDs.
- `pending_tasks()`: Returns count of non-cancelled tasks.
- `total_tasks()`: Returns total count of tasks in the queue.
- `get_tasks()`: Returns a list of all current task objects.
- `get_active_tasks()`: Returns a list of non-cancelled tasks.
- `get_tasks_by_tag(tag)`: Returns tasks filtered by tag.
- `get_task_by_id(id)`: Returns a task by its unique ID.
- `peek_next_task()`: Returns the next non-cancelled task to run.
- `pause()`: Suspends the execution of tasks.
- `resume()`: Resumes the execution of tasks.
- `is_paused()`: Returns whether the scheduler is currently paused.
- `get_time()`: Returns the current scheduler time.
- `set_time(time)`: Sets the current scheduler time.
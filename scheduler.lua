local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    return setmetatable({
        tasks = {},
        currentTime = 0
    }, Scheduler)
end

function Scheduler:add_task(callback, delay, interval, priority)
    local task = {
        callback = callback,
        next_run = self.currentTime + (delay or 0),
        interval = interval,
        priority = priority or 0
    }
    table.insert(self.tasks, task)
    -- Sort by next_run (primary) and priority (secondary)
    table.sort(self.tasks, function(a, b)
        if a.next_run ~= b.next_run then
            return a.next_run < b.next_run
        end
        return a.priority > b.priority
    end)
    return task
end

function Scheduler:update(deltaTime)
    self.currentTime = self.currentTime + deltaTime
    
    while #self.tasks > 0 and self.tasks[1].next_run <= self.currentTime do
        local task = table.remove(self.tasks, 1)
        task.callback(self.currentTime)
        
        if task.interval then
            task.next_run = self.currentTime + task.interval
            self:add_task(task.callback, 0, task.interval, task.priority)
        end
    end
end

return Scheduler
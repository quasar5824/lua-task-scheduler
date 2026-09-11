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
        priority = priority or 0,
        cancelled = false
    }
    table.insert(self.tasks, task)
    self:_sort_tasks()
    return task
end

function Scheduler:clear()
    self.tasks = {}
end

function Scheduler:_sort_tasks()
    table.sort(self.tasks, function(a, b)
        if a.next_run ~= b.next_run then
            return a.next_run < b.next_run
        end
        return a.priority > b.priority
    end)
end

function Scheduler:update(deltaTime)
    self.currentTime = self.currentTime + deltaTime
    
    while #self.tasks > 0 and self.tasks[1].next_run <= self.currentTime do
        local task = table.remove(self.tasks, 1)
        
        if not task.cancelled then
            task.callback(self.currentTime)
            
            if task.interval then
                task.next_run = self.currentTime + task.interval
                table.insert(self.tasks, task)
                self:_sort_tasks()
            end
        end
    end
end

return Scheduler
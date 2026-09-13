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
    self:_insert_task(task)
    return task
end

function Scheduler:cancel_task(task)
    if task then
        task.cancelled = true
    end
end

function Scheduler:clear()
    self.tasks = {}
end

function Scheduler:pending_tasks()
    local count = 0
    for _, task in ipairs(self.tasks) do
        if not task.cancelled then
            count = count + 1
        end
    end
    return count
end

function Scheduler:_insert_task(task)
    local low = 1
    local high = #self.tasks
    
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local other = self.tasks[mid]
        
        local should_come_before = false
        if task.next_run < other.next_run then
            should_come_before = true
        elseif task.next_run == other.next_run then
            if task.priority > other.priority then
                should_come_before = true
            end
        end
        
        if should_come_before then
            high = mid - 1
        else
            low = mid + 1
        end
    end
    
    table.insert(self.tasks, low, task)
end

function Scheduler:update(deltaTime)
    self.currentTime = self.currentTime + deltaTime
    
    while #self.tasks > 0 and self.tasks[1].next_run <= self.currentTime do
        local task = table.remove(self.tasks, 1)
        
        if not task.cancelled then
            task.callback(self.currentTime)
            
            if task.interval then
                task.next_run = self.currentTime + task.interval
                self:_insert_task(task)
            end
        end
    end
end

return Scheduler
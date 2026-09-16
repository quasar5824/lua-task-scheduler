local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    return setmetatable({
        tasks = {},
        currentTime = 0
    }, Scheduler)
end

function Scheduler:add_task(callback, delay, interval, priority, args)
    local task = {
        callback = callback,
        next_run = self.currentTime + (delay or 0),
        interval = interval,
        priority = priority or 0,
        cancelled = false,
        args = args
    }
    self:_insert_task(task)
    return task
end

function Scheduler:cancel_task(task)
    if task then
        task.cancelled = true
    end
end

function Scheduler:remove_task(task)
    if not task then return end
    for i = 1, #self.tasks do
        if self.tasks[i] == task then
            table.remove(self.tasks, i)
            return true
        end
    end
    return false
end

function Scheduler:reschedule_task(task, new_delay)
    if not task then return false end
    
    -- To maintain the sorted order of the task list, we must remove and re-insert
    if self:remove_task(task) then
        task.next_run = self.currentTime + (new_delay or 0)
        self:_insert_task(task)
        return true
    end
    return false
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

function Scheduler:total_tasks()
    return #self.tasks
end

function Scheduler:get_tasks()
    -- Return a copy of the tasks table to avoid external modification of the queue structure
    local copy = {}
    for i, task in ipairs(self.tasks) do
        copy[i] = task
    end
    return copy
end

function Scheduler:prune_cancelled()
    local i = 1
    while i <= #self.tasks do
        if self.tasks[i].cancelled then
            table.remove(self.tasks, i)
        else
            i = i + 1
        end
    end
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
            -- Pass currentTime and any provided arguments to the callback
            local success, err = pcall(task.callback, self.currentTime, task.args)
            if not success then
                print("Task Scheduler Error: " .. tostring(err))
            end
            
            if task.interval then
                task.next_run = self.currentTime + task.interval
                self:_insert_task(task)
            end
        end
    end
end

return Scheduler
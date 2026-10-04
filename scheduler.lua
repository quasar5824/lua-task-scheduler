local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    return setmetatable({
        tasks = {},
        currentTime = 0,
        paused = false,
        nextTaskId = 1
    }, Scheduler)
end

function Scheduler:get_time()
    return self.currentTime
end

function Scheduler:set_time(time)
    self.currentTime = time or 0
end

function Scheduler:add_task(callback, delay, interval, priority, args, tag)
    local task = {
        id = self.nextTaskId,
        callback = callback,
        next_run = self.currentTime + (delay or 0),
        interval = interval,
        priority = priority or 0,
        cancelled = false,
        executed = false,
        execution_count = 0,
        args = args,
        tag = tag,
        dependencies = {}
    }
    self.nextTaskId = self.nextTaskId + 1
    self:_insert_task(task)
    return task
end

function Scheduler:add_tasks(task_list)
    if type(task_list) ~= "table" then return {}
    end
    local added = {}
    for _, t_data in ipairs(task_list) do
        local task = self:add_task(
            t_data.callback,
            t_data.delay,
            t_data.interval,
            t_data.priority,
            t_data.args,
            t_data.tag
        )
        table.insert(added, task)
    end
    return added
end

function Scheduler:wait_until(absoluteTime, callback, interval, priority, args, tag)
    local task = {
        id = self.nextTaskId,
        callback = callback,
        next_run = absoluteTime,
        interval = interval,
        priority = priority or 0,
        cancelled = false,
        executed = false,
        execution_count = 0,
        args = args,
        tag = tag,
        dependencies = {}
    }
    self.nextTaskId = self.nextTaskId + 1
    self:_insert_task(task)
    return task
end

function Scheduler:add_dependency(task, dependencyTask)
    if not task or not dependencyTask then return false end
    for _, dep in ipairs(task.dependencies) do
        if dep == dependencyTask then return true end
    end
    table.insert(task.dependencies, dependencyTask)
    return true
end

function Scheduler:get_task_by_id(id)
    if not id then return nil end
    for _, task in ipairs(self.tasks) do
        if task.id == id then
            return task
        end
    end
    return nil
end

function Scheduler:get_task_details(task)
    if not task then return nil end
    return {
        id = task.id,
        next_run = task.next_run,
        priority = task.priority,
        interval = task.interval,
        tag = task.tag,
        status = self:get_task_status(task),
        remaining = self:get_task_remaining_time(task),
        execution_count = task.execution_count
    }
end

function Scheduler:cancel_task(task)
    if task then
        task.cancelled = true
    end
end

function Scheduler:cancel_tasks_by_tag(tag)
    if not tag then return 0 end
    local count = 0
    for _, task in ipairs(self.tasks) do
        if task.tag == tag then
            task.cancelled = true
            count = count + 1
        end
    end
    return count
end

function Scheduler:cancel_tasks_by_callback(callback)
    if not callback then return 0 end
    local count = 0
    for _, task in ipairs(self.tasks) do
        if task.callback == callback then
            task.cancelled = true
            count = count + 1
        end
    end
    return count
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

function Scheduler:remove_tasks_by_tag(tag)
    if not tag then return 0 end
    local count = 0
    local i = 1
    while i <= #self.tasks do
        if self.tasks[i].tag == tag then
            table.remove(self.tasks, i)
            count = count + 1
        else
            i = i + 1
        end
    end
    return count
end

function Scheduler:remove_tasks_by_callback(callback)
    if not callback then return 0 end
    local count = 0
    local i = 1
    while i <= #self.tasks do
        if self.tasks[i].callback == callback then
            table.remove(self.tasks, i)
            count = count + 1
        else
            i = i + 1
        end
    end
    return count
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

function Scheduler:update_task(task, updates)
    if not task or not updates then return false end
    
    -- Validate that the task actually belongs to this scheduler
    local exists = false
    for _, t in ipairs(self.tasks) do
        if t == task then
            exists = true
            break
        end
    end
    if not exists then return false end

    local needs_reinsert = false
    
    if updates.delay then
        task.next_run = self.currentTime + updates.delay
        needs_reinsert = true
    end
    
    if updates.priority then
        task.priority = updates.priority
        needs_reinsert = true
    end
    
    if updates.interval then
        task.interval = updates.interval
    end
    
    if updates.tag then
        task.tag = updates.tag
    end
    
    if updates.args then
        task.args = updates.args
    end

    if needs_reinsert then
        if self:remove_task(task) then
            self:_insert_task(task)
            return true
        end
        return false
    end
    
    return true
end

function Scheduler:clear()
    self.tasks = {}
    self.nextTaskId = 1
end

function Scheduler:remove_all_tasks()
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

function Scheduler:get_active_tasks()
    local active = {}
    for _, task in ipairs(self.tasks) do
        if not task.cancelled then
            table.insert(active, task)
        end
    end
    return active
end

function Scheduler:get_tasks_by_tag(tag)
    if not tag then return {}
    end
    local filtered = {}
    for _, task in ipairs(self.tasks) do
        if task.tag == tag then
            table.insert(filtered, task)
        end
    end
    return filtered
end

function Scheduler:get_tasks_by_callback(callback)
    if not callback then return {}
    end
    local filtered = {}
    for _, task in ipairs(self.tasks) do
        if task.callback == callback then
            table.insert(filtered, task)
        end
    end
    return filtered
end

function Scheduler:get_tasks_by_priority_range(min, max)
    local filtered = {}
    local low = min or -math.huge
    local high = max or math.huge
    for _, task in ipairs(self.tasks) do
        if task.priority >= low and task.priority <= high then
            table.insert(filtered, task)
        end
    end
    return filtered
end

function Scheduler:peek_next_task()
    -- Return the first non-cancelled task in the sorted list
    for i = 1, #self.tasks do
        if not self.tasks[i].cancelled then
            return self.tasks[i]
        end
    end
    return nil
end

function Scheduler:get_next_task_time()
    local next_task = self:peek_next_task()
    return next_task and next_task.next_run or nil
end

function Scheduler:get_task_remaining_time(task)
    if not task then return nil end
    return math.max(0, task.next_run - self.currentTime)
end

function Scheduler:get_task_status(task)
    if not task then return nil end
    if task.cancelled then return "cancelled"
    end
    if task.executed then return "executed"
    end
    return "pending"
end

function Scheduler:is_task_pending(task)
    if not task then return false end
    return not task.cancelled and not task.executed
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

function Scheduler:pause()
    self.paused = true
end

function Scheduler:resume()
    self.paused = false
end

function Scheduler:is_paused()
    return self.paused
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

function Scheduler:update(deltaTime, maxExecutionTime)
    if self.paused then
        return
    end

    self.currentTime = self.currentTime + deltaTime
    self:execute_due(maxExecutionTime)
end

function Scheduler:execute_due(maxExecutionTime)
    local startTime = os.clock()
    
    -- We use a loop to check for due tasks. Since some tasks might be blocked by dependencies,
    -- we may need to iterate several times or handle the queue carefully to avoid infinite loops
    -- if tasks are mutually dependent (though that should be handled by user).
    
    local tasksToReinsert = {}
    
    while #self.tasks > 0 and self.tasks[1].next_run <= self.currentTime do
        if maxExecutionTime and (os.clock() - startTime) > maxExecutionTime then
            break
        end

        local task = table.remove(self.tasks, 1)
        
        if not task.cancelled then
            -- Check if dependencies are met
            local deps_met = true
            for _, dep in ipairs(task.dependencies) do
                if not dep.executed then
                    deps_met = false
                    break
                end
            end

            if deps_met then
                -- Pass currentTime, task object, and any provided arguments to the callback
                local success, result = pcall(task.callback, self.currentTime, task, task.args)
                if not success then
                    print("Task Scheduler Error: " .. tostring(result))
                end
                
                task.executed = true
                task.execution_count = task.execution_count + 1

                -- Task control logic
                local should_reschedule = true
                
                if type(result) == "table" then
                    if result.cancel == true then
                        should_reschedule = false
                    end
                    if result.repeat == false then
                        task.interval = nil
                    end
                    if result.priority then
                        task.priority = result.priority
                    end
                    if result.next_delay then
                        task.next_run = self.currentTime + result.next_delay
                    elseif task.interval then
                        task.next_run = task.next_run + task.interval
                    end
                elseif task.interval then
                    task.next_run = task.next_run + task.interval
                end

                if should_reschedule and (task.interval or (type(result) == "table" and result.next_delay)) then
                    -- Keep recurring
                elseif should_reschedule and not task.interval and (type(result) ~= "table" or not result.next_delay) then
                    should_reschedule = false
                end

                if should_reschedule then
                    table.insert(tasksToReinsert, task)
                end
            else
                -- Dependencies not met, re-insert for later
                table.insert(tasksToReinsert, task)
            end
        end
    end

    -- Re-insert tasks that were skipped or need to recur
    for _, t in ipairs(tasksToReinsert) do
        self:_insert_task(t)
    end
end

function Scheduler:flush_due()
    -- Executes all tasks that are due now, ignoring maxExecutionTime
    self:execute_due(nil)
end

return Scheduler
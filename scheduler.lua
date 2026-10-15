local Scheduler = {}
Scheduler.__index = Scheduler

-- Default logger
local default_logger = {
    log = function(msg) print("Task Scheduler: " .. msg) end,
    error = function(msg) print("Task Scheduler ERROR: " .. msg) end
}

function Scheduler.new()
    return setmetatable({
        tasks = {},
        groups = {},
        currentTime = 0,
        paused = false,
        nextTaskId = 1,
        logger = default_logger,
        stats = {
            total_executions = 0,
            total_execution_time = 0
        }
    }, Scheduler)
end

function Scheduler:set_logger(logger)
    if type(logger) == "table" and logger.log and logger.error then
        self.logger = logger
    else
        self.logger = default_logger
    end
end

function Scheduler:get_time()
    return self.currentTime
end

function Scheduler:set_time(time)
    self.currentTime = time or 0
end

function Scheduler:add_task(callback, delay, interval, priority, args, tag, timeout, on_complete, weight)
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
        dependencies = {},
        timeout = timeout,
        groupId = nil,
        on_complete = on_complete,
        last_result = nil,
        weight = weight or 1,
        last_execution_time = 0,
        avg_execution_time = 0
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
            t_data.tag,
            t_data.timeout,
            t_data.on_complete,
            t_data.weight
        )
        table.insert(added, task)
    end
    return added
end

function Scheduler:wait_until(absoluteTime, callback, interval, priority, args, tag, timeout, on_complete, weight)
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
        dependencies = {},
        timeout = timeout,
        groupId = nil,
        on_complete = on_complete,
        last_result = nil,
        weight = weight or 1,
        last_execution_time = 0,
        avg_execution_time = 0
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
        execution_count = task.execution_count,
        timeout = task.timeout,
        weight = task.weight,
        last_execution_time = task.last_execution_time,
        avg_execution_time = task.avg_execution_time
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
            -- Replace with last element and re-heapify
            local last = table.remove(self.tasks)
            if i <= #self.tasks then
                self.tasks[i] = last
                self:_sift_up(i)
                self:_sift_down(i)
            end
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
            self:remove_task(self.tasks[i])
            count = count + 1
            -- remove_task may have changed current index, but loop will handle
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
            self:remove_task(self.tasks[i])
            count = count + 1
        else
            i = i + 1
        end
    end
    return count
end

function Scheduler:reschedule_task(task, new_delay)
    if not task then return false end
    
    if self:remove_task(task) then
        task.next_run = self.currentTime + (new_delay or 0)
        self:_insert_task(task)
        return true
    end
    return false
end

function Scheduler:update_task(task, updates)
    if not task or not updates then return false end
    
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

    if updates.timeout then
        task.timeout = updates.timeout
    end

    if updates.weight then
        task.weight = updates.weight
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
    self.groups = {}
    self.nextTaskId = 1
    self.stats = {
        total_executions = 0,
        total_execution_time = 0
    }
end

function Scheduler:remove_all_tasks()
    self.tasks = {}
    self.groups = {}
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

function Scheduler:get_tasks_by_execution_range(min, max)
    local filtered = {}
    local low = min or 0
    local high = max or math.huge
    for _, task in ipairs(self.tasks) do
        if task.execution_count >= low and task.execution_count <= high then
            table.insert(filtered, task)
        end
    end
    return filtered
end

function Scheduler:peek_next_task()
    -- In a heap, the top is at index 1. However, it might be cancelled.
    -- To correctly peek the next non-cancelled task without modifying the heap,
    -- we must search. For efficiency, we can't simply peek index 1 if it's cancelled.
    -- However, execute_due will eventually prune it. 
    -- To maintain API compatibility: we search the heap for the one with minimum next_run
    local best = nil
    for _, task in ipairs(self.tasks) do
        if not task.cancelled then
            if not best or task.next_run < best.next_run or 
               (task.next_run == best.next_run and task.priority > best.priority) then
                best = task
            end
        end
    end
    return best
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
            if self.tasks[i].groupId then
                local gid = self.tasks[i].groupId
                local group = self.groups[gid]
                if group then
                    for j, t in ipairs(group.tasks) do
                        if t == self.tasks[i] then
                            table.remove(group.tasks, j)
                            break
                        end
                    end
                end
            end
            self:remove_task(self.tasks[i])
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

-- Group Management --

function Scheduler:create_group(groupId)
    if not groupId then return nil end
    self.groups[groupId] = {
        tasks = {},
        paused = false
    }
    return self.groups[groupId]
end

function Scheduler:add_task_to_group(task, groupId)
    if not task or not groupId then return false end
    if not self.groups[groupId] then
        self:create_group(groupId)
    end
    
    task.groupId = groupId
    table.insert(self.groups[groupId].tasks, task)
    return true
end

function Scheduler:remove_task_from_group(task)
    if not task or not task.groupId then return false end
    local group = self.groups[task.groupId]
    if not group then return false end
    
    for i, t in ipairs(group.tasks) do
        if t == task then
            table.remove(group.tasks, i)
            task.groupId = nil
            return true
        end
    end
    return false
end

function Scheduler:pause_group(groupId)
    if self.groups[groupId] then
        self.groups[groupId].paused = true
        return true
    end
    return false
end

function Scheduler:resume_group(groupId)
    if self.groups[groupId] then
        self.groups[groupId].paused = false
        return true
    end
    return false
end

function Scheduler:cancel_group(groupId)
    if not self.groups[groupId] then return 0 end
    local count = 0
    for _, task in ipairs(self.groups[groupId].tasks) do
        if not task.cancelled then
            task.cancelled = true
            count = count + 1
        end
    end
    return count
end

function Scheduler:get_group_tasks(groupId)
    if not self.groups[groupId] then return {} end
    local copy = {}
    for i, t in ipairs(self.groups[groupId].tasks) do
        copy[i] = t
    end
    return copy
end

function Scheduler:_insert_task(task)
    table.insert(self.tasks, task)
    self:_sift_up(#self.tasks)
end

function Scheduler:_sift_up(idx)
    local task = self.tasks[idx]
    while idx > 1 do
        local parentIdx = math.floor(idx / 2)
        local parent = self.tasks[parentIdx]
        
        if self:_compare_tasks(task, parent) then
            self.tasks[idx] = parent
            idx = parentIdx
        else
            break
        end
    end
    self.tasks[idx] = task
end

function Scheduler:_sift_down(idx)
    local count = #self.tasks
    local task = self.tasks[idx]
    while true do
        local left = 2 * idx
        local right = 2 * idx + 1
        local smallest = nil

        if left <= count then
            smallest = self.tasks[left]
        end

        if right <= count then
            local rightTask = self.tasks[right]
            if not smallest or self:_compare_tasks(rightTask, smallest) then
                smallest = rightTask
            end
        end

        if smallest and self:_compare_tasks(smallest, task) then
            local smallestIdx = (smallest == self.tasks[2 * idx]) and (2 * idx) or (2 * idx + 1)
            self.tasks[idx] = smallest
            idx = smallestIdx
        else
            break
        end
    end
    self.tasks[idx] = task
end

function Scheduler:_compare_tasks(a, b)
    if a.next_run < b.next_run then
        return true
    elseif a.next_run == b.next_run then
        return a.priority > b.priority
    end
    return false
end

function Scheduler:update(deltaTime, maxExecutionTime, maxTasks)
    if self.paused then
        return
    end

    self.currentTime = self.currentTime + deltaTime
    self:execute_due(maxExecutionTime, maxTasks)
end

function Scheduler:execute_due(maxExecutionTime, maxTasks)
    local startTime = os.clock()
    local tasksExecuted = 0
    
    local tasksToReinsert = {}
    
    while #self.tasks > 0 and self.tasks[1].next_run <= self.currentTime do
        if maxExecutionTime and (os.clock() - startTime) > maxExecutionTime then
            break
        end

        if maxTasks and tasksExecuted >= maxTasks then
            break
        end

        -- Pop root
        local task = table.remove(self.tasks, 1)
        if #self.tasks > 0 then
            self.tasks[1] = table.remove(self.tasks)
            self:_sift_down(1)
        end
        
        if not task.cancelled then
            local group_paused = false
            if task.groupId then
                local group = self.groups[task.groupId]
                if group and group.paused then
                    group_paused = true
                end
            end

            if group_paused then
                table.insert(tasksToReinsert, task)
            else
                if task.timeout and (self.currentTime - (task.next_run - (task.interval or 0)) > task.timeout) then
                    task.cancelled = true
                else
                    local deps_met = true
                    for _, dep in ipairs(task.dependencies) do
                        if not dep.executed then
                            deps_met = false
                            break
                        end
                    end

                    if deps_met then
                        local task_start = os.clock()
                        local success, result = pcall(task.callback, self.currentTime, task, task.args)
                        local task_end = os.clock()
                        local duration = task_end - task_start

                        if not success then
                            self.logger.error("Task Scheduler Error: " .. tostring(result))
                        end
                        
                        -- Update performance metrics
                        task.last_execution_time = duration
                        task.avg_execution_time = (task.avg_execution_time * task.execution_count + duration) / (task.execution_count + 1)
                        self.stats.total_executions = self.stats.total_executions + 1
                        self.stats.total_execution_time = self.stats.total_execution_time + duration

                        task.executed = true
                        task.execution_count = task.execution_count + 1
                        task.last_result = result
                        tasksExecuted = tasksExecuted + 1

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

                        if not should_reschedule and task.on_complete then
                            pcall(task.on_complete, self.currentTime, task, result)
                        end

                        if should_reschedule then
                            table.insert(tasksToReinsert, task)
                        end
                    else
                        table.insert(tasksToReinsert, task)
                    end
                end
            end
        end
    end

    for _, t in ipairs(tasksToReinsert) do
        self:_insert_task(t)
    end
end

function Scheduler:flush_due()
    self:execute_due(nil)
end

-- Weighted Selection --

function Scheduler:weighted_select_due()
    local due_tasks = {}
    local total_weight = 0
    
    for _, task in ipairs(self.tasks) do
        if not task.cancelled and task.next_run <= self.currentTime then
            local deps_met = true
            for _, dep in ipairs(task.dependencies) do
                if not dep.executed then
                    deps_met = false
                    break
                end
            end
            
            if deps_met then
                local w = task.weight or 1
                table.insert(due_tasks, {task = task, weight = w})
                total_weight = total_weight + w
            end
        end
    end
    
    if #due_tasks == 0 then return nil end
    
    local random_val = math.random() * total_weight
    local current_sum = 0
    
    for _, entry in ipairs(due_tasks) do
        current_sum = current_sum + entry.weight
        if random_val <= current_sum then
            return entry.task
        end
    end
    
    return due_tasks[#due_tasks].task
end

-- Serialization --

function Scheduler:serialize(callback_map)
    -- callback_map should be a table mapping function references to string IDs
    local state = {
        currentTime = self.currentTime,
        paused = self.paused,
        nextTaskId = self.nextTaskId,
        groups = {},
        tasks = {},
        stats = self.stats
    }

    for groupId, group in pairs(self.groups) do
        state.groups[groupId] = {
            paused = group.paused
        }
    end

    for _, task in ipairs(self.tasks) do
        local callback_id = callback_map[task.callback]
        if not callback_id then
            callback_id = "unknown"
        end

        table.insert(state.tasks, {
            id = task.id,
            callback_id = callback_id,
            next_run = task.next_run,
            interval = task.interval,
            priority = task.priority,
            cancelled = task.cancelled,
            executed = task.executed,
            execution_count = task.execution_count,
            args = task.args,
            tag = task.tag,
            timeout = task.timeout,
            groupId = task.groupId,
            last_result = task.last_result,
            weight = task.weight,
            last_execution_time = task.last_execution_time,
            avg_execution_time = task.avg_execution_time
        })
    end

    return state
end

function Scheduler:deserialize(state, callback_map)
    -- callback_map should be a table mapping string IDs to function references
    if not state then return false end

    self.currentTime = state.currentTime or 0
    self.paused = state.paused or false
    self.nextTaskId = state.nextTaskId or 1
    self.tasks = {}
    self.groups = {}
    self.stats = state.stats or {
        total_executions = 0,
        total_execution_time = 0
    }

    for groupId, group_state in pairs(state.groups or {}) do
        self:create_group(groupId)
        self.groups[groupId].paused = group_state.paused
    end

    for _, t_state in ipairs(state.tasks or {}) do
        local callback = callback_map[t_state.callback_id]
        if callback then
            local task = {
                id = t_state.id,
                callback = callback,
                next_run = t_state.next_run,
                interval = t_state.interval,
                priority = t_state.priority,
                cancelled = t_state.cancelled,
                executed = t_state.executed,
                execution_count = t_state.execution_count,
                args = t_state.args,
                tag = t_state.tag,
                dependencies = {},
                timeout = t_state.timeout,
                groupId = t_state.groupId,
                on_complete = nil, -- Not serialized
                last_result = t_state.last_result,
                weight = t_state.weight or 1,
                last_execution_time = t_state.last_execution_time or 0,
                avg_execution_time = t_state.avg_execution_time or 0
            }
            
            if task.groupId then
                if not self.groups[task.groupId] then
                    self:create_group(task.groupId)
                end
                table.insert(self.groups[task.groupId].tasks, task)
            end

            self:_insert_task(task)
        end
    end

    return true
end

function Scheduler:get_performance_report()
    local total_execs = self.stats.total_executions
    local total_time = self.stats.total_execution_time
    
    return {
        total_executions = total_execs,
        total_execution_time = total_time,
        average_execution_time = total_execs > 0 and (total_time / total_execs) or 0,
        active_tasks = self:pending_tasks()
    }
end

return Scheduler
-- 战斗日志处理模块
local skynet = require "skynet"
local log = require "log"
local json = require "json"

local battle_log = {}

-- 生成时间戳字符串，格式为 HH:MM:SS
local function format_timestamp(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- 生成不均匀的时间间隔
local function generate_uneven_timestamps(total_duration, count)
    if count <= 0 then
        return {}
    end

    -- 确保时间戳数量不超过总时长(秒)
    count = math.min(count, total_duration + 1) -- +1 是因为我们包含了0和total_duration

    -- 如果请求的时间点数量超过了可用的不重复时间点数量
    if count > total_duration + 1 then
        log.warn("请求的时间点数量(%d)超过了可用的不重复时间点数量(%d)", count, total_duration + 1)
        count = total_duration + 1
    end

    -- 生成随机的时间点
    local timestamps = {}
    local time_set = {} -- 用于快速检查时间点是否已存在

    -- 添加起始时间点
    timestamps[1] = 0
    time_set[0] = true

    -- 添加结束时间点
    timestamps[2] = total_duration
    time_set[total_duration] = true

    -- 生成中间的时间点
    local remaining = count - 2
    if remaining > 0 then
        -- 使用随机数生成中间时间点
        math.randomseed(os.time() + os.clock() * 1000)

        -- 尝试生成不重复的时间点
        local attempts = 0
        local max_attempts = total_duration * 2 -- 设置最大尝试次数，避免无限循环

        while #timestamps < count and attempts < max_attempts do
            -- 生成1到total_duration-1之间的随机数
            local time_point = math.random(1, total_duration - 1)

            -- 检查是否已存在该时间点
            if not time_set[time_point] then
                table.insert(timestamps, time_point)
                time_set[time_point] = true
            end

            attempts = attempts + 1
        end

        -- 如果尝试次数过多但仍未生成足够的时间点，则顺序填充剩余时间点
        if #timestamps < count then
            log.warn("无法生成足够的不重复随机时间点，使用顺序填充")
            for i = 1, total_duration - 1 do
                if not time_set[i] and #timestamps < count then
                    table.insert(timestamps, i)
                    time_set[i] = true
                end
            end
        end

        -- 排序时间点
        table.sort(timestamps)
    end

    return timestamps
end

-- 获取战斗日志阶段信息
local function get_battle_log_stages()
    local result, err = skynet.call(".dbproxyd", "lua", "query", {
        sql = [[
            SELECT stage_id, stage_name, process_id, process_name, process_type, script_lib_id, script_count
            FROM battle_log_stage
            ORDER BY stage_id, process_id
        ]],
        params = {}
    })

    if not result then
        log.error("获取战斗日志阶段信息失败: %s", err)
        return nil, err
    end

    return result
end

-- 获取会员信息
local function get_member_info(member_ids)
    if not member_ids or #member_ids == 0 then
        return {}
    end

    -- 构建IN查询的参数列表
    local params = {}
    for _, id in ipairs(member_ids) do
        table.insert(params, id)
    end

    -- 构建IN查询的占位符
    local placeholders = {}
    for i = 1, #params do
        table.insert(placeholders, "?")
    end

    local sql = string.format([[
        SELECT member_id, nickname as member_name, profession_id, position
        FROM player_member
        WHERE member_id IN (%s)
    ]], table.concat(placeholders, ","))

    local result, err = skynet.call(".dbproxyd", "lua", "query", {
        sql = sql,
        params = params
    })

    if not result then
        log.error("获取会员信息失败: %s", err)
        return {}
    end

    -- 转换为以member_id为键的表
    local members = {}
    for _, member in ipairs(result) do
        members[member.member_id] = {
            name = member.member_name,
            profession_id = member.profession_id,
            position = member.position
        }
    end

    return members
end

-- 获取Boss信息
local function get_boss_info(boss_id)
    if not boss_id then
        return nil
    end

    local result, err = skynet.call(".dbproxyd", "lua", "query", {
        sql = "SELECT boss_id, boss_name FROM boss WHERE boss_id = ?",
        params = { boss_id }
    })

    if not result or #result == 0 then
        log.error("获取Boss信息失败: %s", err or "未找到Boss")
        return nil
    end

    return result[1]
end

-- 获取特定阶段和过程的话术
local function get_battle_scripts(script_lib_id, profession_id, count)
    local params = { script_lib_id }
    local profession_condition = ""

    if profession_id then
        profession_condition = " AND (profession_id = ? OR profession_id IS NULL)"
        table.insert(params, profession_id)
    else
        profession_condition = " AND (profession_id IS NULL)"
    end

    local sql = string.format([[
        SELECT script_id, character_name, profession_id, log_text
        FROM battle_log_script
        WHERE script_lib_id = ?%s
        ORDER BY RAND()
        LIMIT ?
    ]], profession_condition)

    table.insert(params, count)

    local result, err = skynet.call(".dbproxyd", "lua", "query", {
        sql = sql,
        params = params
    })

    if not result then
        log.error("获取战斗话术失败: %s", err)
        return {}
    end

    return result
end

-- 根据过程类型选择合适的角色
local function select_character_by_process_type(process_type, boss_info, members, member_ids)
    if process_type == "1" then                            -- Boss话术
        return boss_info and boss_info.boss_name or "拉格纳罗斯"
    elseif process_type == "2" or process_type == "3" then -- 会员通用话术或专属话术
        if #member_ids > 0 then
            -- 随机选择一个会员
            local random_index = math.random(1, #member_ids)
            local member_id = member_ids[random_index]
            local member = members[member_id]
            if member then
                return member.name, member.profession_id, member_id
            end
        end
    end

    -- 默认返回团长
    return "团长", nil, nil
end

-- 生成PVE战斗日志
function battle_log.generate_pve_battle_log(battle_id, boss_id, member_ids, is_win, battle_duration)
    log.info("生成PVE战斗日志: battle_id=%s, boss_id=%s, is_win=%s, duration=%s",
        battle_id,
        boss_id,
        is_win and "是" or "否",
        tostring(battle_duration))


    -- 参数校验
    if not battle_id then
        return nil, "缺少战斗ID参数"
    end

    if not boss_id then
        return nil, "缺少Boss ID参数"
    end

    if not member_ids or #member_ids == 0 then
        return nil, "缺少参战会员ID参数"
    end

    if is_win == nil then
        return nil, "缺少战斗结果参数"
    end

    -- 获取Boss信息
    local boss_info = get_boss_info(boss_id)
    if not boss_info then
        log.warn("未找到Boss信息，使用默认值")
        boss_info = { boss_id = boss_id, boss_name = "拉格纳罗斯" }
    end

    -- 获取会员信息
    local members = get_member_info(member_ids)
    if not members or next(members) == nil then
        log.warn("未找到会员信息，使用默认值")
    end

    -- 获取战斗日志阶段信息
    local stages, err = get_battle_log_stages()
    if not stages then
        return nil, "获取战斗日志阶段信息失败: " .. (err or "未知错误")
    end

    -- 根据战斗结果选择合适的阶段
    local filtered_stages = {}
    for _, stage in ipairs(stages) do
        -- 如果是结束阶段，根据战斗结果筛选
        if stage.stage_id == "stage-3" then
            if (is_win and stage.process_id == "process-3-1") or
                (not is_win and stage.process_id == "process-3-2") or
                (is_win and stage.process_id == "process-3-3") then
                table.insert(filtered_stages, stage)
            end
        else
            table.insert(filtered_stages, stage)
        end
    end

    -- 计算总话术数量
    local total_script_count = 0
    for _, stage in ipairs(filtered_stages) do
        total_script_count = total_script_count + tonumber(stage.script_count or 0)
    end

    -- 生成不均匀的时间戳
    local time_points = generate_uneven_timestamps(battle_duration, total_script_count)

    -- 准备批量插入的日志数据
    local logs = {}
    local time_index = 1

    -- 随机打乱阶段顺序，但保持相同stage_id的阶段相邻
    local stage_groups = {}
    local current_stage_id = nil
    local current_group = {}

    for _, stage in ipairs(filtered_stages) do
        if stage.stage_id ~= current_stage_id then
            if #current_group > 0 then
                table.insert(stage_groups, current_group)
            end
            current_stage_id = stage.stage_id
            current_group = { stage }
        else
            table.insert(current_group, stage)
        end
    end

    if #current_group > 0 then
        table.insert(stage_groups, current_group)
    end

    -- 根据阶段ID排序组
    table.sort(stage_groups, function(a, b)
        return a[1].stage_id < b[1].stage_id
    end)

    -- 处理每个阶段组
    for _, group in ipairs(stage_groups) do
        -- 在每个组内随机排序过程
        for i = 1, #group do
            local j = math.random(i, #group)
            group[i], group[j] = group[j], group[i]
        end

        -- 处理每个阶段的话术
        for _, stage in ipairs(group) do
            local script_count = tonumber(stage.script_count or 0)
            if script_count > 0 then
                -- 根据过程类型选择角色
                local character_name, profession_id, member_id = select_character_by_process_type(
                    stage.process_type,
                    boss_info,
                    members,
                    member_ids
                )

                -- 获取话术
                local scripts = get_battle_scripts(stage.script_lib_id, profession_id, script_count)

                -- 如果没有找到匹配的话术，尝试获取通用话术
                if #scripts == 0 and profession_id then
                    scripts = get_battle_scripts(stage.script_lib_id, nil, script_count)
                end

                -- 如果仍然没有找到话术，使用默认话术
                if #scripts == 0 then
                    for i = 1, script_count do
                        if time_index <= #time_points then
                            table.insert(logs, {
                                battle_id = battle_id,
                                battle_timestamp = format_timestamp(time_points[time_index]),
                                character_name = character_name,
                                log_text = string.format("战斗阶段 %s - %s", stage.stage_name, stage.process_name),
                                remarks = "自动生成的默认战斗日志"
                            })
                            time_index = time_index + 1
                        end
                    end
                else
                    -- 使用获取到的话术
                    for _, script in ipairs(scripts) do
                        if time_index <= #time_points then
                            -- 如果话术中有指定角色名，优先使用
                            local final_character_name = script.character_name or character_name

                            table.insert(logs, {
                                battle_id = battle_id,
                                battle_timestamp = format_timestamp(time_points[time_index]),
                                character_name = final_character_name,
                                log_text = script.log_text,
                                remarks = string.format("阶段:%s,过程:%s", stage.stage_name, stage.process_name)
                            })
                            time_index = time_index + 1
                        end
                    end
                end
            end
        end
    end

    -- 按时间戳排序
    table.sort(logs, function(a, b)
        return a.battle_timestamp < b.battle_timestamp
    end)

    -- 批量插入日志记录
    if #logs > 0 then
        local placeholders = {}
        local values = {}

        for _, log_entry in ipairs(logs) do
            table.insert(placeholders, "(?, ?, ?, ?, ?)")
            table.insert(values, log_entry.battle_id)
            table.insert(values, log_entry.battle_timestamp)
            table.insert(values, log_entry.character_name)
            table.insert(values, log_entry.log_text)
            table.insert(values, log_entry.remarks)
        end

        local sql = string.format([[
            INSERT INTO pve_battle_log
            (battle_id, battle_timestamp, character_name, log_text, remarks)
            VALUES %s
        ]], table.concat(placeholders, ","))

        local result, err = skynet.call(".dbproxyd", "lua", "query", {
            sql = sql,
            params = values
        })

        if not result then
            log.error("插入战斗日志失败: %s", err)
            return nil, "插入战斗日志失败: " .. (err or "未知错误")
        end

        log.info("成功生成战斗日志 %d 条，战斗ID: %s", #logs, battle_id)
    else
        log.warn("没有生成任何战斗日志，战斗ID: %s", battle_id)
    end

    return {
        success = true,
        message = string.format("成功生成战斗日志 %d 条", #logs),
        log_count = #logs
    }
end

-- 获取战斗日志
function battle_log.get_battle_logs(battle_id, page, num)
    log.info("获取战斗日志: battle_id=%s, page=%s, num=%s",
        battle_id, page or 1, num or 10)

    -- 参数校验
    if not battle_id then
        return nil, "缺少战斗ID参数"
    end

    page = tonumber(page) or 1
    num = tonumber(num) or 10

    -- 计算偏移量
    local offset = (page - 1) * num

    -- 查询总记录数
    local count_result, count_err = skynet.call(".dbproxyd", "lua", "query", {
        sql = "SELECT COUNT(*) as total FROM pve_battle_log WHERE battle_id = ?",
        params = { battle_id }
    })

    if not count_result then
        log.error("查询战斗日志总数失败: %s", count_err)
        return nil, "查询战斗日志总数失败: " .. (count_err or "未知错误")
    end

    local total = tonumber(count_result[1].total) or 0

    -- 如果没有记录，直接返回空结果
    if total == 0 then
        return {
            total = 0,
            page = page,
            num = num,
            logs = {}
        }
    end

    -- 查询分页数据
    local logs_result, logs_err = skynet.call(".dbproxyd", "lua", "query", {
        sql = [[
            SELECT log_id, battle_id, battle_timestamp as timestamp, character_name, log_text
            FROM pve_battle_log
            WHERE battle_id = ?
            ORDER BY battle_timestamp
            LIMIT ? OFFSET ?
        ]],
        params = { battle_id, num, offset }
    })

    if not logs_result then
        log.error("查询战斗日志失败: %s", logs_err)
        return nil, "查询战斗日志失败: " .. (logs_err or "未知错误")
    end

    -- 转换结果格式
    local logs = {}
    for _, row in ipairs(logs_result) do
        table.insert(logs, {
            timestamp = row.timestamp,
            character_name = row.character_name,
            log_text = row.log_text
        })
    end

    return {
        total = total,
        page = page,
        num = #logs,
        logs = logs
    }
end

return battle_log

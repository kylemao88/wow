local skynet = require "skynet"
local log = require "log"
local sproto_client = require "sproto_client"

-- Sproto消息处理器表
local handler = {}

-- 示例：处理ping消息
handler["ping"] = function(ws, args)
    log.info("收到ping请求")
    return {}
end

-- 示例：处理signup消息
handler["signup"] = function(ws, args)
    log.info("收到注册请求: userid=%s", args.userid)
    return { ok = true }
end

-- 示例：处理signin消息
handler["signin"] = function(ws, args)
    log.info("收到登录请求: userid=%s", args.userid)
    return { ok = true }
end

-- 示例：处理login消息
handler["login"] = function(ws, args)
    log.info("收到登录请求")
    -- 发送欢迎推送消息
    sproto_client.push(ws, "push", { text = "欢迎使用Sproto协议!" })
    return { ok = true }
end

-- 获取玩家会员信息
handler["get_player_member"] = function(ws, args)
    log.info("收到获取玩家会员信息请求: player_id=%s", tostring(args.player_id))

    -- 从MySQL数据库获取玩家会员信息
    local result, err = skynet.call(".dbproxyd", "lua", "query", {
        sql = "SELECT " ..
            "pm.member_id, pm.nickname, pm.gender, " ..
            "pm.profession_id, p.profession_name as profession_name, " ..
            "pm.race_id, r.race_name as race_name, " ..
            "pm.talent_id, t.talent_name as talent_name, " ..
            "pm.position, pm.equipment_level " ..
            "FROM player_member pm " ..
            "LEFT JOIN profession p ON pm.profession_id = p.profession_id " ..
            "LEFT JOIN race r ON pm.race_id = r.race_id " ..
            "LEFT JOIN talent t ON pm.talent_id = t.talent_id " ..
            "WHERE pm.player_id = ?",
        params = { args.player_id }
    })

    -- 处理查询结果
    if not result then
        log.error("数据库查询失败，玩家ID:%s 错误:%s", args.player_id, err)
        return {
            ok = false,
            error = {
                code = "DB_ERROR",
                message = "数据库查询失败: " .. (err or "未知错误")
            },
            members = {}
        }
    end
    log.info("数据库查询成功，玩家ID:%s #result:%d", args.player_id, #result)

    -- 检查玩家是否存在
    if #result == 0 then
        log.info("未找到玩家会员信息，玩家ID:%s", args.player_id)
        return {
            ok = true, -- 查询成功，只是没有数据
            members = {}
        }
    end

    -- 转换数据类型
    local members = {}
    for _, row in ipairs(result) do
        table.insert(members, {
            member_id = row.member_id,
            nickname = row.nickname or "",
            gender = tonumber(row.gender) or 0,
            profession_id = row.profession_id or "",
            profession_name = row.profession_name or "",
            race_id = row.race_id or "",
            race_name = row.race_name or "",
            talent_id = row.talent_id or "",
            talent_name = row.talent_name or "",
            position = row.position or "",
            equipment_level = tonumber(row.equipment_level) or 0
        })
    end

    log.info("成功获取玩家会员信息，玩家ID:%s 会员数量:%d", args.player_id, #members)
    return {
        ok = true,
        members = members
    }
end

-- 获取Boss信息
handler["get_boss_info"] = function(ws, args)
    log.info("收到获取Boss信息请求: boss_id=%s", tostring(args.boss_id))

    -- 从MySQL数据库获取Boss信息
    local result, err = skynet.call(".dbproxyd", "lua", "query", {
        sql = "SELECT " ..
            "boss_id, boss_name, boss_level, min_required_level, " ..
            "tank_required, healer_required, dps_required, " ..
            "battle_time_limit, remarks " ..
            "FROM boss " ..
            "WHERE boss_id = ?",
        params = { args.boss_id }
    })

    -- 处理查询结果
    if not result then
        log.error("数据库查询失败，Boss ID:%s 错误:%s", args.boss_id, err)
        return {
            ok = false,
            error = {
                code = "DB_ERROR",
                message = "数据库查询失败: " .. (err or "未知错误")
            }
        }
    end
    log.info("数据库查询成功，Boss ID:%s #result:%d", args.boss_id, #result)

    -- 检查Boss是否存在
    if #result == 0 then
        log.info("未找到Boss信息，Boss ID:%s", args.boss_id)
        return {
            ok = false,
            error = {
                code = "BOSS_NOT_FOUND",
                message = "未找到指定的Boss信息"
            }
        }
    end

    -- 转换数据类型
    local row = result[1] -- 只取第一条记录
    local boss_info = {
        boss_id = row.boss_id,
        boss_name = row.boss_name or "",
        boss_level = tonumber(row.boss_level) or 0,
        min_required_level = tonumber(row.min_required_level) or 0,
        tank_required = tonumber(row.tank_required) or 2,
        healer_required = tonumber(row.healer_required) or 4,
        dps_required = tonumber(row.dps_required) or 15,
        battle_time_limit = tonumber(row.battle_time_limit) or 60,
        remarks = row.remarks or ""
    }

    log.info("成功获取Boss信息，Boss ID:%s 名称:%s", args.boss_id, boss_info.boss_name)
    return {
        ok = true,
        boss = boss_info
    }
end

-- PVE玩家选择会员备战接口
handler["pve_prepare_battle"] = function(ws, args)
    log.info("收到PVE备战请求: player_id=%s, boss_id=%s, 会员数量=%d",
        tostring(args.player_id), tostring(args.boss_id), #(args.member_ids or {}))

    -- 检查参数
    if not args.player_id or not args.boss_id or not args.member_ids or #args.member_ids == 0 then
        return {
            ok = false,
            error = {
                code = "INVALID_PARAMS",
                message = "缺少必要参数或会员列表为空"
            }
        }
    end

    -- 1. 对参战会员ID列表去重
    local member_set = {}
    local unique_members = {}
    for _, member_id in ipairs(args.member_ids) do
        if not member_set[member_id] then
            member_set[member_id] = true
            table.insert(unique_members, member_id)
        end
    end

    -- 2. 检查会员是否都属于该玩家
    local member_ids_str = table.concat(unique_members, "','")
    local check_sql = string.format([[
        SELECT member_id FROM player_member
         WHERE player_id = ? AND member_id IN ('%s')
    ]], member_ids_str)

    local result, err = skynet.call(".dbproxyd", "lua", "query", {
        sql = check_sql,
        params = { args.player_id }
    })

    if not result then
        log.error("数据库查询失败，玩家ID:%s 错误:%s", args.player_id, err)
        return {
            ok = false,
            error = {
                code = "DB_ERROR",
                message = "数据库查询失败: " .. (err or "未知错误")
            }
        }
    end

    -- 检查所有会员是否都属于该玩家
    local valid_members = {}
    local valid_member_set = {}
    for _, row in ipairs(result) do
        valid_member_set[row.member_id] = true
        table.insert(valid_members, row.member_id)
    end

    local invalid_members = {}
    for _, member_id in ipairs(unique_members) do
        if not valid_member_set[member_id] then
            table.insert(invalid_members, member_id)
        end
    end

    if #invalid_members > 0 then
        log.error("存在无效会员ID，玩家ID:%s, 无效会员:%s", args.player_id, table.concat(invalid_members, ","))
        return {
            ok = false,
            error = {
                code = "INVALID_MEMBERS",
                message = "以下会员ID不属于该玩家: " .. table.concat(invalid_members, ", ")
            }
        }
    end

    -- 3. 检查Boss是否存在
    local boss_result, boss_err = skynet.call(".dbproxyd", "lua", "query", {
        sql = "SELECT boss_id FROM boss WHERE boss_id = ?",
        params = { args.boss_id }
    })

    if not boss_result or #boss_result == 0 then
        log.error("Boss不存在，Boss ID:%s", args.boss_id)
        return {
            ok = false,
            error = {
                code = "BOSS_NOT_FOUND",
                message = "指定的Boss不存在"
            }
        }
    end

    -- 4. 生成唯一战斗ID
    local battle_id = string.format("battle_%s_%s_%d",
        args.player_id, args.boss_id, os.time())

    -- 5. 将会员ID列表转换为JSON格式
    local json = require "json"
    local battle_members_json = json.encode(valid_members)

    -- 6. 记录备战信息到数据库
    local insert_result, insert_err = skynet.call(".dbproxyd", "lua", "query", {
        sql = [[
            INSERT INTO player_pve_battle
            (battle_id, player_id, boss_id, battle_start_time, battle_members, battle_status, remarks)
            VALUES (?, ?, ?, NOW(), ?, 0, '玩家备战中')
        ]],
        params = { battle_id, args.player_id, args.boss_id, battle_members_json }
    })

    if not insert_result then
        log.error("记录备战信息失败，玩家ID:%s Boss ID:%s 错误:%s",
            args.player_id, args.boss_id, insert_err)
        return {
            ok = false,
            error = {
                code = "DB_ERROR",
                message = "记录备战信息失败: " .. (insert_err or "未知错误")
            }
        }
    end

    log.info("PVE备战成功，玩家ID:%s Boss ID:%s 战斗ID:%s 参战会员数:%d",
        args.player_id, args.boss_id, battle_id, #valid_members)

    return {
        ok = true,
        battle_id = battle_id,
        ready_status = true
    }
end

-- PVE玩家战斗接口
handler["pve_battle"] = function(ws, args)
    log.info("收到PVE战斗请求: battle_id=%s", tostring(args.battle_id))

    -- 检查参数
    if not args.battle_id then
        return {
            ok = false,
            error = {
                code = "INVALID_PARAMS",
                message = "缺少必要参数battle_id"
            }
        }
    end

    -- 1. 检查battle_id的有效性，获取战斗相关信息
    local battle_result, battle_err = skynet.call(".dbproxyd", "lua", "query", {
        sql = [[
            SELECT battle_id, player_id, boss_id, battle_members, battle_status, retry_count, battle_duration_phases
            FROM player_pve_battle
            WHERE battle_id = ?
        ]],
        params = { args.battle_id }
    })

    if not battle_result then
        log.error("数据库查询失败，战斗ID:%s 错误:%s", args.battle_id, battle_err)
        return {
            ok = false,
            error = {
                code = "DB_ERROR",
                message = "数据库查询失败: " .. (battle_err or "未知错误")
            }
        }
    end

    -- 检查战斗是否存在
    if #battle_result == 0 then
        log.error("战斗不存在，战斗ID:%s", args.battle_id)
        return {
            ok = false,
            error = {
                code = "BATTLE_NOT_FOUND",
                message = "指定的战斗不存在"
            }
        }
    end

    local battle_info = battle_result[1]
    local player_id = battle_info.player_id
    local boss_id = battle_info.boss_id
    local battle_status = tonumber(battle_info.battle_status) or 0     -- 战斗状态(0-未开始,1-进行中,2-已结束)
    local current_retry_count = tonumber(battle_info.retry_count) or 0 -- 当前重开次数

    -- 解析已有的战斗时长记录
    local json = require "json"
    local battle_duration_phases = {}
    if battle_info.battle_duration_phases and battle_info.battle_duration_phases ~= "" then
        local ok, result = pcall(function()
            return json.decode(battle_info.battle_duration_phases)
        end)
        if ok and result then
            battle_duration_phases = result
        else
            log.error("解析战斗时长记录失败: %s", tostring(result))
            battle_duration_phases = {}
        end
    end

    -- 2. 判断战斗是否已结束且不可重试
    if battle_status == 2 then
        log.info("战斗已结束且不可重试，战斗ID:%s", args.battle_id)
        return {
            ok = false,
            error = {
                code = "BATTLE_ENDED",
                message = "该战斗已结束且不可重试"
            }
        }
    end

    -- 3. 获取Boss信息，包括重开次数上限和战斗时长设定
    local boss_result, boss_err = skynet.call(".dbproxyd", "lua", "query", {
        sql = [[
            SELECT boss_level, min_required_level, tank_required, healer_required, dps_required,
                   battle_time_limit, max_retry_count
            FROM boss
            WHERE boss_id = ?
        ]],
        params = { boss_id }
    })

    if not boss_result or #boss_result == 0 then
        log.error("Boss不存在，Boss ID:%s", boss_id)
        return {
            ok = false,
            error = {
                code = "BOSS_NOT_FOUND",
                message = "指定的Boss不存在"
            }
        }
    end

    local boss_info = boss_result[1]
    local boss_level = tonumber(boss_info.boss_level) or 0
    local min_required_level = tonumber(boss_info.min_required_level) or 0
    local tank_required = tonumber(boss_info.tank_required) or 2
    local healer_required = tonumber(boss_info.healer_required) or 4
    local dps_required = tonumber(boss_info.dps_required) or 15
    local battle_time_limit = tonumber(boss_info.battle_time_limit) or 300 -- boss战斗时长设定
    local max_retry_count = tonumber(boss_info.max_retry_count) or 3       -- boss战斗重开次数上限

    -- 检查是否已达到重开次数上限
    if current_retry_count >= max_retry_count then
        log.info("已达到重开次数上限，战斗ID:%s 当前重开次数:%d 上限:%d",
            args.battle_id, current_retry_count, max_retry_count)
        return {
            ok = false,
            error = {
                code = "MAX_RETRY_REACHED",
                message = "已达到重开次数上限"
            }
        }
    end

    -- 解析参战会员ID列表
    local battle_members = json.decode(battle_info.battle_members)
    if not battle_members or #battle_members == 0 then
        log.error("参战会员列表为空，战斗ID:%s", args.battle_id)
        return {
            ok = false,
            error = {
                code = "INVALID_BATTLE_MEMBERS",
                message = "参战会员列表为空"
            }
        }
    end

    -- 4. 获取参战会员信息
    local member_ids_str = table.concat(battle_members, "','")
    local members_sql = string.format([[
        SELECT member_id, position, equipment_level
        FROM player_member
        WHERE player_id = ? AND member_id IN ('%s')
    ]], member_ids_str)

    local members_result, members_err = skynet.call(".dbproxyd", "lua", "query", {
        sql = members_sql,
        params = { player_id }
    })

    if not members_result then
        log.error("获取参战会员信息失败，玩家ID:%s 错误:%s", player_id, members_err)
        return {
            ok = false,
            error = {
                code = "DB_ERROR",
                message = "获取参战会员信息失败: " .. (members_err or "未知错误")
            }
        }
    end

    -- 5. 计算胜率
    -- 统计会员装备等级总和和各职业数量
    local total_equipment_level = 0
    local tank_count = 0
    local healer_count = 0
    local dps_count = 0

    for _, member in ipairs(members_result) do
        total_equipment_level = total_equipment_level + (tonumber(member.equipment_level) or 0)

        local position = member.position and string.lower(member.position) or ""
        if position == "tank" or position == "t" or position == "T" then
            tank_count = tank_count + 1
        elseif position == "healer" or position == "n" or position == "N" then
            healer_count = healer_count + 1
        elseif position == "dps" or position == "d" then
            dps_count = dps_count + 1
        end
    end

    -- 计算会员平均装备等级
    local member_count = #members_result
    local avg_equipment_level = member_count > 0 and (total_equipment_level / member_count) or 0

    log.info("战斗统计 - 战斗ID:%s, 平均装等:%f, 坦克:%d, 治疗:%d, 输出:%d",
        args.battle_id, avg_equipment_level, tank_count, healer_count, dps_count)

    -- 应用胜率公式
    -- 胜率公式: 6*(x-z)/y+(A-a)/(a+A)+(B-b)/(b+B)+(C-c)/(c+C)
    local win_rate = 0

    -- 计算装备等级部分: 6*(x-z)/y
    if boss_level > 0 then
        win_rate = win_rate + 6 * (avg_equipment_level - min_required_level) / boss_level
    end

    -- 计算坦克部分: (A-a)/(a+A)
    if tank_count + tank_required > 0 then
        win_rate = win_rate + (tank_count - tank_required) / (tank_count + tank_required)
    end

    -- 计算治疗部分: (B-b)/(b+B)
    if healer_count + healer_required > 0 then
        win_rate = win_rate + (healer_count - healer_required) / (healer_count + healer_required)
    end

    -- 计算输出部分: (C-c)/(c+C)
    if dps_count + dps_required > 0 then
        win_rate = win_rate + (dps_count - dps_required) / (dps_count + dps_required)
    end

    -- 打印日志，当前胜率
    log.info("战斗统计 - 战斗ID:%s, 胜率:%f", args.battle_id, win_rate)

    -- 6. 判断是否胜利 (随机数小于胜率则胜利)
    -- 生成0~1之间的随机数
    math.randomseed(os.time() + os.clock() * 1000)
    local random_value = math.random()
    local is_win = random_value < win_rate

    -- 7. 计算战斗时长 T=K*(1-S)+60
    local battle_duration = math.floor(battle_time_limit * (1 - win_rate) + 60)
    log.info("战斗时长计算 - 战斗ID:%s, 基础时长:%d, 胜率:%f, 计算结果:%d秒",
        args.battle_id, battle_time_limit, win_rate, battle_duration)

    -- 将当前战斗时长添加到战斗时长记录中
    table.insert(battle_duration_phases, battle_duration)

    -- 8. 判断是否可以重试(战斗失败时有50%概率可以重试，且未达到重开次数上限)
    local is_retry = false
    if not is_win then
        is_retry = (math.random() < 0.5) and (current_retry_count < max_retry_count)
        log.info("战斗失败，是否可重试: %s (当前重开次数:%d, 上限:%d)",
            is_retry and "是" or "否", current_retry_count, max_retry_count)
    end

    -- 9. 更新战斗状态
    -- 如果可以重试，则状态为1(进行中)，否则为2(已结束)
    local new_battle_status = is_retry and 1 or 2
    local new_retry_count = current_retry_count
    if is_retry then
        new_retry_count = current_retry_count + 1
    end

    local battle_remarks = is_win and "战斗胜利" or (is_retry and "战斗失败，可重试" or "战斗失败，不可重试")
    
    -- 安全地编码JSON数据
    local battle_duration_phases_json
    local ok, result = pcall(function()
        return json.encode(battle_duration_phases)
    end)
    if ok and result then
        battle_duration_phases_json = result
    else
        log.error("编码战斗时长记录失败: %s", tostring(result))
        battle_duration_phases_json = "[]" -- 使用空数组作为默认值
    end
    
    local update_result, update_err = skynet.call(".dbproxyd", "lua", "query", {
        sql = [[
            UPDATE player_pve_battle
            SET battle_status = ?, is_win = ?, retry_count = ?,
                battle_duration_phases = ?, remarks = ?
            WHERE battle_id = ?
        ]],
        params = {
            new_battle_status,
            is_win and 1 or 0,
            new_retry_count,
            battle_duration_phases_json,
            battle_remarks,
            args.battle_id
        }
    })

    if not update_result then
        log.error("更新战斗状态失败，战斗ID:%s 错误:%s", args.battle_id, update_err)
        return {
            ok = false,
            error = {
                code = "DB_ERROR",
                message = "更新战斗状态失败: " .. (update_err or "未知错误")
            }
        }
    end

    log.info("战斗结果 - 战斗ID:%s, 胜率:%f, 随机值:%f, 是否胜利:%s, 战斗时长:%d秒, 重开次数:%d, 是否可重试:%s",
        args.battle_id, win_rate, random_value, is_win and "是" or "否", battle_duration, current_retry_count,
        is_retry and "是" or "否")

    return {
        ok = true,
        battle_id = args.battle_id,
        is_win = is_win,
        is_retry = is_retry,
        battle_duration = battle_duration,
        retry_count = current_retry_count
    }
end

-- 将处理器注册到sproto_client
local client_handler = sproto_client.handler()
for name, func in pairs(handler) do
    client_handler[name] = func
end

return handler

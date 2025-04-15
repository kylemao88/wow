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

-- 将处理器注册到sproto_client
local client_handler = sproto_client.handler()
for name, func in pairs(handler) do
    client_handler[name] = func
end

return handler

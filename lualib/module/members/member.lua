-- 会员管理处理器
local skynet = require "skynet"
local log = require "log"

local handler = {}

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

return handler

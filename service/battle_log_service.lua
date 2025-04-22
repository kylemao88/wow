local skynet = require "skynet"
local log = require "log"
local battle_log = require "module.battle.battle_log" -- 引入战斗日志模块
require "skynet.manager"
require "skynet.debug"

local command = {}

-- 生成单局PVE战斗日志
-- @param battle_id 战斗ID
-- @param boss_id Boss ID
-- @param member_ids 参战会员ID列表
-- @param is_win 战斗是否胜利
-- @param battle_duration 当局战斗时长
function command.generate_pve_battle_log(_, args)
    log.info("生成PVE战斗日志: battle_id=%s, boss_id=%s, is_win=%s, duration=%s",
        args.battle_id,
        args.boss_id,
        args.is_win and "是" or "否",
        tostring(args.battle_duration))

    -- 参数校验
    if not args.battle_id then
        return {
            ok = false,
            error = {
                code = "MISSING_PARAM",
                message = "缺少战斗ID参数"
            }
        }
    end

    if not args.boss_id then
        return {
            ok = false,
            error = {
                code = "MISSING_PARAM",
                message = "缺少Boss ID参数"
            }
        }
    end

    if not args.member_ids or #args.member_ids == 0 then
        return {
            ok = false,
            error = {
                code = "MISSING_PARAM",
                message = "缺少参战会员ID参数"
            }
        }
    end

    if args.is_win == nil then
        return {
            ok = false,
            error = {
                code = "MISSING_PARAM",
                message = "缺少战斗结果参数"
            }
        }
    end

    if not args.battle_duration or args.battle_duration <= 0 then
        return {
            ok = false,
            error = {
                code = "MISSING_PARAM",
                message = "缺少有效的战斗时长参数"
            }
        }
    end

    -- 调用战斗日志模块生成日志
    local result, err = battle_log.generate_pve_battle_log(
        args.battle_id,
        args.boss_id,
        args.member_ids,
        args.is_win,
        args.battle_duration
    )

    if not result then
        log.error("生成PVE战斗日志失败: %s", err)
        return {
            ok = false,
            error = {
                code = "GENERATE_FAILED",
                message = err
            }
        }
    end

    log.info("生成PVE战斗日志成功: %s", result.message)
    return {
        ok = true,
        message = result.message,
        log_count = result.log_count
    }
end

-- 获取战斗日志
function command.get_battle_logs(_, args)
    log.info("获取战斗日志: battle_id=%s, page=%s, num=%s",
        args.battle_id, args.page or 1, args.num or 10)

    -- 参数校验
    if not args.battle_id then
        return {
            ok = false,
            error = {
                code = "MISSING_PARAM",
                message = "缺少战斗ID参数"
            }
        }
    end

    local page = tonumber(args.page) or 1
    local num = tonumber(args.num) or 10

    -- 调用战斗日志模块获取日志
    local result, err = battle_log.get_battle_logs(
        args.battle_id,
        page,
        num
    )

    if not result then
        log.error("获取战斗日志失败: %s", err)
        return {
            ok = false,
            error = {
                code = "QUERY_FAILED",
                message = err
            }
        }
    end

    log.info("获取战斗日志成功: 总数=%d, 页码=%d, 本页数量=%d",
        result.total, result.page, result.num)

    return {
        ok = true,
        total = result.total,
        page = result.page,
        num = result.num,
        logs = result.logs
    }
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = command[cmd]
        if f then
            skynet.ret(skynet.pack(f(command, ...)))
        else
            log.error("未知命令: %s", cmd)
            skynet.ret(skynet.pack({
                ok = false,
                error = {
                    code = "UNKNOWN_COMMAND",
                    message = "未知命令: " .. cmd
                }
            }))
        end
    end)

    log.info("战斗日志处理服务已启动，地址: %s", skynet.address(skynet.self()))
    skynet.register(".battle_log_service")
end)

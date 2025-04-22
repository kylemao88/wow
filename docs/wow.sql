
CREATE DATABASE `wow` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 阵营表 - 记录基础阵营类别信息
CREATE TABLE faction (
    faction_id VARCHAR(64) COMMENT '阵营ID',
    faction_name VARCHAR(50) NOT NULL COMMENT '阵营名称',
	faction_desc VARCHAR(250) NOT NULL COMMENT '阵营描述',
	PRIMARY KEY (`faction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='阵营信息表';

INSERT INTO faction (faction_id, faction_name, faction_desc) 
VALUES ('faction_001', '联盟', '由人类、矮人、暗夜精灵等种族组成的正义阵营');
INSERT INTO faction (faction_id, faction_name, faction_desc) 
VALUES ('faction_002', '部落', '由兽人、牛头人、巨魔等种族组成的强大阵营');


-- 基础种族表 - 记录基础种族类别信息
CREATE TABLE race (
    race_id VARCHAR(64) COMMENT '种族ID',
    race_name VARCHAR(50) NOT NULL COMMENT '种族名称',
	remarks VARCHAR(250) NOT NULL COMMENT '备注',
	PRIMARY KEY (`race_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='基础种族表';
-- 联盟种族
INSERT INTO race (race_id, race_name, remarks) VALUES ('race_001', '人类', '艾泽拉斯最坚韧的种族，以勇气和适应力著称');
INSERT INTO race (race_id, race_name, remarks) VALUES ('race_002', '矮人', '来自铁炉堡的强壮种族，擅长锻造和采矿');
INSERT INTO race (race_id, race_name, remarks) VALUES ('race_003', '侏儒', '来自诺莫瑞根的聪明种族，以工程学和发明闻名');
INSERT INTO race (race_id, race_name, remarks) VALUES ('race_004', '暗夜精灵', '卡多雷的守护者，与自然和月光有着深厚联系');
INSERT INTO race (race_id, race_name, remarks) VALUES ('race_005', '德莱尼', '来自外域的流亡者，拥有神圣的纳鲁科技');

-- 部落种族
INSERT INTO race (race_id, race_name, remarks) VALUES ('race_006', '兽人', '来自德拉诺的战士种族，崇尚荣誉和力量');
INSERT INTO race (race_id, race_name, remarks) VALUES ('race_007', '巨魔', '暗矛部族的成员，擅长巫毒和投掷武器');
INSERT INTO race (race_id, race_name, remarks) VALUES ('race_008', '亡灵', '被遗忘者，从巫妖王的控制中解脱出来的不死生物');
INSERT INTO race (race_id, race_name, remarks) VALUES ('race_009', '牛头人', '来自莫高雷的高贵种族，崇尚自然和大地母亲');
INSERT INTO race (race_id, race_name, remarks) VALUES ('race_010', '血精灵', '奎尔萨拉斯的幸存者，对魔法有着强烈的渴望');

-- 基础职业表 - 记录基础职业类别信息
CREATE TABLE profession (
    profession_id VARCHAR(64) COMMENT '职业ID',
    profession_name VARCHAR(50) NOT NULL COMMENT '职业名称',
	remarks VARCHAR(250) NOT NULL COMMENT '备注',
	PRIMARY KEY (`profession_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='基础职业表';
INSERT INTO profession (profession_id, profession_name, remarks) 
VALUES ('profession_001', '战士', '精通各种武器的战斗大师，可以担任坦克或伤害输出角色');
INSERT INTO profession (profession_id, profession_name, remarks) 
VALUES ('profession_002', '猎人', '远程武器专家，可以驯服野兽作为宠物协助战斗');
INSERT INTO profession (profession_id, profession_name, remarks) 
VALUES ('profession_003', '萨满', '与元素之灵沟通的施法者，可以治疗、输出或增强队友');
INSERT INTO profession (profession_id, profession_name, remarks) 
VALUES ('profession_004', '骑士', '圣光的守护者，可以担任坦克、治疗或伤害输出角色');
INSERT INTO profession (profession_id, profession_name, remarks) 
VALUES ('profession_005', '术士', '操纵暗影和恶魔之力的施法者，可以召唤恶魔仆从');
INSERT INTO profession (profession_id, profession_name, remarks) 
VALUES ('profession_006', '牧师', '信仰的治疗者，可以专注于神圣治疗或暗影伤害');
INSERT INTO profession (profession_id, profession_name, remarks) 
VALUES ('profession_007', '盗贼', '潜行和暗杀的大师，擅长爆发性伤害和控制');
INSERT INTO profession (profession_id, profession_name, remarks) 
VALUES ('profession_008', '法师', '奥术能量的大师，可以造成强大的范围或单体伤害');
INSERT INTO profession (profession_id, profession_name, remarks) 
VALUES ('profession_009', '德鲁伊', '自然的守护者，可以变形为不同形态应对各种角色');
INSERT INTO profession (profession_id, profession_name, remarks) 
VALUES ('profession_010', '死亡骑士', '使用符文和符能的不死战士，可以担任坦克或伤害输出角色');


-- 创建基础天赋表
CREATE TABLE talent (
    talent_id VARCHAR(64) COMMENT '天赋ID',
    talent_name VARCHAR(50) NOT NULL COMMENT '天赋名称',
    remarks VARCHAR(250) COMMENT '备注',
    PRIMARY KEY (`talent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='基础天赋表';

-- 插入天赋数据
INSERT INTO talent (talent_id, talent_name, remarks) VALUES
('talent_001', '元素', '萨满的元素专精，专注于元素法术伤害'),
('talent_002', '兽王', '猎人的兽王专精，强化宠物战斗能力'),
('talent_003', '冰霜', '法师的冰霜专精，擅长控制和减速'),
('talent_004', '刺杀', '盗贼的刺杀专精，专注于毒药和单体伤害'),
('talent_005', '增强', '萨满的增强专精，强化近战攻击能力'),
('talent_006', '奥术', '法师的奥术专精，使用纯净的奥术能量'),
('talent_007', '射击', '猎人的射击专精，专注于远程武器伤害'),
('talent_008', '平衡', '德鲁伊的平衡专精，使用日月之力'),
('talent_009', '恢复', '德鲁伊/萨满的治疗专精'),
('talent_010', '恶魔', '术士的恶魔专精，强化恶魔仆从'),
('talent_011', '惩戒', '骑士的惩戒专精，使用圣光之力攻击'),
('talent_012', '戒律', '牧师的戒律专精，预防性治疗和护盾'),
('talent_013', '战斗', '盗贼的战斗专精，均衡的伤害输出'),
('talent_014', '敏锐', '盗贼的敏锐专精，擅长潜行和伏击'),
('talent_015', '暗影', '牧师的暗影专精，使用暗影魔法攻击'),
('talent_016', '武器', '战士的武器专精，精通各种武器'),
('talent_017', '毁灭', '术士的毁灭专精，使用火焰和暗影魔法'),
('talent_018', '火焰', '法师的火焰专精，高爆发伤害'),
('talent_019', '狂暴', '战士的狂暴专精，双持武器疯狂攻击'),
('talent_020', '生存', '猎人的生存专精，陷阱和生存技巧'),
('talent_021', '痛苦', '术士的痛苦专精，持续伤害和诅咒'),
('talent_022', '神圣', '牧师/骑士的治疗专精'),
('talent_023', '邪恶', '死亡骑士的邪恶专精，疾病和亡灵仆从'),
('talent_024', '野性', '德鲁伊的野性专精，变身野兽形态'),
('talent_025', '防战', '战士的防护专精，坦克天赋'),
('talent_026', '防骑', '骑士的防护专精，坦克天赋'),
('talent_027', '鲜血', '死亡骑士的鲜血专精，坦克天赋');


-- 基础角色表 - 记录角色类别信息   -- *** 取消 *** 无效 *** -
CREATE TABLE base_character (
    character_id VARCHAR(64) COMMENT '角色ID',
    profession_id VARCHAR(64) NOT NULL COMMENT '职业类型:对应profession.profession_id',
    race_id VARCHAR(64) NOT NULL COMMENT '种族类型:对应race.race_id',
	PRIMARY KEY (`character_id`),
	UNIQUE INDEX uk_prof_race (profession_id,race_id) COMMENT '职业种族联合唯一索引'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色信息表';


-- 玩家会员表 - 记录玩家的会员信息
CREATE TABLE player_member (
    player_id VARCHAR(64) NOT NULL COMMENT '玩家ID',
    member_id VARCHAR(64) NOT NULL COMMENT '会员ID',
    nickname VARCHAR(50) NOT NULL COMMENT '昵称',
    gender TINYINT NOT NULL COMMENT '性别(0-未知,1-男,2-女)',
    profession_id VARCHAR(64) NOT NULL COMMENT '职业类型:对应profession.profession_id',
    race_id VARCHAR(64) NOT NULL COMMENT '种族类型:对应race.race_id',
    talent_id VARCHAR(64) COMMENT '天赋ID:对应talent.talent_id',
    position VARCHAR(50) COMMENT '位置',
    equipment_level INT DEFAULT 0 COMMENT '装等',
	PRIMARY KEY (`player_id`,`member_id`),
	INDEX idx_player_id (player_id) COMMENT '玩家ID索引'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='玩家会员表';

-- 插入玩家会员数据(所有玩家ID均为player_101)
INSERT INTO player_member (player_id, member_id, nickname, gender, profession_id, race_id, talent_id, position, equipment_level) VALUES
('player_101', 'member_001', '俺不冲锋', 1, 'profession_001', 'race_009', 'talent_025', 'T', 65),
('player_101', 'member_002', '江水又为竭', 1, 'profession_004', 'race_010', 'talent_026', 'T', 60),
('player_101', 'member_003', '好运星', 2, 'profession_006', 'race_008', 'talent_012', 'N', 65),
('player_101', 'member_004', '未来星', 2, 'profession_004', 'race_010', 'talent_022', 'N', 62),
('player_101', 'member_005', '秒杀feelゼ', 2, 'profession_003', 'race_007', 'talent_009', 'N', 57),
('player_101', 'member_006', '年少殊途', 2, 'profession_009', 'race_009', 'talent_009', 'N', 60),
('player_101', 'member_007', '斧虐英豪', 1, 'profession_007', 'race_008', 'talent_013', 'dps', 52),
('player_101', 'member_008', '点也卟坚强丶', 2, 'profession_007', 'race_010', 'talent_014', 'dps', 55),
('player_101', 'member_009', '寒塘冷月', 1, 'profession_007', 'race_006', 'talent_004', 'dps', 56),
('player_101', 'member_010', '゛厌丗沉淪ゝ', 1, 'profession_001', 'race_006', 'talent_019', 'dps', 58),
('player_101', 'member_011', '来个橙子', 1, 'profession_004', 'race_010', 'talent_011', 'dps', 57),
('player_101', 'member_012', '邪不肉', 1, 'profession_010', 'race_009', 'talent_023', 'dps', 61),
('player_101', 'member_013', '你爹突然间', 1, 'profession_008', 'race_008', 'talent_018', 'dps', 63),
('player_101', 'member_014', '悲魂曲', 1, 'profession_008', 'race_007', 'talent_003', 'dps', 59),
('player_101', 'member_015', '无妄之森', 2, 'profession_008', 'race_010', 'talent_003', 'dps', 60),
('player_101', 'member_016', '與鬼共粲', 1, 'profession_008', 'race_010', 'talent_006', 'dps', 55),
('player_101', 'member_017', '大郎吃糖了', 2, 'profession_005', 'race_008', 'talent_021', 'dps', 59),
('player_101', 'member_018', '树屿牧歌', 2, 'profession_005', 'race_010', 'talent_010', 'dps', 52),
('player_101', 'member_019', '雪落纷纷', 1, 'profession_002', 'race_007', 'talent_007', 'dps', 58),
('player_101', 'member_020', '弑神eastwest', 2, 'profession_002', 'race_007', 'talent_007', 'dps', 56),
('player_101', 'member_021', '红色娘子军^', 1, 'profession_002', 'race_006', 'talent_002', 'dps', 55),
('player_101', 'member_022', '爱你不是以往', 2, 'profession_002', 'race_010', 'talent_020', 'dps', 56),
('player_101', 'member_023', 'JYP', 1, 'profession_003', 'race_006', 'talent_001', 'dps', 58),
('player_101', 'member_024', 'Haerin', 2, 'profession_006', 'race_010', 'talent_015', 'dps', 64),
('player_101', 'member_025', '相位星', 1, 'profession_009', 'race_009', 'talent_008', 'dps', 60);


-- 关卡副本表 - 记录副本关卡信息
CREATE TABLE dungeon (
    dungeon_id VARCHAR(64) COMMENT '副本ID',
    dungeon_name VARCHAR(100) NOT NULL COMMENT '副本名称',
    stage_index INT NOT NULL COMMENT '关卡序号',
    stage_name VARCHAR(100) NOT NULL COMMENT '关卡名称',
    stage_attributes TEXT COMMENT '关卡属性(JSON格式存储)',
	PRIMARY KEY (`dungeon_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='关卡副本信息表';


-- 基础Boss信息表
CREATE TABLE boss (
    boss_id VARCHAR(64) NOT NULL COMMENT 'Boss唯一标识ID',
    boss_name VARCHAR(100) NOT NULL COMMENT 'Boss名称',
    boss_level INT NOT NULL COMMENT 'Boss等级',
    min_required_level INT NOT NULL COMMENT '要求玩家最低等级',
    tank_required INT DEFAULT 2 COMMENT '队伍需要的坦克数量',
    healer_required INT DEFAULT 4 COMMENT '队伍需要的治疗数量',
    dps_required INT DEFAULT 15 COMMENT '队伍需要的输出数量',
    battle_time_limit INT DEFAULT 60 COMMENT 'Boss战斗时长设定',
    max_retry_count INT DEFAULT 3 COMMENT 'Boss战斗重开次数上限',
    remarks VARCHAR(500) COMMENT '备注信息',
    PRIMARY KEY (`boss_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='副本Boss基础信息表';

-- 插入拉格纳罗斯Boss数据
INSERT INTO boss (boss_id, boss_name, boss_level, min_required_level, tank_required, healer_required, dps_required, battle_time_limit, remarks) 
VALUES ('boss_001', '拉格纳罗斯', 65, 55, 2, 4, 15, 300, '熔火之心的最终Boss，火焰之王，拥有强大的火焰攻击能力');


-- 玩家副本战斗log表 
CREATE TABLE player_dungeon (
    player_id VARCHAR(64) NOT NULL COMMENT '玩家ID',
    dungeon_id VARCHAR(64) NOT NULL COMMENT '副本ID',
    log_index INT NOT NULL COMMENT '日志序号',
    log_desc VARCHAR(250) NOT NULL COMMENT '日志描述',
    remarks VARCHAR(250) NOT NULL COMMENT '备注',
    INDEX idx_dungeon_id (dungeon_id) COMMENT '副本ID索引',
    INDEX idx_player_id (player_id) COMMENT '玩家ID索引'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='玩家副本战斗log表';


-- PVE战斗备战表 - 记录玩家与Boss的战斗信息
CREATE TABLE player_pve_battle (
    battle_id VARCHAR(64) NOT NULL COMMENT '战斗唯一标识ID',
    player_id VARCHAR(64) NOT NULL COMMENT '玩家ID',
    boss_id VARCHAR(64) NOT NULL COMMENT 'Boss ID',
    battle_start_time DATETIME NOT NULL COMMENT '战斗时间',
    battle_members TEXT COMMENT '参战会员ID列表，JSON格式存储',
    battle_status TINYINT DEFAULT 0 COMMENT '战斗状态(0-未开始,1-进行中,2-已结束)',
    is_win TINYINT DEFAULT 0 COMMENT '是否获胜(0-失败,1-胜利)',
    retry_count INT DEFAULT 0 COMMENT '已重开次数',
    battle_duration_phases TEXT COMMENT '战斗时长配置(多阶段JSON格式存储)',
    remarks VARCHAR(500) COMMENT '备注信息',
    PRIMARY KEY (battle_id),
    INDEX idx_player_id (player_id) COMMENT '玩家ID索引',
    INDEX idx_boss_id (boss_id) COMMENT 'Boss ID索引',
    INDEX idx_battle_time (battle_start_time) COMMENT '战斗时间索引'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='PVE战斗备战表';

-- 插入示例数据
INSERT INTO player_pve_battle (battle_id, player_id, boss_id, battle_start_time, battle_members, is_win, battle_duration_phases, remarks)
VALUES (
    'battle_001', 
    'player_101', 
    'boss_001', 
    '2025-04-01 20:30:00', 
    '["member_001", "member_002", "member_005", "member_006", "member_009", "member_010", "member_011", "member_015", "member_016", "member_017", "member_018", "member_019", "member_020", "member_021"]', 
    1, 
    '[1810, 235, 588]', 
    '首次挑战拉格纳罗斯成功'
);


-- 战斗日志表 - 记录PVE战斗的详细日志信息
CREATE TABLE pve_battle_log (
    log_id BIGINT AUTO_INCREMENT COMMENT '日志ID，自增主键',
    battle_id VARCHAR(64) NOT NULL COMMENT '战斗ID，关联player_pve_battle表',
    battle_timestamp VARCHAR(20) NOT NULL COMMENT '时间戳，格式如00:00:00或00:01:26',
    character_name VARCHAR(100) NULL COMMENT '人物名称，可能是boss名称或玩家会员名称或空',
    log_text TEXT NOT NULL COMMENT '战斗日志话术',
    remarks VARCHAR(500) DEFAULT NULL COMMENT '备注信息',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (log_id),
    INDEX idx_battle_id (battle_id) COMMENT '战斗ID索引，用于快速查询特定战斗的日志',
    INDEX idx_timestamp (battle_timestamp) COMMENT '时间戳索引，用于按时间顺序查询'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='PVE战斗日志表';

-- 插入示例数据
INSERT INTO pve_battle_log (battle_id, battle_timestamp, character_name, log_text, remarks) VALUES
('battle_001', '00:00:00', '团长', '开始挑战拉格纳罗斯，全体注意！', '战斗开始提示'),
('battle_001', '00:00:15', '拉格纳罗斯', '你们这些虫子竟敢挑战炎魔之王！', 'Boss台词'),
('battle_001', '00:01:26', '俺不冲锋', '嘲讽成功，注意治疗！', '坦克提示'),
('battle_001', '00:02:45', '好运星', '治疗已到位，坦克血量稳定', '治疗反馈'),
('battle_001', '00:03:30', '团长', '火焰之子即将出现，远程注意！', '战术提示'),
('battle_001', '00:04:15', '点也卟坚强丶', '引到小怪了..扣他DKP！', '战斗意外'),
('battle_001', '00:05:40', '拉格纳罗斯', '感受炎魔之王的愤怒吧！', 'Boss技能释放'),
('battle_001', '00:06:20', '团长', '所有人注意躲避火焰冲击！', '战术指挥'),
('battle_001', '00:08:10', '你爹突然间', '法力值不足，需要回蓝！', 'DPS状态'),
('battle_001', '00:10:00', '团长', 'Boss血量50%，第二阶段开始！', '阶段转换');


-- 日志阶段表 - 记录战斗日志的不同阶段和过程
CREATE TABLE `battle_log_stage` (
  `stage_id` varchar(64) NOT NULL COMMENT '阶段ID，如stage-1、stage-2',
  `stage_name` varchar(100) NOT NULL COMMENT '阶段名称，如boss战准备、boss战斗、boss战斗结束判定',
  `process_id` varchar(64) NOT NULL COMMENT '过程ID',
  `process_type` varchar(100) NOT NULL COMMENT '过程类型，0:无人物话术；1:boss话术； 2:会员通用话术； 3:会员专属话术',
  `process_name` varchar(100) NOT NULL COMMENT '过程名称，如boss战斗过程通用话术、boss台词、boss战斗专属',
  `script_lib_id` varchar(64) NOT NULL COMMENT '对应话术库ID',
  `script_count` int DEFAULT '0' COMMENT '话术数量',
  `remarks` varchar(500) DEFAULT NULL COMMENT '备注信息',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`stage_id`,`process_id`),
  KEY `idx_stage_id` (`stage_id`) COMMENT '阶段ID索引',
  KEY `idx_script_lib_id` (`script_lib_id`) COMMENT '话术库ID索引'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='战斗日志阶段表'

-- 日志话术表 - 存储各种战斗场景的话术内容
CREATE TABLE battle_log_script (
    script_id BIGINT AUTO_INCREMENT COMMENT '话术ID，自增主键',
    script_lib_id VARCHAR(64) NOT NULL COMMENT '话术库ID，关联battle_log_stage表',
    character_id VARCHAR(100) DEFAULT NULL COMMENT '话术人物ID，可为空或为boos_id或member_id',
    character_name VARCHAR(100) DEFAULT NULL COMMENT '话术人物名称，可为空表示通用话术',
    profession_id VARCHAR(64) DEFAULT NULL COMMENT '话术人物职业ID，可为空表示不限职业',
    log_text TEXT NOT NULL COMMENT '话术日志内容',
    remarks VARCHAR(500) DEFAULT NULL COMMENT '备注信息',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (script_id),
    INDEX idx_script_lib_id (script_lib_id) COMMENT '话术库ID索引',
    INDEX idx_profession_id (profession_id) COMMENT '职业ID索引'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='战斗日志话术表';

-- 插入日志阶段示例数据
INSERT INTO battle_log_stage (stage_id, stage_name, process_id, process_type,process_name, script_lib_id, script_count, remarks) VALUES
('stage-1', 'Boss战准备', 'process-1-1', '团队集结', 0, 'script-lib-101', 5, '战斗前团队集结阶段的话术'),
('stage-1', 'Boss战准备', 'process-1-2', '战术讲解', 0, 'script-lib-102', 8, '战斗前战术讲解阶段的话术'),
('stage-1', 'Boss战准备', 'process-1-3', '就位确认', 0, 'script-lib-103', 4, '战斗前就位确认阶段的话术'),
('stage-2', 'Boss战斗', 'process-2-1', 'Boss台词', 1, 'script-lib-201', 10, 'Boss在战斗中的台词'),
('stage-2', 'Boss战斗', 'process-2-2', '坦克话术', 2, 'script-lib-202', 12, '坦克在战斗中的话术'),
('stage-2', 'Boss战斗', 'process-2-3', '治疗话术', 2, 'script-lib-203', 15, '治疗在战斗中的话术'),
('stage-2', 'Boss战斗', 'process-2-4', 'DPS话术', 2, 'script-lib-204', 20, 'DPS在战斗中的话术'),
('stage-2', 'Boss战斗', 'process-2-5', '团长指挥', 2,'script-lib-205', 18, '团长在战斗中的指挥话术'),
('stage-2', 'Boss战斗', 'process-2-6', '战斗意外', 0, 'script-lib-206', 8, '战斗中意外情况的话术'),
('stage-3', 'Boss战斗结束判定', 'process-3-1', 0, '战斗胜利', 'script-lib-301', 10, '战斗胜利时的话术'),
('stage-3', 'Boss战斗结束判定', 'process-3-2', 0, '战斗失败', 'script-lib-302', 8, '战斗失败时的话术'),
('stage-3', 'Boss战斗结束判定', 'process-3-3', 0, '战利品分配', 'script-lib-303', 6, '战利品分配时的话术');

-- 插入日志话术示例数据
INSERT INTO battle_log_script (script_lib_id, character_name, profession_id, log_text, remarks) VALUES
-- 战斗准备阶段 - 团队集结
('script-lib-101', '团长', NULL, '全体集合，准备挑战拉格纳罗斯！', '团队集结通用话术'),
('script-lib-101', '团长', NULL, '检查装备和消耗品，确保全部到位！', '团队集结通用话术'),
('script-lib-101', '团长', NULL, '今天我们将挑战炎魔之王，请大家做好准备！', '团队集结通用话术'),
('script-lib-101', NULL, NULL, '团队成员陆续到达集合点，准备开始挑战。', '团队集结通用话术'),
('script-lib-101', NULL, NULL, '公会成员们摩拳擦掌，准备迎接新的挑战。', '团队集结通用话术'),

-- 战斗准备阶段 - 战术讲解
('script-lib-102', '团长', NULL, '拉格纳罗斯有三个阶段，每个阶段的战术要点如下...', '战术讲解通用话术'),
('script-lib-102', '团长', NULL, '坦克注意仇恨，治疗注意驱散，DPS注意站位！', '战术讲解通用话术'),
('script-lib-102', '团长', NULL, '当Boss释放火焰冲击时，所有人必须立即散开！', '战术讲解通用话术'),
('script-lib-102', '团长', NULL, '第二阶段会刷新火焰元素，优先击杀它们！', '战术讲解通用话术'),
('script-lib-102', '团长', NULL, '最后阶段Boss会狂暴，治疗要全力输出！', '战术讲解通用话术'),
('script-lib-102', NULL, NULL, '团队成员认真听取战术安排，做好心理准备。', '战术讲解通用话术'),
('script-lib-102', NULL, NULL, '老队员向新人解释战斗机制的细节。', '战术讲解通用话术'),
('script-lib-102', NULL, NULL, '队员们在地图上标记关键位置，确保战术执行准确。', '战术讲解通用话术'),

-- 战斗准备阶段 - 就位确认
('script-lib-103', '团长', NULL, '所有人就位，准备开始！', '就位确认通用话术'),
('script-lib-103', '团长', NULL, '倒数5秒，5、4、3、2、1，开始！', '就位确认通用话术'),
('script-lib-103', NULL, NULL, '团队成员纷纷就位，准备迎接挑战。', '就位确认通用话术'),
('script-lib-103', NULL, NULL, '坦克深吸一口气，冲向Boss所在位置。', '就位确认通用话术'),

-- Boss战斗阶段 - Boss台词
('script-lib-201', '拉格纳罗斯', NULL, '你们这些虫子竟敢挑战炎魔之王！', 'Boss台词'),
('script-lib-201', '拉格纳罗斯', NULL, '感受炎魔之王的愤怒吧！', 'Boss台词'),
('script-lib-201', '拉格纳罗斯', NULL, '我的火焰将焚烧一切！', 'Boss台词'),
('script-lib-201', '拉格纳罗斯', NULL, '太早了！你们太早挑战我了！', 'Boss台词'),
('script-lib-201', '拉格纳罗斯', NULL, '我的仆从会将你们撕成碎片！', 'Boss台词'),
('script-lib-201', '拉格纳罗斯', NULL, '火焰之子，听从我的召唤！', 'Boss台词'),
('script-lib-201', '拉格纳罗斯', NULL, '灰烬中的重生，死亡中的新生！', 'Boss台词'),
('script-lib-201', '拉格纳罗斯', NULL, '你们将在烈焰中灰飞烟灭！', 'Boss台词'),
('script-lib-201', '拉格纳罗斯', NULL, '燃烧吧，凡人们！', 'Boss台词'),
('script-lib-201', '拉格纳罗斯', NULL, '这是我的领域，你们将在此化为灰烬！', 'Boss台词'),

-- Boss战斗阶段 - 坦克话术
('script-lib-202', NULL, 'profession_001', '嘲讽成功，注意治疗！', '战士坦克通用话术'),
('script-lib-202', NULL, 'profession_001', '盾墙已开，加大治疗！', '战士坦克通用话术'),
('script-lib-202', NULL, 'profession_001', '仇恨稳定，DPS可以全力输出！', '战士坦克通用话术'),
('script-lib-202', NULL, 'profession_004', '圣盾术已开，10秒无敌时间！', '骑士坦克通用话术'),
('script-lib-202', NULL, 'profession_004', '正义之怒嘲讽成功，注意治疗！', '骑士坦克通用话术'),
('script-lib-202', NULL, 'profession_004', '神圣护盾已开，加大治疗！', '骑士坦克通用话术'),
('script-lib-202', '俺不冲锋', 'profession_001', '盾墙已开，加大治疗！', '特定角色话术'),
('script-lib-202', '俺不冲锋', 'profession_001', '仇恨稳定，DPS可以全力输出！', '特定角色话术'),
('script-lib-202', '江水又为竭', 'profession_004', '圣盾术已开，10秒无敌时间！', '特定角色话术'),
('script-lib-202', '江水又为竭', 'profession_004', '正义之怒嘲讽成功，注意治疗！', '特定角色话术'),
('script-lib-202', NULL, NULL, '坦克稳住Boss，为团队创造输出空间。', '坦克通用话术'),
('script-lib-202', NULL, NULL, '坦克灵活走位，避开Boss的正面攻击。', '坦克通用话术'),

-- Boss战斗阶段 - 治疗话术
('script-lib-203', NULL, 'profession_006', '治疗已到位，坦克血量稳定', '牧师治疗通用话术'),
('script-lib-203', NULL, 'profession_006', '团队治疗已施放，注意避开伤害！', '牧师治疗通用话术'),
('script-lib-203', NULL, 'profession_006', '真言术：盾已加持坦克，请继续前进！', '牧师治疗通用话术'),
('script-lib-203', NULL, 'profession_004', '圣光术已施放，坦克血量回满！', '骑士治疗通用话术'),
('script-lib-203', NULL, 'profession_004', '圣疗术冷却完毕，准备应对大量伤害！', '骑士治疗通用话术'),
('script-lib-203', NULL, 'profession_003', '治疗链已施放，团队血量回升中！', '萨满治疗通用话术'),
('script-lib-203', NULL, 'profession_003', '治疗之潮图腾已放置，站在附近可获得持续治疗！', '萨满治疗通用话术'),
('script-lib-203', NULL, 'profession_009', '回春术已加持坦克，持续治疗中！', '德鲁伊治疗通用话术'),
('script-lib-203', NULL, 'profession_009', '生命绽放已施放，注意站位获得治疗！', '德鲁伊治疗通用话术'),
('script-lib-203', '好运星', 'profession_006', '团队治疗已施放，注意避开伤害！', '特定角色话术'),
('script-lib-203', '未来星', 'profession_004', '圣光术已施放，坦克血量回满！', '特定角色话术'),
('script-lib-203', '秒杀feelゼ', 'profession_003', '治疗链已施放，团队血量回升中！', '特定角色话术'),
('script-lib-203', '年少殊途', 'profession_009', '回春术已加持坦克，持续治疗中！', '特定角色话术'),
('script-lib-203', NULL, NULL, '治疗密切关注团队血量，随时准备应对突发情况。', '治疗通用话术'),
('script-lib-203', NULL, NULL, '治疗法力值告急，需要回蓝！', '治疗通用话术'),

-- Boss战斗阶段 - DPS话术
('script-lib-204', NULL, 'profession_008', '火焰冲击！伤害爆表！', '法师DPS通用话术'),
('script-lib-204', NULL, 'profession_008', '奥术飞弹已就绪，全力输出！', '法师DPS通用话术'),
('script-lib-204', NULL, 'profession_008', '需要回蓝，暂停输出！', '法师DPS通用话术'),
('script-lib-204', NULL, 'profession_007', '背刺连击，爆发伤害！', '盗贼DPS通用话术'),
('script-lib-204', NULL, 'profession_007', '消失准备就绪，准备重置仇恨！', '盗贼DPS通用话术'),
('script-lib-204', NULL, 'profession_002', '瞄准射击，爆头！', '猎人DPS通用话术'),
('script-lib-204', NULL, 'profession_002', '宠物嘲讽已开，帮助坦克分担伤害！', '猎人DPS通用话术'),
('script-lib-204', NULL, 'profession_005', '暗影箭雨已释放，范围伤害爆表！', '术士DPS通用话术'),
('script-lib-204', NULL, 'profession_005', '恶魔仆从已召唤，增加输出！', '术士DPS通用话术'),
('script-lib-204', NULL, 'profession_010', '死亡缠绕已施放，Boss减速！', '死亡骑士DPS通用话术'),
('script-lib-204', NULL, 'profession_010', '符文武器已激活，伤害提升！', '死亡骑士DPS通用话术'),
('script-lib-204', '你爹突然间', 'profession_008', '法力值不足，需要回蓝！', '特定角色话术'),
('script-lib-204', '悲魂曲', 'profession_008', '火焰冲击！伤害爆表！', '特定角色话术'),
('script-lib-204', '无妄之森', 'profession_008', '奥术飞弹已就绪，全力输出！', '特定角色话术'),
('script-lib-204', '點也卟坚强丶', 'profession_007', '背刺连击，爆发伤害！', '特定角色话术'),
('script-lib-204', '寒塘冷月', 'profession_007', '消失准备就绪，准备重置仇恨！', '特定角色话术'),
('script-lib-204', NULL, NULL, 'DPS全力输出，Boss血量迅速下降！', 'DPS通用话术'),
('script-lib-204', NULL, NULL, 'DPS注意控制仇恨，不要超过坦克！', 'DPS通用话术'),
('script-lib-204', NULL, NULL, 'DPS注意躲避地面火焰，边移动边输出！', 'DPS通用话术'),
('script-lib-204', NULL, NULL, 'DPS集火攻击新出现的小怪！', 'DPS通用话术'),

-- Boss战斗阶段 - 团长指挥
('script-lib-205', '团长', NULL, '所有人注意躲避火焰冲击！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '火焰之子即将出现，远程注意！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, 'Boss血量50%，第二阶段开始！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '治疗注意节省法力，战斗还很长！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '坦克注意换防，治疗跟上！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, 'DPS集火小怪，优先击杀！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '全体注意，Boss即将释放大招！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '血量低于20%，全力输出，冲刺阶段！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '治疗注意驱散减益效果！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '坦克准备嘲讽，3秒后换防！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '全体注意，保持站位，不要踩火！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '远程DPS向后撤退，避开火焰区域！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '近战DPS注意Boss前方锥形攻击！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '所有人准备，Boss即将狂暴！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '治疗注意，坦克即将承受大量伤害！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '全体注意，准备转火新目标！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, 'Boss即将施放火焰新星，全体散开！', '团长指挥通用话术'),
('script-lib-205', '团长', NULL, '最后冲刺，全力输出，胜利在望！', '团长指挥通用话术'),

-- Boss战斗阶段 - 战斗意外
('script-lib-206', '点也卟坚强丶', NULL, '引到小怪了..扣他DKP！', '战斗意外通用话术'),
('script-lib-206', NULL, NULL, '有人站位不当，引发了连锁反应！', '战斗意外通用话术'),
('script-lib-206', NULL, NULL, '治疗被沉默，无法施法！', '战斗意外通用话术'),
('script-lib-206', NULL, NULL, '坦克突然倒地，副坦赶紧接手！', '战斗意外通用话术'),
('script-lib-206', NULL, NULL, '有DPS仇恨过高，被Boss秒杀！', '战斗意外通用话术'),
('script-lib-206', NULL, NULL, '团队站位混乱，多人受到AOE伤害！', '战斗意外通用话术'),
('script-lib-206', NULL, NULL, '有人误触了机关，触发了额外的小怪！', '战斗意外通用话术'),
('script-lib-206', NULL, NULL, '网络延迟导致关键技能没有及时释放！', '战斗意外通用话术'),

-- Boss战斗结束判定 - 战斗胜利
('script-lib-301', '团长', NULL, '干得漂亮！拉格纳罗斯已被击败！', '战斗胜利通用话术'),
('script-lib-301', '团长', NULL, '恭喜大家，任务完成！', '战斗胜利通用话术'),
('script-lib-301', '团长', NULL, '这是我们团队的又一次胜利！', '战斗胜利通用话术'),
('script-lib-301', '拉格纳罗斯', NULL, '不可能...我是...炎魔之王...', '战斗胜利Boss台词'),
('script-lib-301', NULL, NULL, '拉格纳罗斯倒下了，熔火之心的威胁已经解除！', '战斗胜利通用话术'),
('script-lib-301', NULL, NULL, '团队成员欢呼雀跃，庆祝这来之不易的胜利！', '战斗胜利通用话术'),
('script-lib-301', NULL, NULL, '炎魔之王的火焰渐渐熄灭，只留下一堆珍贵的战利品。', '战斗胜利通用话术'),
('script-lib-301', NULL, NULL, '这次胜利将被记入公会的荣誉册！', '战斗胜利通用话术'),
('script-lib-301', NULL, NULL, '团队成员互相击掌庆祝，为这次完美的配合感到自豪。', '战斗胜利通用话术'),
('script-lib-301', NULL, NULL, '拉格纳罗斯的火焰熄灭了，但它的传说将永远流传。', '战斗胜利通用话术'),

-- Boss战斗结束判定 - 战斗失败
('script-lib-302', '团长', NULL, '团灭了，准备重新来过！', '战斗失败通用话术'),
('script-lib-302', '团长', NULL, '分析一下失败原因，我们再来一次！', '战斗失败通用话术'),
('script-lib-302', '团长', NULL, '不要灰心，调整策略再试一次！', '战斗失败通用话术'),
('script-lib-302', '拉格纳罗斯', NULL, '凡人们，你们的挑战已经结束！', '战斗失败Boss台词'),
('script-lib-302', NULL, NULL, '团队被Boss的强大力量击溃，只能重整旗鼓再来。', '战斗失败通用话术'),
('script-lib-302', NULL, NULL, '这次失败让团队明白了挑战的艰难，但没有人打算放弃。', '战斗失败通用话术'),
('script-lib-302', NULL, NULL, '拉格纳罗斯的火焰吞噬了整个团队，但他们的意志没有被摧毁。', '战斗失败通用话术'),
('script-lib-302', NULL, NULL, '团队成员从灵魂医者处复活，准备再次挑战。', '战斗失败通用话术'),

-- Boss战斗结束判定 - 战利品分配
('script-lib-303', '团长', NULL, '战利品分配开始，请按需求roll点！', '战利品分配通用话术'),
('script-lib-303', '团长', NULL, '史诗装备优先主天赋，然后是副天赋！', '战利品分配通用话术'),
('script-lib-303', '团长', NULL, '恭喜获得装备的成员，这是团队努力的成果！', '战利品分配通用话术'),
('script-lib-303', NULL, NULL, '团队成员围绕着战利品，等待分配的结果。', '战利品分配通用话术'),
('script-lib-303', NULL, NULL, '珍贵的装备被公平地分配给了团队成员。', '战利品分配通用话术'),
('script-lib-303', NULL, NULL, '拉格纳罗斯掉落的传说装备引起了所有人的关注。', '战利品分配通用话术');

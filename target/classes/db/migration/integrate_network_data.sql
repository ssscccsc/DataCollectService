-- 数据整合脚本：将逻辑组网和网络类型数据整合到统一网络管理表

-- 1. 确保统一网络管理表存在
CREATE TABLE IF NOT EXISTS `unified_network` (
    `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `name` varchar(100) NOT NULL COMMENT '网络名称',
    `description` text COMMENT '描述',
    `network_type` varchar(20) NOT NULL COMMENT '网络类型：LOGIC-逻辑组网，TYPE-网络类型',
    `network_scenario` varchar(50) DEFAULT 'NORMAL' COMMENT '网络场景：NORMAL-正常网络，WEAK-弱网，CONGESTION-拥塞，WEAK_CONGESTION-弱网+拥塞，CUSTOM-自定义',
    `custom_scenario` varchar(200) COMMENT '自定义场景描述',
    `bandwidth` decimal(10,2) COMMENT '网络参数-带宽(Mbps)',
    `latency` decimal(10,2) COMMENT '网络参数-延迟(ms)',
    `packet_loss` decimal(5,2) COMMENT '网络参数-丢包率(%)',
    `jitter` decimal(10,2) COMMENT '网络参数-抖动(ms)',
    `status` tinyint(1) NOT NULL DEFAULT 1 COMMENT '状态：0-禁用，1-启用',
    `create_by` varchar(50) COMMENT '创建人',
    `update_by` varchar(50) COMMENT '更新人',
    `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '逻辑删除：0-未删除，1-已删除',
    PRIMARY KEY (`id`),
    KEY `idx_network_type` (`network_type`),
    KEY `idx_network_scenario` (`network_scenario`),
    KEY `idx_status` (`status`),
    KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='统一网络管理表';

-- 2. 清空现有统一网络数据（如果存在）
DELETE FROM `unified_network`;

-- 3. 迁移现有逻辑组网数据
INSERT INTO `unified_network` (
    `name`, 
    `description`, 
    `network_type`, 
    `network_scenario`, 
    `status`, 
    `create_time`, 
    `update_time`, 
    `deleted`
)
SELECT 
    `name`,
    `description`,
    'LOGIC' as `network_type`,
    'NORMAL' as `network_scenario`,
    1 as `status`,
    `create_time`,
    `update_time`,
    `deleted`
FROM `logic_network`
WHERE `deleted` = 0;

-- 4. 迁移现有网络类型数据
INSERT INTO `unified_network` (
    `name`, 
    `description`, 
    `network_type`, 
    `network_scenario`, 
    `status`, 
    `create_time`, 
    `update_time`, 
    `deleted`
)
SELECT 
    `name`,
    `description`,
    'TYPE' as `network_type`,
    CASE 
        WHEN `name` LIKE '%弱网%' AND `name` LIKE '%拥塞%' THEN 'WEAK_CONGESTION'
        WHEN `name` LIKE '%弱网%' THEN 'WEAK'
        WHEN `name` LIKE '%拥塞%' THEN 'CONGESTION'
        ELSE 'NORMAL'
    END as `network_scenario`,
    `status`,
    `create_time`,
    `update_time`,
    `deleted`
FROM `network_type`
WHERE `deleted` = 0;

-- 5. 更新逻辑环境组网关联表，使用新的统一网络ID
-- 首先备份现有关联关系
CREATE TABLE IF NOT EXISTS `logic_environment_network_backup` AS 
SELECT * FROM `logic_environment_network`;

-- 更新关联表，将逻辑组网ID映射到统一网络ID
UPDATE `logic_environment_network` len
JOIN `logic_network` ln ON len.logic_network_id = ln.id
JOIN `unified_network` un ON un.name = ln.name AND un.network_type = 'LOGIC'
SET len.logic_network_id = un.id
WHERE len.deleted = 0 AND ln.deleted = 0 AND un.deleted = 0;

-- 6. 创建统一网络关联表（用于逻辑环境）
CREATE TABLE IF NOT EXISTS `logic_environment_unified_network` (
    `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `logic_environment_id` bigint(20) NOT NULL COMMENT '逻辑环境ID',
    `unified_network_id` bigint(20) NOT NULL COMMENT '统一网络ID',
    `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted` tinyint(4) DEFAULT '0' COMMENT '逻辑删除：0-未删除，1-已删除',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_logic_environment_unified_network` (`logic_environment_id`, `unified_network_id`),
    KEY `idx_logic_environment_id` (`logic_environment_id`),
    KEY `idx_unified_network_id` (`unified_network_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='逻辑环境统一网络关联表';

-- 7. 迁移逻辑环境组网关联数据到新的关联表
INSERT INTO `logic_environment_unified_network` (
    `logic_environment_id`,
    `unified_network_id`,
    `create_time`,
    `update_time`,
    `deleted`
)
SELECT 
    len.logic_environment_id,
    len.logic_network_id as unified_network_id,
    len.create_time,
    len.update_time,
    len.deleted
FROM `logic_environment_network` len
WHERE len.deleted = 0;

-- 8. 插入一些示例网络参数数据
UPDATE `unified_network` 
SET 
    `bandwidth` = CASE 
        WHEN `name` LIKE '%4G%' THEN 100.00
        WHEN `name` LIKE '%5G%' THEN 1000.00
        WHEN `name` LIKE '%WiFi%' THEN 300.00
        ELSE 50.00
    END,
    `latency` = CASE 
        WHEN `name` LIKE '%弱网%' THEN 200.00
        WHEN `name` LIKE '%拥塞%' THEN 150.00
        WHEN `name` LIKE '%5G%' THEN 5.00
        ELSE 50.00
    END,
    `packet_loss` = CASE 
        WHEN `name` LIKE '%弱网%' THEN 5.00
        WHEN `name` LIKE '%拥塞%' THEN 3.00
        ELSE 0.10
    END,
    `jitter` = CASE 
        WHEN `name` LIKE '%弱网%' THEN 50.00
        WHEN `name` LIKE '%拥塞%' THEN 30.00
        ELSE 5.00
    END
WHERE `network_type` = 'LOGIC';

-- 9. 为网络类型设置参数
UPDATE `unified_network` 
SET 
    `bandwidth` = CASE 
        WHEN `network_scenario` = 'WEAK' THEN 10.00
        WHEN `network_scenario` = 'CONGESTION' THEN 5.00
        WHEN `network_scenario` = 'WEAK_CONGESTION' THEN 2.00
        ELSE 100.00
    END,
    `latency` = CASE 
        WHEN `network_scenario` = 'WEAK' THEN 500.00
        WHEN `network_scenario` = 'CONGESTION' THEN 300.00
        WHEN `network_scenario` = 'WEAK_CONGESTION' THEN 800.00
        ELSE 50.00
    END,
    `packet_loss` = CASE 
        WHEN `network_scenario` = 'WEAK' THEN 10.00
        WHEN `network_scenario` = 'CONGESTION' THEN 15.00
        WHEN `network_scenario` = 'WEAK_CONGESTION' THEN 25.00
        ELSE 0.10
    END,
    `jitter` = CASE 
        WHEN `network_scenario` = 'WEAK' THEN 100.00
        WHEN `network_scenario` = 'CONGESTION' THEN 80.00
        WHEN `network_scenario` = 'WEAK_CONGESTION' THEN 150.00
        ELSE 5.00
    END
WHERE `network_type` = 'TYPE';

-- 10. 显示迁移结果统计
SELECT 
    '迁移完成' as status,
    COUNT(*) as total_networks,
    SUM(CASE WHEN network_type = 'LOGIC' THEN 1 ELSE 0 END) as logic_networks,
    SUM(CASE WHEN network_type = 'TYPE' THEN 1 ELSE 0 END) as network_types
FROM `unified_network`;

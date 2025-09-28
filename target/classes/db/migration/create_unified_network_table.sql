-- 创建统一网络管理表
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

-- 迁移现有逻辑组网数据
INSERT INTO `unified_network` (`name`, `description`, `network_type`, `network_scenario`, `status`, `create_time`, `update_time`, `deleted`)
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

-- 迁移现有网络类型数据
INSERT INTO `unified_network` (`name`, `description`, `network_type`, `network_scenario`, `status`, `create_time`, `update_time`, `deleted`)
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

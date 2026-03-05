-- =====================================================
-- 告警方案表结构优化
-- 版本：V1.0.2
-- 日期：2026-03-04
-- 说明：解决告警方案与规则关联、指标去重展示、TBEL支持等问题
-- 优化：所有业务逻辑在应用层实现，数据库只做数据存储
-- =====================================================

-- 1. 告警级别条件表增加 TBEL 脚本支持
ALTER TABLE g3d_alarm_level_condition 
ADD COLUMN tbel_script TEXT NOT NULL DEFAULT '';

COMMENT ON COLUMN g3d_alarm_level_condition.tbel_script IS 'TBEL 自定义脚本（可选），为空时使用 condition_operator + threshold_value';

-- 2. 告警方案设备规则映射表增加规则版本号和规则哈希
ALTER TABLE g3d_alarm_scheme_device_rule 
ADD COLUMN rule_version INT NOT NULL DEFAULT 1,
ADD COLUMN rule_hash VARCHAR(64) NOT NULL DEFAULT '';

COMMENT ON COLUMN g3d_alarm_scheme_device_rule.rule_version IS '规则版本号，每次规则变更时递增';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.rule_hash IS '规则内容哈希值（MD5），用于判断规则是否变更，由应用层计算';

-- 3. 创建索引优化查询性能
CREATE INDEX idx_g3d_alarm_scheme_device_rule_rule_hash ON g3d_alarm_scheme_device_rule(rule_hash);
CREATE INDEX idx_g3d_alarm_scheme_device_rule_scheme_sync ON g3d_alarm_scheme_device_rule(scheme_id, sync_status);
CREATE INDEX idx_g3d_alarm_scheme_metric_rule_scheme_metric ON g3d_alarm_scheme_metric_rule(scheme_id, metric_key);

-- 4. 示例数据说明
COMMENT ON COLUMN g3d_alarm_level_condition.tbel_script IS 
'TBEL 自定义脚本示例：
-- 简单条件（使用 condition_operator）
tbel_script = "" (空字符串，使用 condition_operator + threshold_value)

-- 复杂条件（使用 TBEL 脚本）
tbel_script = "
var temp = msg.temperature;
var pressure = msg.pressure;
return temp > 80 && pressure > 1.5;
"

-- 时间窗口条件
tbel_script = "
var values = getTimeseries(''temperature'', now() - 300000, now());
var avg = values.reduce((a,b) => a + b.value, 0) / values.length;
return avg > 75;
"
';

-- =====================================================
-- 告警管理系统数据库增量脚本
-- 版本：V1.0.1
-- 日期：2026-03-03
-- 说明：调整 alarm_scheme_device_rule 表字段命名
-- =====================================================

-- 重命名字段以更准确反映其含义
-- tb_alarm_rule_id -> tb_calculated_field_id
ALTER TABLE alarm_scheme_device_rule 
  RENAME COLUMN tb_alarm_rule_id TO tb_calculated_field_id;

-- 更新字段注释
COMMENT ON COLUMN alarm_scheme_device_rule.tb_calculated_field_id IS 'ThingsBoard计算字段ID（UUID）';
COMMENT ON COLUMN alarm_scheme_device_rule.tb_alarm_type IS 'ThingsBoard告警类型（格式：{scheme_code}_{device_id}，全局唯一，用于Kafka消息定位告警方案）';

-- 说明：
-- 1. tb_calculated_field_id 存储 ThingsBoard 返回的 CalculatedField UUID
-- 2. tb_alarm_type 格式示例：PUMP_TEMP_001_3001（方案编码_设备ID）
-- 3. tb_alarm_type 是 Kafka 消息中唯一能定位告警方案的字段

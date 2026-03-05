-- =====================================================
-- 告警管理系统数据库初始化脚本 (PostgreSQL)
-- 版本：V1.0.0
-- 日期：2026-03-04
-- 数据库：PostgreSQL 14+
-- =====================================================

-- 告警方案表
CREATE TABLE g3d_alarm_scheme (
  id BIGSERIAL PRIMARY KEY,
  scheme_code VARCHAR(50) NOT NULL,
  scheme_name VARCHAR(100) NOT NULL,
  station_type_id BIGINT NOT NULL,
  alarm_message VARCHAR(500) NOT NULL DEFAULT '',
  enable_rule_type VARCHAR(20) NOT NULL DEFAULT 'ALWAYS',
  enable_rule_config JSONB NOT NULL DEFAULT '{}',
  device_count INT NOT NULL DEFAULT 0,
  status SMALLINT NOT NULL DEFAULT 1,
  created_by BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted SMALLINT NOT NULL DEFAULT 0,
  CONSTRAINT uk_scheme_code UNIQUE (scheme_code)
);

COMMENT ON TABLE g3d_alarm_scheme IS '告警方案表';
COMMENT ON COLUMN g3d_alarm_scheme.id IS '主键ID';
COMMENT ON COLUMN g3d_alarm_scheme.scheme_code IS '告警方案编码（唯一）';
COMMENT ON COLUMN g3d_alarm_scheme.scheme_name IS '告警方案名称';
COMMENT ON COLUMN g3d_alarm_scheme.station_type_id IS '测站类型ID';
COMMENT ON COLUMN g3d_alarm_scheme.alarm_message IS '告警提示语';
COMMENT ON COLUMN g3d_alarm_scheme.enable_rule_type IS '启动规则类型：ALWAYS-始终启动,SCHEDULED-定时启动,CUSTOM-自定义时间,CONDITION-工况启动';
COMMENT ON COLUMN g3d_alarm_scheme.enable_rule_config IS '启动规则配置JSON';
COMMENT ON COLUMN g3d_alarm_scheme.device_count IS '关联设备数量（冗余字段）';
COMMENT ON COLUMN g3d_alarm_scheme.status IS '状态：0-禁用,1-启用';
COMMENT ON COLUMN g3d_alarm_scheme.created_by IS '创建人ID，0表示系统';
COMMENT ON COLUMN g3d_alarm_scheme.created_at IS '创建时间';
COMMENT ON COLUMN g3d_alarm_scheme.updated_by IS '更新人ID，0表示系统';
COMMENT ON COLUMN g3d_alarm_scheme.updated_at IS '更新时间';
COMMENT ON COLUMN g3d_alarm_scheme.deleted IS '逻辑删除：0-未删除,1-已删除';

CREATE INDEX idx_g3d_alarm_scheme_station_type ON g3d_alarm_scheme(station_type_id);
CREATE INDEX idx_g3d_alarm_scheme_status ON g3d_alarm_scheme(status, deleted);
CREATE INDEX idx_g3d_alarm_scheme_created_at ON g3d_alarm_scheme(created_at);

-- 创建更新时间触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为 g3d_alarm_scheme 表创建触发器
CREATE TRIGGER trigger_g3d_alarm_scheme_updated_at
BEFORE UPDATE ON g3d_alarm_scheme
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 告警方案测站关联表
CREATE TABLE g3d_alarm_scheme_station (
  id BIGSERIAL PRIMARY KEY,
  scheme_id BIGINT NOT NULL,
  station_id BIGINT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_scheme_station UNIQUE (scheme_id, station_id)
);

COMMENT ON TABLE g3d_alarm_scheme_station IS '告警方案测站关联表';
COMMENT ON COLUMN g3d_alarm_scheme_station.id IS '主键ID';
COMMENT ON COLUMN g3d_alarm_scheme_station.scheme_id IS '告警方案ID';
COMMENT ON COLUMN g3d_alarm_scheme_station.station_id IS '测站ID（外部系统）';
COMMENT ON COLUMN g3d_alarm_scheme_station.created_at IS '创建时间';

CREATE INDEX idx_g3d_alarm_scheme_station_station ON g3d_alarm_scheme_station(station_id);

-- 告警方案指标规则表
CREATE TABLE g3d_alarm_scheme_metric_rule (
  id BIGSERIAL PRIMARY KEY,
  scheme_id BIGINT NOT NULL,
  metric_key VARCHAR(100) NOT NULL,
  metric_name VARCHAR(100) NOT NULL,
  metric_alias VARCHAR(100) NOT NULL DEFAULT '',
  device_id BIGINT NOT NULL DEFAULT 0,
  trigger_type VARCHAR(20) NOT NULL DEFAULT 'INDEPENDENT',
  linkage_group_id BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE g3d_alarm_scheme_metric_rule IS '告警方案指标规则表';
COMMENT ON COLUMN g3d_alarm_scheme_metric_rule.id IS '主键ID';
COMMENT ON COLUMN g3d_alarm_scheme_metric_rule.scheme_id IS '告警方案ID';
COMMENT ON COLUMN g3d_alarm_scheme_metric_rule.metric_key IS '监测指标键';
COMMENT ON COLUMN g3d_alarm_scheme_metric_rule.metric_name IS '监测指标名称';
COMMENT ON COLUMN g3d_alarm_scheme_metric_rule.metric_alias IS '监测指标别名';
COMMENT ON COLUMN g3d_alarm_scheme_metric_rule.device_id IS '设备ID，0表示当前设备，非0表示其他设备（用于联动）';
COMMENT ON COLUMN g3d_alarm_scheme_metric_rule.trigger_type IS '触发类型：INDEPENDENT-独立触发,LINKAGE-联动触发';
COMMENT ON COLUMN g3d_alarm_scheme_metric_rule.linkage_group_id IS '联动组ID，0表示非联动，同一组内的规则需同时满足';
COMMENT ON COLUMN g3d_alarm_scheme_metric_rule.created_at IS '创建时间';
COMMENT ON COLUMN g3d_alarm_scheme_metric_rule.updated_at IS '更新时间';

CREATE INDEX idx_g3d_alarm_scheme_metric_rule_scheme ON g3d_alarm_scheme_metric_rule(scheme_id);
CREATE INDEX idx_g3d_alarm_scheme_metric_rule_linkage_group ON g3d_alarm_scheme_metric_rule(linkage_group_id);
CREATE INDEX idx_g3d_alarm_scheme_metric_rule_device ON g3d_alarm_scheme_metric_rule(device_id);

CREATE TRIGGER trigger_g3d_alarm_scheme_metric_rule_updated_at
BEFORE UPDATE ON g3d_alarm_scheme_metric_rule
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 告警级别条件表
CREATE TABLE g3d_alarm_level_condition (
  id BIGSERIAL PRIMARY KEY,
  metric_rule_id BIGINT NOT NULL,
  alarm_level VARCHAR(20) NOT NULL,
  condition_operator VARCHAR(20) NOT NULL,
  threshold_value DECIMAL(20,6) NOT NULL DEFAULT 0.000000,
  threshold_min DECIMAL(20,6) NOT NULL DEFAULT 0.000000,
  threshold_max DECIMAL(20,6) NOT NULL DEFAULT 0.000000,
  duration_seconds INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE g3d_alarm_level_condition IS '告警级别条件表';
COMMENT ON COLUMN g3d_alarm_level_condition.id IS '主键ID';
COMMENT ON COLUMN g3d_alarm_level_condition.metric_rule_id IS '指标规则ID';
COMMENT ON COLUMN g3d_alarm_level_condition.alarm_level IS '告警级别：CRITICAL-危险,MAJOR-重要,MINOR-次要,WARNING-警告,INDETERMINATE-轻微';
COMMENT ON COLUMN g3d_alarm_level_condition.condition_operator IS '条件操作符：GT-大于,GTE-大于等于,LT-小于,LTE-小于等于,EQ-等于,NEQ-不等于,BETWEEN-区间';
COMMENT ON COLUMN g3d_alarm_level_condition.threshold_value IS '阈值';
COMMENT ON COLUMN g3d_alarm_level_condition.threshold_min IS '区间最小值';
COMMENT ON COLUMN g3d_alarm_level_condition.threshold_max IS '区间最大值';
COMMENT ON COLUMN g3d_alarm_level_condition.duration_seconds IS '持续时间(秒)，0表示不限制';
COMMENT ON COLUMN g3d_alarm_level_condition.created_at IS '创建时间';
COMMENT ON COLUMN g3d_alarm_level_condition.updated_at IS '更新时间';

CREATE INDEX idx_g3d_alarm_level_condition_metric_rule ON g3d_alarm_level_condition(metric_rule_id);
CREATE INDEX idx_g3d_alarm_level_condition_alarm_level ON g3d_alarm_level_condition(alarm_level);

CREATE TRIGGER trigger_g3d_alarm_level_condition_updated_at
BEFORE UPDATE ON g3d_alarm_level_condition
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 告警方案设备规则映射表
CREATE TABLE g3d_alarm_scheme_device_rule (
  id BIGSERIAL PRIMARY KEY,
  scheme_id BIGINT NOT NULL,
  device_id BIGINT NOT NULL,
  tb_device_id VARCHAR(100) NOT NULL,
  tb_alarm_type VARCHAR(100) NOT NULL,
  tb_calculated_field_id VARCHAR(100) NOT NULL DEFAULT '',
  sync_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  sync_time TIMESTAMP NOT NULL DEFAULT '1970-01-01 00:00:00',
  sync_error VARCHAR(500) NOT NULL DEFAULT '',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_tb_alarm_type UNIQUE (tb_alarm_type)
);

COMMENT ON TABLE g3d_alarm_scheme_device_rule IS '告警方案设备规则映射表';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.id IS '主键ID';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.scheme_id IS '告警方案ID';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.device_id IS '设备ID（外部系统）';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.tb_device_id IS 'ThingsBoard设备ID';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.tb_alarm_type IS 'ThingsBoard告警类型（格式：{scheme_code}_{device_id}，全局唯一，用于Kafka消息定位告警方案）';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.tb_calculated_field_id IS 'ThingsBoard计算字段ID（UUID）';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.sync_status IS '同步状态：PENDING-待同步,SUCCESS-成功,FAILED-失败';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.sync_time IS '同步时间，1970-01-01表示未同步';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.sync_error IS '同步失败原因';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.created_at IS '创建时间';
COMMENT ON COLUMN g3d_alarm_scheme_device_rule.updated_at IS '更新时间';

CREATE INDEX idx_g3d_alarm_scheme_device_rule_scheme ON g3d_alarm_scheme_device_rule(scheme_id);
CREATE INDEX idx_g3d_alarm_scheme_device_rule_device ON g3d_alarm_scheme_device_rule(device_id);
CREATE INDEX idx_g3d_alarm_scheme_device_rule_tb_device ON g3d_alarm_scheme_device_rule(tb_device_id);
CREATE INDEX idx_g3d_alarm_scheme_device_rule_sync_status ON g3d_alarm_scheme_device_rule(sync_status);

CREATE TRIGGER trigger_g3d_alarm_scheme_device_rule_updated_at
BEFORE UPDATE ON g3d_alarm_scheme_device_rule
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 告警实例表
CREATE TABLE g3d_alarm_instance (
  id BIGSERIAL PRIMARY KEY,
  tb_alarm_id VARCHAR(100) NOT NULL,
  tb_alarm_type VARCHAR(100) NOT NULL,
  scheme_id BIGINT NOT NULL,
  scheme_name VARCHAR(100) NOT NULL DEFAULT '',
  device_id BIGINT NOT NULL,
  device_name VARCHAR(100) NOT NULL DEFAULT '',
  tb_device_id VARCHAR(100) NOT NULL,
  product_id BIGINT NOT NULL DEFAULT 0,
  product_name VARCHAR(100) NOT NULL DEFAULT '',
  metric_key VARCHAR(100) NOT NULL,
  metric_name VARCHAR(100) NOT NULL,
  alarm_level VARCHAR(20) NOT NULL,
  alarm_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  trigger_type VARCHAR(20) NOT NULL DEFAULT 'INDEPENDENT',
  trigger_value DECIMAL(20,6) NOT NULL DEFAULT 0.000000,
  trigger_condition VARCHAR(200) NOT NULL DEFAULT '',
  triggered_metrics JSONB NOT NULL DEFAULT '{}',
  alarm_description VARCHAR(1000) NOT NULL DEFAULT '',
  trigger_count INT NOT NULL DEFAULT 1,
  first_trigger_time TIMESTAMP NOT NULL,
  last_trigger_time TIMESTAMP NOT NULL,
  acknowledged_time TIMESTAMP NOT NULL DEFAULT '1970-01-01 00:00:00',
  acknowledged_by BIGINT NOT NULL DEFAULT 0,
  acknowledged_remark VARCHAR(500) NOT NULL DEFAULT '',
  assignee_id BIGINT NOT NULL DEFAULT 0,
  assignee_name VARCHAR(100) NOT NULL DEFAULT '',
  cleared_time TIMESTAMP NOT NULL DEFAULT '1970-01-01 00:00:00',
  resolved_time TIMESTAMP NOT NULL DEFAULT '1970-01-01 00:00:00',
  raw_tb_message JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_tb_alarm UNIQUE (tb_alarm_id)
);

COMMENT ON TABLE g3d_alarm_instance IS '告警实例表';
COMMENT ON COLUMN g3d_alarm_instance.id IS '主键ID';
COMMENT ON COLUMN g3d_alarm_instance.tb_alarm_id IS 'ThingsBoard告警ID';
COMMENT ON COLUMN g3d_alarm_instance.tb_alarm_type IS 'ThingsBoard告警规则类型';
COMMENT ON COLUMN g3d_alarm_instance.scheme_id IS '告警方案ID';
COMMENT ON COLUMN g3d_alarm_instance.scheme_name IS '告警方案名称';
COMMENT ON COLUMN g3d_alarm_instance.device_id IS '设备ID（外部系统）';
COMMENT ON COLUMN g3d_alarm_instance.device_name IS '设备名称';
COMMENT ON COLUMN g3d_alarm_instance.tb_device_id IS 'ThingsBoard设备ID';
COMMENT ON COLUMN g3d_alarm_instance.product_id IS '产品ID，0表示未关联';
COMMENT ON COLUMN g3d_alarm_instance.product_name IS '产品名称';
COMMENT ON COLUMN g3d_alarm_instance.metric_key IS '触发指标键';
COMMENT ON COLUMN g3d_alarm_instance.metric_name IS '触发指标名称';
COMMENT ON COLUMN g3d_alarm_instance.alarm_level IS '告警级别：CRITICAL,MAJOR,MINOR,WARNING,INDETERMINATE';
COMMENT ON COLUMN g3d_alarm_instance.alarm_status IS '告警状态：ACTIVE-报警中,ACKNOWLEDGED-已确认,CLEARED-已清除,RESOLVED-已处置';
COMMENT ON COLUMN g3d_alarm_instance.trigger_type IS '触发类型：INDEPENDENT-独立,LINKAGE-联动';
COMMENT ON COLUMN g3d_alarm_instance.trigger_value IS '触发值';
COMMENT ON COLUMN g3d_alarm_instance.trigger_condition IS '触发条件描述';
COMMENT ON COLUMN g3d_alarm_instance.triggered_metrics IS '联动触发时的所有指标值';
COMMENT ON COLUMN g3d_alarm_instance.alarm_description IS '告警描述';
COMMENT ON COLUMN g3d_alarm_instance.trigger_count IS '触发次数';
COMMENT ON COLUMN g3d_alarm_instance.first_trigger_time IS '首次触发时间';
COMMENT ON COLUMN g3d_alarm_instance.last_trigger_time IS '最后触发时间';
COMMENT ON COLUMN g3d_alarm_instance.acknowledged_time IS '确认时间，1970-01-01表示未确认';
COMMENT ON COLUMN g3d_alarm_instance.acknowledged_by IS '确认人ID，0表示未确认';
COMMENT ON COLUMN g3d_alarm_instance.acknowledged_remark IS '确认备注';
COMMENT ON COLUMN g3d_alarm_instance.assignee_id IS '委托人ID，0表示未委托';
COMMENT ON COLUMN g3d_alarm_instance.assignee_name IS '委托人姓名';
COMMENT ON COLUMN g3d_alarm_instance.cleared_time IS '清除时间，1970-01-01表示未清除';
COMMENT ON COLUMN g3d_alarm_instance.resolved_time IS '处置完成时间，1970-01-01表示未处置';
COMMENT ON COLUMN g3d_alarm_instance.raw_tb_message IS '原始ThingsBoard消息';
COMMENT ON COLUMN g3d_alarm_instance.created_at IS '创建时间';
COMMENT ON COLUMN g3d_alarm_instance.updated_at IS '更新时间';

CREATE INDEX idx_g3d_alarm_instance_tb_alarm_type ON g3d_alarm_instance(tb_alarm_type);
CREATE INDEX idx_g3d_alarm_instance_device ON g3d_alarm_instance(device_id);
CREATE INDEX idx_g3d_alarm_instance_tb_device ON g3d_alarm_instance(tb_device_id);
CREATE INDEX idx_g3d_alarm_instance_scheme ON g3d_alarm_instance(scheme_id);
CREATE INDEX idx_g3d_alarm_instance_status ON g3d_alarm_instance(alarm_status);
CREATE INDEX idx_g3d_alarm_instance_level ON g3d_alarm_instance(alarm_level);
CREATE INDEX idx_g3d_alarm_instance_trigger_time ON g3d_alarm_instance(first_trigger_time, last_trigger_time);
CREATE INDEX idx_g3d_alarm_instance_assignee ON g3d_alarm_instance(assignee_id);
CREATE INDEX idx_g3d_alarm_instance_created_at ON g3d_alarm_instance(created_at);

CREATE TRIGGER trigger_g3d_alarm_instance_updated_at
BEFORE UPDATE ON g3d_alarm_instance
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 告警实例测站关联表
CREATE TABLE g3d_alarm_instance_station (
  id BIGSERIAL PRIMARY KEY,
  alarm_id BIGINT NOT NULL,
  station_id BIGINT NOT NULL,
  station_name VARCHAR(100) NOT NULL DEFAULT '',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE g3d_alarm_instance_station IS '告警实例测站关联表';
COMMENT ON COLUMN g3d_alarm_instance_station.id IS '主键ID';
COMMENT ON COLUMN g3d_alarm_instance_station.alarm_id IS '告警实例ID';
COMMENT ON COLUMN g3d_alarm_instance_station.station_id IS '测站ID（外部系统）';
COMMENT ON COLUMN g3d_alarm_instance_station.station_name IS '测站名称';
COMMENT ON COLUMN g3d_alarm_instance_station.created_at IS '创建时间';

CREATE INDEX idx_g3d_alarm_instance_station_alarm ON g3d_alarm_instance_station(alarm_id);
CREATE INDEX idx_g3d_alarm_instance_station_station ON g3d_alarm_instance_station(station_id);

-- 告警处理记录表
CREATE TABLE g3d_alarm_handle_log (
  id BIGSERIAL PRIMARY KEY,
  alarm_id BIGINT NOT NULL,
  handle_type VARCHAR(20) NOT NULL,
  step_description TEXT NOT NULL,
  handle_result VARCHAR(500) NOT NULL DEFAULT '',
  image_urls JSONB NOT NULL DEFAULT '[]',
  operator_id BIGINT NOT NULL,
  operator_name VARCHAR(100) NOT NULL DEFAULT '',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE g3d_alarm_handle_log IS '告警处理记录表';
COMMENT ON COLUMN g3d_alarm_handle_log.id IS '主键ID';
COMMENT ON COLUMN g3d_alarm_handle_log.alarm_id IS '告警实例ID';
COMMENT ON COLUMN g3d_alarm_handle_log.handle_type IS '处理类型：ACKNOWLEDGE-确认,ASSIGN-委托,HANDLE-处置,CLEAR-清除,COMMENT-评论';
COMMENT ON COLUMN g3d_alarm_handle_log.step_description IS '处理步骤描述';
COMMENT ON COLUMN g3d_alarm_handle_log.handle_result IS '处理结果';
COMMENT ON COLUMN g3d_alarm_handle_log.image_urls IS '处理图片URL列表';
COMMENT ON COLUMN g3d_alarm_handle_log.operator_id IS '操作人ID';
COMMENT ON COLUMN g3d_alarm_handle_log.operator_name IS '操作人姓名';
COMMENT ON COLUMN g3d_alarm_handle_log.created_at IS '创建时间';

CREATE INDEX idx_g3d_alarm_handle_log_alarm ON g3d_alarm_handle_log(alarm_id);
CREATE INDEX idx_g3d_alarm_handle_log_handle_type ON g3d_alarm_handle_log(handle_type);
CREATE INDEX idx_g3d_alarm_handle_log_created_at ON g3d_alarm_handle_log(created_at);

-- 告警状态历史表
CREATE TABLE g3d_alarm_status_history (
  id BIGSERIAL PRIMARY KEY,
  alarm_id BIGINT NOT NULL,
  from_status VARCHAR(20) NOT NULL DEFAULT '',
  to_status VARCHAR(20) NOT NULL,
  operator_id BIGINT NOT NULL DEFAULT 0,
  remark VARCHAR(500) NOT NULL DEFAULT '',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE g3d_alarm_status_history IS '告警状态历史表';
COMMENT ON COLUMN g3d_alarm_status_history.id IS '主键ID';
COMMENT ON COLUMN g3d_alarm_status_history.alarm_id IS '告警实例ID';
COMMENT ON COLUMN g3d_alarm_status_history.from_status IS '原状态，空字符串表示初始状态';
COMMENT ON COLUMN g3d_alarm_status_history.to_status IS '目标状态';
COMMENT ON COLUMN g3d_alarm_status_history.operator_id IS '操作人ID，0表示系统自动';
COMMENT ON COLUMN g3d_alarm_status_history.remark IS '备注';
COMMENT ON COLUMN g3d_alarm_status_history.created_at IS '创建时间';

CREATE INDEX idx_g3d_alarm_status_history_alarm ON g3d_alarm_status_history(alarm_id);
CREATE INDEX idx_g3d_alarm_status_history_created_at ON g3d_alarm_status_history(created_at);

-- 通知规则表
CREATE TABLE g3d_notify_rule (
  id BIGSERIAL PRIMARY KEY,
  rule_name VARCHAR(100) NOT NULL,
  notify_type VARCHAR(20) NOT NULL,
  trigger_event VARCHAR(50) NOT NULL,
  alarm_level_filter VARCHAR(100) NOT NULL DEFAULT 'ALL',
  device_ids JSONB NOT NULL DEFAULT '[]',
  template_id BIGINT NOT NULL,
  user_group_id BIGINT NOT NULL,
  description VARCHAR(500) NOT NULL DEFAULT '',
  status SMALLINT NOT NULL DEFAULT 1,
  created_by BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted SMALLINT NOT NULL DEFAULT 0
);

COMMENT ON TABLE g3d_notify_rule IS '通知规则表';
COMMENT ON COLUMN g3d_notify_rule.id IS '主键ID';
COMMENT ON COLUMN g3d_notify_rule.rule_name IS '通知规则名称';
COMMENT ON COLUMN g3d_notify_rule.notify_type IS '通知类型：BEHAVIOR-行为通知,ALARM-报警通知';
COMMENT ON COLUMN g3d_notify_rule.trigger_event IS '触发事件：DEVICE_ADDED,DEVICE_DELETED,DEVICE_OFFLINE,DEVICE_ONLINE,ALARM_CREATED,ALARM_LEVEL_CHANGED,ALARM_ACKNOWLEDGED,ALARM_CLEARED';
COMMENT ON COLUMN g3d_notify_rule.alarm_level_filter IS '告警级别过滤，多个用逗号分隔：ALL,CRITICAL,MAJOR,MINOR,WARNING,INDETERMINATE';
COMMENT ON COLUMN g3d_notify_rule.device_ids IS '关联设备ID列表（行为通知用）';
COMMENT ON COLUMN g3d_notify_rule.template_id IS '通知模板ID';
COMMENT ON COLUMN g3d_notify_rule.user_group_id IS '通知接收组ID';
COMMENT ON COLUMN g3d_notify_rule.description IS '规则描述';
COMMENT ON COLUMN g3d_notify_rule.status IS '状态：0-禁用,1-启用';
COMMENT ON COLUMN g3d_notify_rule.created_by IS '创建人ID，0表示系统';
COMMENT ON COLUMN g3d_notify_rule.created_at IS '创建时间';
COMMENT ON COLUMN g3d_notify_rule.updated_by IS '更新人ID，0表示系统';
COMMENT ON COLUMN g3d_notify_rule.updated_at IS '更新时间';
COMMENT ON COLUMN g3d_notify_rule.deleted IS '逻辑删除：0-未删除,1-已删除';

CREATE INDEX idx_g3d_notify_rule_notify_type ON g3d_notify_rule(notify_type);
CREATE INDEX idx_g3d_notify_rule_trigger_event ON g3d_notify_rule(trigger_event);
CREATE INDEX idx_g3d_notify_rule_status ON g3d_notify_rule(status, deleted);

CREATE TRIGGER trigger_g3d_notify_rule_updated_at
BEFORE UPDATE ON g3d_notify_rule
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 通知模板表
CREATE TABLE g3d_notify_template (
  id BIGSERIAL PRIMARY KEY,
  template_name VARCHAR(100) NOT NULL,
  notify_type VARCHAR(20) NOT NULL,
  notify_channels VARCHAR(100) NOT NULL,
  subject VARCHAR(200) NOT NULL,
  content TEXT NOT NULL,
  created_by BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted SMALLINT NOT NULL DEFAULT 0
);

COMMENT ON TABLE g3d_notify_template IS '通知模板表';
COMMENT ON COLUMN g3d_notify_template.id IS '主键ID';
COMMENT ON COLUMN g3d_notify_template.template_name IS '模板名称';
COMMENT ON COLUMN g3d_notify_template.notify_type IS '通知类型：BEHAVIOR-行为通知,ALARM-报警通知';
COMMENT ON COLUMN g3d_notify_template.notify_channels IS '通知方式，多个用逗号分隔：WEB,EMAIL,SMS';
COMMENT ON COLUMN g3d_notify_template.subject IS '通知主题';
COMMENT ON COLUMN g3d_notify_template.content IS '通知内容，支持变量占位符';
COMMENT ON COLUMN g3d_notify_template.created_by IS '创建人ID，0表示系统';
COMMENT ON COLUMN g3d_notify_template.created_at IS '创建时间';
COMMENT ON COLUMN g3d_notify_template.updated_by IS '更新人ID，0表示系统';
COMMENT ON COLUMN g3d_notify_template.updated_at IS '更新时间';
COMMENT ON COLUMN g3d_notify_template.deleted IS '逻辑删除：0-未删除,1-已删除';

CREATE INDEX idx_g3d_notify_template_notify_type ON g3d_notify_template(notify_type);
CREATE INDEX idx_g3d_notify_template_deleted ON g3d_notify_template(deleted);

CREATE TRIGGER trigger_g3d_notify_template_updated_at
BEFORE UPDATE ON g3d_notify_template
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 通知用户组表
CREATE TABLE g3d_notify_user_group (
  id BIGSERIAL PRIMARY KEY,
  group_name VARCHAR(100) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_by BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted SMALLINT NOT NULL DEFAULT 0
);

COMMENT ON TABLE g3d_notify_user_group IS '通知用户组表';
COMMENT ON COLUMN g3d_notify_user_group.id IS '主键ID';
COMMENT ON COLUMN g3d_notify_user_group.group_name IS '用户组名称';
COMMENT ON COLUMN g3d_notify_user_group.sort_order IS '排序';
COMMENT ON COLUMN g3d_notify_user_group.created_by IS '创建人ID，0表示系统';
COMMENT ON COLUMN g3d_notify_user_group.created_at IS '创建时间';
COMMENT ON COLUMN g3d_notify_user_group.updated_by IS '更新人ID，0表示系统';
COMMENT ON COLUMN g3d_notify_user_group.updated_at IS '更新时间';
COMMENT ON COLUMN g3d_notify_user_group.deleted IS '逻辑删除：0-未删除,1-已删除';

CREATE INDEX idx_g3d_notify_user_group_deleted ON g3d_notify_user_group(deleted);

CREATE TRIGGER trigger_g3d_notify_user_group_updated_at
BEFORE UPDATE ON g3d_notify_user_group
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 通知用户组成员表
CREATE TABLE g3d_notify_user_group_member (
  id BIGSERIAL PRIMARY KEY,
  group_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  user_name VARCHAR(100) NOT NULL DEFAULT '',
  user_email VARCHAR(100) NOT NULL DEFAULT '',
  user_phone VARCHAR(20) NOT NULL DEFAULT '',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uk_group_user UNIQUE (group_id, user_id)
);

COMMENT ON TABLE g3d_notify_user_group_member IS '通知用户组成员表';
COMMENT ON COLUMN g3d_notify_user_group_member.id IS '主键ID';
COMMENT ON COLUMN g3d_notify_user_group_member.group_id IS '用户组ID';
COMMENT ON COLUMN g3d_notify_user_group_member.user_id IS '用户ID';
COMMENT ON COLUMN g3d_notify_user_group_member.user_name IS '用户姓名';
COMMENT ON COLUMN g3d_notify_user_group_member.user_email IS '用户邮箱';
COMMENT ON COLUMN g3d_notify_user_group_member.user_phone IS '用户手机号';
COMMENT ON COLUMN g3d_notify_user_group_member.created_at IS '创建时间';

CREATE INDEX idx_g3d_notify_user_group_member_user ON g3d_notify_user_group_member(user_id);

-- 通知记录表
CREATE TABLE g3d_notify_record (
  id BIGSERIAL PRIMARY KEY,
  notify_type VARCHAR(20) NOT NULL,
  notify_channel VARCHAR(20) NOT NULL,
  subject VARCHAR(200) NOT NULL,
  content TEXT NOT NULL,
  alarm_id BIGINT NOT NULL DEFAULT 0,
  rule_id BIGINT NOT NULL DEFAULT 0,
  template_id BIGINT NOT NULL DEFAULT 0,
  user_id BIGINT NOT NULL,
  user_name VARCHAR(100) NOT NULL DEFAULT '',
  send_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  send_time TIMESTAMP NOT NULL DEFAULT '1970-01-01 00:00:00',
  fail_reason VARCHAR(500) NOT NULL DEFAULT '',
  retry_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE g3d_notify_record IS '通知记录表';
COMMENT ON COLUMN g3d_notify_record.id IS '主键ID';
COMMENT ON COLUMN g3d_notify_record.notify_type IS '通知类型：BEHAVIOR-行为通知,ALARM-报警通知';
COMMENT ON COLUMN g3d_notify_record.notify_channel IS '通知渠道：WEB,EMAIL,SMS';
COMMENT ON COLUMN g3d_notify_record.subject IS '通知主题';
COMMENT ON COLUMN g3d_notify_record.content IS '通知内容';
COMMENT ON COLUMN g3d_notify_record.alarm_id IS '关联告警ID，0表示非告警通知';
COMMENT ON COLUMN g3d_notify_record.rule_id IS '触发规则ID，0表示手动触发';
COMMENT ON COLUMN g3d_notify_record.template_id IS '使用模板ID，0表示未使用模板';
COMMENT ON COLUMN g3d_notify_record.user_id IS '接收用户ID';
COMMENT ON COLUMN g3d_notify_record.user_name IS '接收用户姓名';
COMMENT ON COLUMN g3d_notify_record.send_status IS '发送状态：PENDING-待发送,SUCCESS-成功,FAILED-失败';
COMMENT ON COLUMN g3d_notify_record.send_time IS '发送时间，1970-01-01表示未发送';
COMMENT ON COLUMN g3d_notify_record.fail_reason IS '失败原因';
COMMENT ON COLUMN g3d_notify_record.retry_count IS '重试次数';
COMMENT ON COLUMN g3d_notify_record.created_at IS '创建时间';

CREATE INDEX idx_g3d_notify_record_notify_type ON g3d_notify_record(notify_type);
CREATE INDEX idx_g3d_notify_record_alarm ON g3d_notify_record(alarm_id);
CREATE INDEX idx_g3d_notify_record_user ON g3d_notify_record(user_id);
CREATE INDEX idx_g3d_notify_record_status ON g3d_notify_record(send_status);
CREATE INDEX idx_g3d_notify_record_created_at ON g3d_notify_record(created_at);

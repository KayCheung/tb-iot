# 数据库迁移脚本说明

## 脚本命名规范

```
V{版本号}__{描述}.sql
```

示例：
- `V1.0.0__init_schema.sql` - 初始化数据库表结构
- `V1.0.1__add_device_count_to_alarm_scheme.sql` - 增加设备数量字段

## 执行顺序

脚本按版本号顺序执行，建议使用 Flyway 或 Liquibase 进行数据库版本管理。

## 脚本列表

| 版本 | 文件名 | 描述 | 状态 |
|------|--------|------|------|
| V1.0.0 | init-schema.sql | 初始化数据库表结构（包含所有12张表） | 已完成 |

## 执行方式

### 方式一：直接执行（推荐用于初始化）

```bash
# 创建数据库
psql -U postgres -c "CREATE DATABASE iot_alarm WITH ENCODING='UTF8' LC_COLLATE='zh_CN.UTF-8' LC_CTYPE='zh_CN.UTF-8' TEMPLATE=template0;"

# 执行初始化脚本
psql -U postgres -d iot_alarm -f db/init-schema.sql
```

### 方式二：使用 Flyway

```bash
# 1. 配置 flyway.conf
flyway.url=jdbc:postgresql://localhost:5432/iot_alarm
flyway.user=postgres
flyway.password=your_password
flyway.locations=filesystem:db/migration

# 2. 执行迁移
flyway migrate

# 3. 查看迁移历史
flyway info
```

## 表结构说明

### 告警方案相关表（5张）
1. `alarm_scheme` - 告警方案表
2. `alarm_scheme_station` - 告警方案测站关联表
3. `alarm_scheme_metric_rule` - 告警方案指标规则表
4. `alarm_level_condition` - 告警级别条件表
5. `alarm_scheme_device_rule` - 告警方案设备规则映射表

### 告警记录相关表（4张）
6. `alarm_instance` - 告警实例表
7. `alarm_instance_station` - 告警实例测站关联表
8. `alarm_handle_log` - 告警处理记录表
9. `alarm_status_history` - 告警状态历史表

### 通知管理相关表（5张）
10. `notify_rule` - 通知规则表
11. `notify_template` - 通知模板表
12. `notify_user_group` - 通知用户组表
13. `notify_user_group_member` - 通知用户组成员表
14. `notify_record` - 通知记录表

## 回滚说明

如果需要删除所有表：

```sql
-- 按依赖关系逆序删除表
DROP TABLE IF EXISTS notify_record;
DROP TABLE IF EXISTS notify_user_group_member;
DROP TABLE IF EXISTS notify_user_group;
DROP TABLE IF EXISTS notify_template;
DROP TABLE IF EXISTS notify_rule;
DROP TABLE IF EXISTS alarm_status_history;
DROP TABLE IF EXISTS alarm_handle_log;
DROP TABLE IF EXISTS alarm_instance_station;
DROP TABLE IF EXISTS alarm_instance;
DROP TABLE IF EXISTS alarm_scheme_device_rule;
DROP TABLE IF EXISTS alarm_level_condition;
DROP TABLE IF EXISTS alarm_scheme_metric_rule;
DROP TABLE IF EXISTS alarm_scheme_station;
DROP TABLE IF EXISTS alarm_scheme;
```

## 注意事项

1. **备份数据库**：执行迁移前务必备份数据库
2. **测试环境验证**：先在测试环境执行，验证无误后再在生产环境执行
3. **停机维护**：对于大表的结构变更，建议在业务低峰期执行
4. **监控执行时间**：记录脚本执行时间，评估对业务的影响
5. **验证数据一致性**：执行后验证数据是否正确

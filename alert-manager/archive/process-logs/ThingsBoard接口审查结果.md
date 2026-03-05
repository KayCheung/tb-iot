# ThingsBoard 接口审查结果

## 审查日期
2026-03-03

## 审查范围
- ThingsBoard Calculated Field Controller API
- ThingsBoard Alarm Controller API
- Kafka 告警消息格式
- 数据库表结构
- 外部接口文档

## 主要发现

### 1. 接口类型不匹配 ✅ 已修复

**问题**：
- 文档中使用的是假设的 Alarm API：`POST /api/plugins/telemetry/DEVICE/{deviceId}/ALARM`
- 实际 ThingsBoard 使用的是 Calculated Field API：`POST /api/calculatedField`

**影响**：
- 无法正确创建告警规则
- 同步逻辑需要重新设计

**解决方案**：
- 更新 `.kiro/steering/external-apis.md` 文档
- 使用正确的 CalculatedField API

### 2. 数据库字段命名不准确 ✅ 已修复

**问题**：
- 字段名 `tb_alarm_rule_id` 不能准确反映其存储的是 CalculatedField ID

**解决方案**：
- 重命名为 `tb_calculated_field_id`
- 创建增量脚本：`db/migration/V1.0.1__update_alarm_scheme_device_rule.sql`
- 更新 `db/init-schema.sql` 初始化脚本

### 3. 告警类型生成规则已明确 ✅ 已定义

**规则**：
```
格式：{scheme_code}_{device_id}
示例：PUMP_TEMP_001_3001
```

**优点**：
- 全局唯一
- 包含方案信息和设备信息
- 便于追溯和调试
- 可以通过 Kafka 消息的 type 字段直接定位告警方案

### 4. CalculatedField 映射策略已确定 ✅ 已定义

**策略**：一个设备一个 CalculatedField

**实现方式**：
- 将告警方案的所有指标规则合并成一个复杂表达式
- 独立触发的规则：OR 连接
- 联动触发的规则：同一组内 AND 连接，组之间 OR 连接

**优点**：
- 管理简单
- 同步效率高
- 减少 API 调用次数

## 已完成的工作

### 1. 文档更新
- ✅ 更新 `.kiro/steering/external-apis.md`
  - 替换为实际的 CalculatedField API
  - 添加 Kafka 消息格式说明
  - 更新错误码说明

### 2. 数据库调整
- ✅ 创建增量脚本 `db/migration/V1.0.1__update_alarm_scheme_device_rule.sql`
- ✅ 更新初始化脚本 `db/init-schema.sql`
- ✅ 更新字段注释，明确 `tb_alarm_type` 的格式和用途

### 3. 设计文档
- ✅ 创建 `kiro-log/ThingsBoard接口分析与调整.md`
  - 详细的接口分析
  - CalculatedField 数据结构说明
  - 告警方案到 CalculatedField 的转换逻辑
  - 同步流程设计
  - Kafka 消息处理逻辑

## 接口对比

### 原设计（错误）
```
POST /api/plugins/telemetry/DEVICE/{deviceId}/ALARM
{
  "alarmType": "PUMP_TEMP_001_3001",
  "severity": "CRITICAL",
  "alarmDetails": { ... }
}
```

### 实际接口（正确）
```
POST /api/calculatedField
{
  "entityId": {
    "id": "device_uuid",
    "entityType": "DEVICE"
  },
  "type": "SIMPLE",
  "name": "PUMP_TEMP_001_3001",
  "configuration": {
    "arguments": { ... },
    "expression": "temperature > 80",
    "output": { ... }
  }
}
```

## 关键差异

| 项目 | 原设计 | 实际接口 |
|------|--------|----------|
| 接口路径 | `/api/plugins/telemetry/DEVICE/{deviceId}/ALARM` | `/api/calculatedField` |
| 实体类型 | ALARM_RULE | CALCULATED_FIELD |
| 配置方式 | alarmDetails | configuration (arguments + expression + output) |
| 规则表达式 | 条件数组 | 字符串表达式 |
| 返回ID字段 | alarmRuleId | calculatedFieldId |

## 后续工作建议

### 1. 代码实现（优先级：高）
- [ ] 实现 CalculatedField 转换逻辑
  - 表达式生成器
  - Arguments 构建器
  - Output 配置器
- [ ] 实现 ThingsBoard 客户端
  - 认证管理
  - API 调用封装
  - 错误处理
- [ ] 实现同步服务
  - 创建告警方案时同步
  - 更新告警方案时同步
  - 删除告警方案时同步
  - 失败重试机制

### 2. Kafka 消息处理（优先级：高）
- [ ] 实现 Kafka 消费者
- [ ] 实现告警方案定位逻辑
- [ ] 实现启动规则判断
- [ ] 实现告警实例创建
- [ ] 实现通知触发

### 3. 测试（优先级：中）
- [ ] 单元测试
  - 表达式生成测试
  - 同步逻辑测试
  - 消息处理测试
- [ ] 集成测试
  - ThingsBoard API 集成测试
  - Kafka 消息集成测试
  - 端到端测试

### 4. 文档完善（优先级：中）
- [ ] API 接口文档
- [ ] 部署文档
- [ ] 运维文档
- [ ] 故障排查文档

### 5. 监控和告警（优先级：低）
- [ ] 同步失败监控
- [ ] Kafka 消费延迟监控
- [ ] API 调用性能监控
- [ ] 告警通知监控

## 风险评估

### 1. 技术风险
- **风险**：CalculatedField 表达式复杂度限制
- **缓解**：测试复杂表达式的支持情况，必要时拆分为多个 CalculatedField

### 2. 性能风险
- **风险**：大量设备同步可能导致 ThingsBoard API 限流
- **缓解**：实现批量同步、限流控制、失败重试

### 3. 数据一致性风险
- **风险**：同步失败导致本地数据与 ThingsBoard 不一致
- **缓解**：实现定时同步任务、状态监控、手动重试功能

## 总结

通过本次审查，我们发现并修复了接口类型不匹配的关键问题，明确了告警方案到 ThingsBoard CalculatedField 的映射策略，更新了相关文档和数据库结构。

主要成果：
1. 明确了实际使用的 API 接口
2. 定义了告警类型生成规则
3. 设计了 CalculatedField 转换逻辑
4. 更新了数据库表结构
5. 完善了外部接口文档

下一步需要重点关注代码实现和测试工作，确保系统能够正确地与 ThingsBoard 集成。

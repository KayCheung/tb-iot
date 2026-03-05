---
description: 告警管理系统业务规则和约束条件
inclusion: auto
---

# 业务规则和约束

## 告警方案规则

### 创建规则
1. **唯一性约束**
   - `scheme_code` 必须全局唯一
   - 同一测站类型下，方案名称不能重复

2. **关联约束**
   - 必须关联至少一个测站
   - 关联的测站必须属于指定的测站类型
   - 必须配置至少一个指标规则

3. **指标规则约束**
   - 每个指标必须配置至少一个级别条件
   - 联动触发的指标必须设置相同的 `linkage_group_id`
   - 跨设备联动时，必须指定 `device_id`

4. **启动规则约束**
   - `SCHEDULED` 类型：必须配置 `startTime` 和 `endTime`
   - `CUSTOM` 类型：必须配置 `weekDays` 和 `timeRanges`
   - 时间范围必须合法（开始时间 < 结束时间）

### 更新规则
1. **状态约束**
   - 禁用状态的方案不能同步到 ThingsBoard
   - 更新方案后，必须重新同步到 ThingsBoard

2. **关联变更**
   - 新增测站：为新测站下的设备创建 ThingsBoard 规则
   - 移除测站：删除对应设备的 ThingsBoard 规则
   - 修改指标规则：更新所有设备的 ThingsBoard 规则

### 删除规则
1. **软删除**
   - 告警方案采用软删除（`deleted = 1`）
   - 删除后，删除所有 ThingsBoard 规则

2. **级联处理**
   - 删除方案时，不删除已存在的告警实例
   - 删除方案后，不再产生新的告警

## ThingsBoard 集成规则

### 告警规则类型生成规则
```
格式: {scheme_code}_{device_id}
示例: PUMP_TEMP_001_3001
```

### TBEL 脚本生成规则
1. **包含启动规则判断**
   - ALWAYS: 不添加时间判断
   - SCHEDULED: 添加日期范围和时间段判断
   - CUSTOM: 添加星期和多时间段判断
   - CONDITION: 添加工况条件判断

2. **包含指标条件判断**
   - 独立触发: OR 连接
   - 联动触发: AND 连接

3. **包含持续时间判断**
   - 使用 ctx.args.xxx.ts 计算持续时间
   - 简单场景: 值不变的时间
   - 复杂场景: 需要在告警系统侧实现

### 同步规则
1. **创建同步**
   - 创建告警方案后，立即同步到 ThingsBoard
   - 为每个关联设备创建一条 ThingsBoard 规则
   - 记录同步状态到 `alarm_scheme_device_rule` 表

2. **更新同步**
   - 更新告警方案后，批量更新 ThingsBoard 规则
   - 使用线程池并发调用 ThingsBoard API
   - 更新同步时间和状态

3. **删除同步**
   - 删除告警方案后，批量删除 ThingsBoard 规则
   - 删除 `alarm_scheme_device_rule` 映射记录

4. **失败重试**
   - 同步失败的规则，记录失败原因
   - 定时任务扫描失败记录，自动重试
   - 最多重试 3 次

### 告警规则配置
1. **指标配置**
   - 独立触发：单个指标满足条件即触发
   - 联动触发：多个指标同时满足条件才触发

2. **级别配置**
   - 支持 5 个级别：CRITICAL、MAJOR、MINOR、WARNING、INDETERMINATE
   - 级别优先级：CRITICAL > MAJOR > MINOR > WARNING > INDETERMINATE

3. **启动规则配置**
   - ALWAYS: 始终启动，不添加时间判断
   - SCHEDULED: 定时启动，判断日期范围和时间段
   - CUSTOM: 自定义时间，判断星期和多时间段
   - CONDITION: 工况启动，判断工况条件
   - 所有启动规则在 TBEL 脚本中实现，由 ThingsBoard 执行

4. **持续时间配置**
   - 在 TBEL 脚本中使用 ctx.args.xxx.ts 计算
   - 判断值保持不变的时间是否达到阈值

## 告警实例规则

### 创建规则
1. **唯一性约束**
   - 同一 `tb_alarm_id` 只能创建一个告警实例
   - 如果已存在，执行更新操作

2. **关联查询**
   - 通过 `tb_alarm_type` 查询 `alarm_scheme_device_rule` 表
   - 反查告警方案和设备信息
   - 调用外部接口查询设备关联的测站

3. **状态初始化**
   - 初始状态：`ACTIVE`（报警中）
   - 触发次数：1
   - 首次触发时间：当前时间
   - 最后触发时间：当前时间

### 更新规则
1. **重复触发**
   - 触发次数 +1
   - 更新最后触发时间
   - 不改变告警状态

2. **状态变更**
   - ThingsBoard 状态映射：
     - `ACTIVE_UNACK` → `ACTIVE`
     - `ACTIVE_ACK` → `ACKNOWLEDGED`
     - `CLEARED_UNACK` → `CLEARED`
     - `CLEARED_ACK` → `CLEARED`
   - 状态变更时，记录状态历史

3. **级别变更**
   - 如果告警级别变化，更新 `alarm_level`
   - 发送 `ALARM_LEVEL_CHANGED` 事件

### 处理规则
1. **确认告警**
   - 调用 ThingsBoard API：`POST /api/alarm/{alarmId}/ack`
   - 更新本地状态：`acknowledged_time` 和 `acknowledged_by`
   - 状态变更为 `ACKNOWLEDGED`
   - 记录处理日志
   - **注意**：必须先调用 ThingsBoard API，成功后再更新本地

2. **委托告警**
   - 更新本地状态：`assignee_id` 和 `assignee_name`
   - 记录处理日志
   - 发送通知给委托人
   - **注意**：委托是本地业务，不需要同步到 ThingsBoard

3. **清除告警**
   - 调用 ThingsBoard API：`POST /api/alarm/{alarmId}/clear`
   - 更新本地状态：`cleared_time`
   - 状态变更为 `CLEARED`
   - 记录处理日志
   - **注意**：必须先调用 ThingsBoard API，成功后再更新本地

4. **处置告警**
   - 更新本地状态：`resolved_time`
   - 状态变更为 `RESOLVED`
   - 记录处理日志
   - **注意**：处置是本地业务，不需要同步到 ThingsBoard

### 同步规则
1. **确认（ACK）和清除（CLEAR）必须同步**
   - 这两个操作会触发 ThingsBoard 规则链事件
   - 必须保持双向一致性
   - 同步失败时，回滚本地操作

2. **委托和处置不需要同步**
   - 这是告警管理系统的本地业务
   - ThingsBoard 不关心这些状态

## 通知规则

### 通知触发规则
1. **告警通知触发事件**
   - `ALARM_CREATED`: 告警创建
   - `ALARM_LEVEL_CHANGED`: 告警级别变化
   - `ALARM_ACKNOWLEDGED`: 告警已确认
   - `ALARM_ASSIGNED`: 告警已委托
   - `ALARM_CLEARED`: 告警已清除
   - `ALARM_RESOLVED`: 告警已处置

2. **行为通知触发事件**
   - `DEVICE_ADDED`: 设备新增
   - `DEVICE_DELETED`: 设备删除
   - `DEVICE_OFFLINE`: 设备离线
   - `DEVICE_ONLINE`: 设备在线

### 通知规则匹配
1. **告警通知匹配**
   - 匹配通知类型：`ALARM`
   - 匹配触发事件
   - 匹配告警级别（如果配置了级别过滤）

2. **行为通知匹配**
   - 匹配通知类型：`BEHAVIOR`
   - 匹配触发事件
   - 匹配设备ID（如果配置了设备过滤）

### 通知发送规则
1. **模板渲染**
   - 使用通知模板渲染通知内容
   - 支持变量占位符：`{deviceName}`、`{metricName}`、`{metricValue}` 等

2. **用户组展开**
   - 查询用户组成员
   - 为每个用户创建一条通知记录

3. **多渠道发送**
   - 根据模板配置的通知渠道发送
   - 支持 WEB、EMAIL、SMS 多渠道
   - 每个渠道独立发送，互不影响

4. **失败重试**
   - 发送失败的通知，记录失败原因
   - 最多重试 3 次
   - 重试间隔：1分钟、5分钟、15分钟

## 数据一致性规则

### 与 ThingsBoard 的一致性
1. **告警状态同步**
   - 告警管理系统的状态与 ThingsBoard 保持一致
   - 定期同步 ThingsBoard 的告警状态

2. **委托人同步**
   - 委托人信息同步到 ThingsBoard
   - 保持双向一致性

### 与外部系统的一致性
1. **设备信息同步**
   - 定期同步设备信息（名称、状态等）
   - 缓存设备信息，减少接口调用

2. **测站信息同步**
   - 定期同步测站信息
   - 监听测站-设备关联变化

## 性能约束

### 查询性能
- 告警列表查询：< 200ms
- 告警详情查询：< 100ms
- 统计查询：< 500ms

### 处理性能
- MQTT 消息消费延迟：< 1s
- 告警实例创建：< 500ms
- 通知发送：< 2s

### 并发约束
- 支持 100 并发告警创建
- 支持 1000 条/秒的 MQTT 消息消费
- 支持 50 并发 ThingsBoard API 调用

## 数据保留规则

### 告警实例
- 活跃告警：永久保留
- 已清除告警：保留 1 年
- 已处置告警：保留 1 年

### 通知记录
- 保留 6 个月
- 超过 6 个月的记录归档或删除

### 处理日志
- 保留 1 年
- 超过 1 年的记录归档

### 状态历史
- 保留 1 年
- 超过 1 年的记录归档

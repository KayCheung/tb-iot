# 实体类和 Repository 生成总结

**生成日期**：2026-03-05  
**作者**：zhangkai  
**任务**：Task 1.3 - 实体类和 Repository 创建

---

## ✅ 已完成的工作

### 1. 实体类（14个）

所有实体类位于：`alarm-server/src/main/java/club/g3d/iot/alarm/entity/`

| 序号 | 实体类名 | 表名 | 说明 |
|------|---------|------|------|
| 1 | AlarmScheme | g3d_alarm_scheme | 告警方案 |
| 2 | AlarmSchemeStation | g3d_alarm_scheme_station | 告警方案测站关联 |
| 3 | AlarmSchemeMetricRule | g3d_alarm_scheme_metric_rule | 告警方案指标规则 |
| 4 | AlarmLevelCondition | g3d_alarm_level_condition | 告警级别条件 |
| 5 | AlarmSchemeDeviceRule | g3d_alarm_scheme_device_rule | 告警方案设备规则映射 |
| 6 | AlarmInstance | g3d_alarm_instance | 告警实例 |
| 7 | AlarmInstanceStation | g3d_alarm_instance_station | 告警实例测站关联 |
| 8 | AlarmStatusHistory | g3d_alarm_status_history | 告警状态历史 |
| 9 | AlarmHandleLog | g3d_alarm_handle_log | 告警处理日志 |
| 10 | NotifyRule | g3d_notify_rule | 通知规则 |
| 11 | NotifyTemplate | g3d_notify_template | 通知模板 |
| 12 | NotifyUserGroup | g3d_notify_user_group | 通知用户组 |
| 13 | NotifyUserGroupMember | g3d_notify_user_group_member | 通知用户组成员 |
| 14 | NotifyRecord | g3d_notify_record | 通知记录 |

### 2. Repository 接口（14个）

所有 Repository 接口位于：`alarm-server/src/main/java/club/g3d/iot/alarm/repository/`

| 序号 | Repository 名 | 说明 |
|------|--------------|------|
| 1 | AlarmSchemeRepository | 告警方案 Repository |
| 2 | AlarmSchemeStationRepository | 告警方案测站关联 Repository |
| 3 | AlarmSchemeMetricRuleRepository | 告警方案指标规则 Repository |
| 4 | AlarmLevelConditionRepository | 告警级别条件 Repository |
| 5 | AlarmSchemeDeviceRuleRepository | 告警方案设备规则映射 Repository |
| 6 | AlarmInstanceRepository | 告警实例 Repository |
| 7 | AlarmInstanceStationRepository | 告警实例测站关联 Repository |
| 8 | AlarmStatusHistoryRepository | 告警状态历史 Repository |
| 9 | AlarmHandleLogRepository | 告警处理日志 Repository |
| 10 | NotifyRuleRepository | 通知规则 Repository |
| 11 | NotifyTemplateRepository | 通知模板 Repository |
| 12 | NotifyUserGroupRepository | 通知用户组 Repository |
| 13 | NotifyUserGroupMemberRepository | 通知用户组成员 Repository |
| 14 | NotifyRecordRepository | 通知记录 Repository |

---

## 📋 代码特性

### 实体类特性

1. **JPA 注解**：
   - `@Entity` - 标识实体类
   - `@Table(name = "g3d_xxx")` - 指定表名（包含前缀）
   - `@Id` + `@GeneratedValue` - 主键自增
   - `@Column` - 列定义（名称、长度、约束）

2. **Lombok 注解**：
   - `@Data` - 自动生成 getter/setter/toString/equals/hashCode

3. **生命周期回调**：
   - `@PrePersist` - 插入前自动设置时间
   - `@PreUpdate` - 更新前自动设置时间

4. **JSON 字段处理**：
   - 使用 `@Type(JsonType.class)` 处理 JSONB 字段
   - 需要 Hypersistence Utils 依赖

5. **默认值设置**：
   - 所有字段都有默认值
   - 时间字段使用 `1970-01-01 00:00:00` 作为默认值

### Repository 特性

1. **继承 JpaRepository**：
   - 自动拥有基础 CRUD 方法
   - `save()`, `findById()`, `findAll()`, `delete()` 等

2. **继承 QuerydslPredicateExecutor**：
   - 支持 QueryDSL 类型安全查询
   - 可以使用 `Predicate` 进行复杂查询

3. **方法命名查询**：
   - Spring Data JPA 自动实现
   - 例如：`findBySchemeCode()`, `findByStatusAndDeleted()`

4. **@Query 注解**：
   - 自定义 JPQL 查询
   - 例如：统计查询、聚合查询

---

## 🎯 下一步工作

### Task 2.1：ThingsBoard 客户端（3h）
- 创建 ThingsBoard REST API 客户端
- 实现认证和 Token 管理
- 封装 CalculatedField API
- 封装 Alarm API

### Task 2.2：TBEL 脚本生成器（10h）⭐
- 设计 TBEL 生成器接口
- 实现启动规则生成逻辑
- 实现指标条件生成逻辑
- 实现告警级别判断逻辑

### Task 2.3：CalculatedField 同步服务（3h）
- 实现批量同步服务
- 查询测站关联的设备
- 调用 ThingsBoard API 创建 CalculatedField
- 处理同步失败的情况

---

## 📊 工时统计

| 任务 | 预估工时 | 实际工时 | 状态 |
|------|---------|---------|------|
| Task 1.1：数据库初始化 | 1h | 1h | ✅ 完成 |
| Task 1.2：项目框架搭建 | 2h | 0h | ✅ 已有框架 |
| Task 1.3：实体类和 Repository | 3h | 1h | ✅ 完成 |

**总计**：已完成 6h 中的 2h（实际），剩余 97h

---

## 🔍 验证方法

### 1. 编译项目
```bash
cd alarm-server
mvn clean compile
```

### 2. 运行测试
```bash
mvn test
```

### 3. 启动应用
```bash
mvn spring-boot:run
```

### 4. 检查 JPA 映射
启动应用后，Hibernate 会自动验证实体类与数据库表的映射关系。

---

## 📝 注意事项

1. **JSONB 字段**：
   - `AlarmScheme.enableRuleConfig` 使用 `@Type(JsonType.class)`
   - 需要确保 `hypersistence-utils-hibernate-63` 依赖已添加

2. **逻辑删除**：
   - `AlarmScheme` 有 `deleted` 字段
   - 需要在查询时手动过滤 `deleted = 0`
   - 或者使用 Hibernate 的 `@Where` 注解

3. **时间字段默认值**：
   - 使用 `1970-01-01 00:00:00` 表示未设置
   - 使用 `9999-12-31 23:59:59` 表示永久有效

4. **级联删除**：
   - Repository 中的 `deleteByXxx()` 方法需要添加 `@Transactional` 注解
   - 建议在 Service 层处理级联删除逻辑

---

## ✅ 检查清单

- [x] 14 个实体类已创建（对应数据库中的 14 张表）
- [x] 14 个 Repository 接口已创建
- [x] 所有实体类使用 JPA 注解
- [x] 所有字段有默认值
- [x] 所有时间字段有 @PrePersist/@PreUpdate
- [x] 所有 Repository 继承 JpaRepository 和 QuerydslPredicateExecutor
- [x] 作者统一为 zhangkai
- [x] 表名统一使用 g3d_ 前缀
- [x] 已删除不存在的 DataDictionary 实体类和 Repository

---

**完成时间**：2026-03-05  
**状态**：✅ Task 1.3 完成

# 表名前缀更新说明

**更新日期**：2026-03-05  
**变更内容**：所有数据库表名添加 `g3d_` 前缀

---

## 📋 变更说明

### 数据库表名
所有表名统一添加 `g3d_` 前缀，避免表名冲突。

**示例**：
- `alarm_scheme` → `g3d_alarm_scheme`
- `alarm_instance` → `g3d_alarm_instance`
- `alarm_scheme_station` → `g3d_alarm_scheme_station`

### Java 实体类名
实体类名不包含前缀，保持简洁。

**示例**：
- 数据库表：`g3d_alarm_scheme`
- 实体类：`AlarmScheme`

---

## ⚙️ MyBatis-Plus 配置

### 推荐方案：全局配置

在 `application.yml` 中配置：

```yaml
mybatis-plus:
  global-config:
    db-config:
      table-prefix: g3d_
```

这样所有实体类会自动添加 `g3d_` 前缀，无需在每个类上加 `@TableName` 注解。

### 实体类示例

```java
@Data
public class AlarmScheme {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String schemeCode;
    // ...
}
```

MyBatis-Plus 会自动将 `AlarmScheme` 映射到 `g3d_alarm_scheme` 表。

---

## 📝 已更新的文档

### 1. Steering 规范
- ✅ `.kiro/steering/database-standards.md`
  - 添加了表名前缀说明
  - 更新了表设计示例
  - 添加了 Java 实体类映射示例

- ✅ `.kiro/steering/coding-standards.md`
  - 添加了实体类与数据库表映射说明
  - 添加了 `@TableName` 注解示例

### 2. 配置文档
- ✅ `docs/MyBatis-Plus配置说明.md`（新建）
  - 详细的 MyBatis-Plus 配置说明
  - 全局表前缀配置
  - 实体类编写规范
  - 字段自动填充配置
  - 完整的使用示例

---

## 📊 表名对照表

| 原表名 | 新表名（带前缀） | 实体类名 |
|--------|----------------|---------|
| alarm_scheme | g3d_alarm_scheme | AlarmScheme |
| alarm_scheme_station | g3d_alarm_scheme_station | AlarmSchemeStation |
| alarm_scheme_metric_rule | g3d_alarm_scheme_metric_rule | AlarmSchemeMetricRule |
| alarm_level_condition | g3d_alarm_level_condition | AlarmLevelCondition |
| alarm_scheme_device_rule | g3d_alarm_scheme_device_rule | AlarmSchemeDeviceRule |
| alarm_instance | g3d_alarm_instance | AlarmInstance |
| alarm_instance_station | g3d_alarm_instance_station | AlarmInstanceStation |
| alarm_status_history | g3d_alarm_status_history | AlarmStatusHistory |
| alarm_handle_log | g3d_alarm_handle_log | AlarmHandleLog |
| notify_rule | g3d_notify_rule | NotifyRule |
| notify_template | g3d_notify_template | NotifyTemplate |
| notify_user_group | g3d_notify_user_group | NotifyUserGroup |
| notify_user_group_member | g3d_notify_user_group_member | NotifyUserGroupMember |
| notify_record | g3d_notify_record | NotifyRecord |
| data_dictionary | g3d_data_dictionary | DataDictionary |

---

## ✅ 开发时注意事项

### 1. 实体类创建
```java
// ✅ 正确：使用全局配置，无需 @TableName
@Data
public class AlarmScheme {
    @TableId(type = IdType.AUTO)
    private Long id;
    // ...
}

// ❌ 错误：不要在类名中包含前缀
public class G3dAlarmScheme { }
```

### 2. Mapper 接口
```java
// ✅ 正确：Mapper 接口名不包含前缀
@Mapper
public interface AlarmSchemeMapper extends BaseMapper<AlarmScheme> {
}
```

### 3. SQL 语句
如果需要手写 SQL，记得使用带前缀的表名：

```xml
<!-- Mapper XML -->
<select id="customQuery" resultType="AlarmScheme">
    SELECT * FROM g3d_alarm_scheme WHERE status = 1
</select>
```

### 4. 索引和约束
索引名称不需要包含表前缀：

```sql
-- ✅ 正确
CREATE INDEX idx_alarm_scheme_status ON g3d_alarm_scheme(status);

-- ❌ 不推荐
CREATE INDEX idx_g3d_alarm_scheme_status ON g3d_alarm_scheme(status);
```

---

## 🔍 验证方法

### 1. 启动应用后检查日志
MyBatis-Plus 会打印实际执行的 SQL：

```sql
==>  Preparing: SELECT * FROM g3d_alarm_scheme WHERE id = ?
==> Parameters: 1(Long)
<==      Total: 1
```

确认表名包含 `g3d_` 前缀。

### 2. 单元测试
```java
@Test
public void testTablePrefix() {
    AlarmScheme scheme = new AlarmScheme();
    scheme.setSchemeCode("TEST_001");
    scheme.setSchemeName("测试方案");
    
    // 插入数据
    alarmSchemeMapper.insert(scheme);
    
    // 查询数据
    AlarmScheme result = alarmSchemeMapper.selectById(scheme.getId());
    assertNotNull(result);
}
```

---

## 📚 相关文档

1. `docs/MyBatis-Plus配置说明.md` - 详细配置说明
2. `.kiro/steering/database-standards.md` - 数据库设计规范
3. `.kiro/steering/coding-standards.md` - 编码规范
4. `db/init-schema.sql` - 数据库初始化脚本（已包含 g3d_ 前缀）

---

**更新完成**：所有相关文档已更新，可以开始开发了！

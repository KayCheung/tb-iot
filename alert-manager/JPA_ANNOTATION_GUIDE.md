# JPA 注解 + MyBatis-Plus 使用指南

**更新日期**：2026-03-05  
**技术选型**：MyBatis-Plus + JPA 标准注解（`jakarta.persistence`）

---

## 📋 技术选型说明

### 为什么使用 JPA 注解？

1. **标准化**：JPA 是 Java 持久化标准规范，不绑定特定框架
2. **兼容性**：MyBatis-Plus 3.x+ 完全支持 JPA 注解
3. **灵活性**：将来可以切换到 Spring Data JPA 或混合使用
4. **可移植性**：代码更容易迁移到其他项目
5. **IDE 支持**：更好的代码提示和重构支持

### MyBatis-Plus 对 JPA 注解的支持

MyBatis-Plus 会自动识别以下 JPA 注解：

| JPA 注解 | 作用 | MyBatis-Plus 支持 |
|---------|------|------------------|
| `@Entity` | 标识实体类 | ✅ 完全支持 |
| `@Table(name = "...")` | 指定表名 | ✅ 完全支持 |
| `@Id` | 标识主键 | ✅ 完全支持 |
| `@GeneratedValue` | 主键生成策略 | ✅ 完全支持 |
| `@Column(name = "...")` | 指定列名 | ✅ 完全支持 |
| `@Transient` | 忽略字段 | ✅ 完全支持 |
| `@PrePersist` | 插入前回调 | ✅ 完全支持 |
| `@PreUpdate` | 更新前回调 | ✅ 完全支持 |

---

## 🎯 实体类编写规范

### 完整示例

```java
package com.example.iot.alarm.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 告警方案实体类
 */
@Data
@Entity
@Table(name = "g3d_alarm_scheme")
public class AlarmScheme {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "scheme_code", nullable = false, length = 50, unique = true)
    private String schemeCode;
    
    @Column(name = "scheme_name", nullable = false, length = 100)
    private String schemeName;
    
    @Column(name = "station_type_id", nullable = false)
    private Long stationTypeId;
    
    @Column(name = "alarm_message", nullable = false, length = 500)
    private String alarmMessage;
    
    @Column(name = "enable_rule_type", nullable = false, length = 20)
    private String enableRuleType;
    
    @Column(name = "enable_rule_config", nullable = false, columnDefinition = "jsonb")
    private String enableRuleConfig; // JSON 字符串
    
    @Column(name = "device_count", nullable = false)
    private Integer deviceCount = 0;
    
    @Column(name = "status", nullable = false)
    private Integer status = 1;
    
    @Column(name = "created_by", nullable = false, updatable = false)
    private Long createdBy = 0L;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @Column(name = "updated_by", nullable = false)
    private Long updatedBy = 0L;
    
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
    
    @Column(name = "deleted", nullable = false)
    private Integer deleted = 0;
    
    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        if (updatedAt == null) updatedAt = now;
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
```

---

## 📝 注解详解

### @Entity
```java
@Entity
public class AlarmScheme { }
```
- 标识这是一个 JPA 实体类
- MyBatis-Plus 会识别并处理

### @Table
```java
@Table(name = "g3d_alarm_scheme")
```
- 指定数据库表名
- 包含 `g3d_` 前缀

### @Id
```java
@Id
private Long id;
```
- 标识主键字段
- MyBatis-Plus 会识别为主键

### @GeneratedValue
```java
@GeneratedValue(strategy = GenerationType.IDENTITY)
```
- 主键生成策略
- `IDENTITY`：数据库自增（PostgreSQL SERIAL）
- `AUTO`：自动选择
- `SEQUENCE`：使用序列

### @Column
```java
@Column(name = "scheme_code", nullable = false, length = 50, unique = true)
```
- `name`：数据库列名
- `nullable`：是否允许为空
- `length`：字符串长度
- `unique`：是否唯一
- `updatable`：是否可更新（false 表示只能插入，不能更新）
- `columnDefinition`：列定义（如 `jsonb`）

### @Transient
```java
@Transient
private String tempField;
```
- 标识字段不映射到数据库
- MyBatis-Plus 会忽略此字段

### @PrePersist / @PreUpdate
```java
@PrePersist
protected void onCreate() {
    createdAt = LocalDateTime.now();
}

@PreUpdate
protected void onUpdate() {
    updatedAt = LocalDateTime.now();
}
```
- JPA 生命周期回调
- MyBatis-Plus 会自动调用
- 用于自动设置时间戳

---

## ⚙️ MyBatis-Plus 配置

### application.yml

```yaml
spring:
  datasource:
    driver-class-name: org.postgresql.Driver
    url: jdbc:postgresql://localhost:5432/iot_alarm
    username: postgres
    password: your_password

mybatis-plus:
  global-config:
    db-config:
      # 主键类型：自增
      id-type: auto
      # 逻辑删除
      logic-delete-field: deleted
      logic-delete-value: 1
      logic-not-delete-value: 0
  
  configuration:
    # 驼峰转下划线
    map-underscore-to-camel-case: true
    # 日志（开发环境）
    log-impl: org.apache.ibatis.logging.stdout.StdOutImpl
  
  # Mapper XML 文件位置
  mapper-locations: classpath*:mapper/**/*.xml
  
  # 类型别名包
  type-aliases-package: com.example.iot.alarm.entity
```

**注意**：
- 不需要配置 `table-prefix`，因为使用 `@Table(name = "...")` 直接指定表名
- MyBatis-Plus 会自动识别 JPA 注解

---

## 🔧 Mapper 接口

```java
package com.example.iot.alarm.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.example.iot.alarm.entity.AlarmScheme;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface AlarmSchemeMapper extends BaseMapper<AlarmScheme> {
    // 继承 BaseMapper，自动拥有 CRUD 方法
    // MyBatis-Plus 会自动识别 JPA 注解
}
```

---

## 💡 使用示例

### Service 层

```java
@Service
public class AlarmSchemeServiceImpl implements AlarmSchemeService {
    
    @Autowired
    private AlarmSchemeMapper alarmSchemeMapper;
    
    @Override
    public void createScheme(AlarmScheme scheme) {
        // 插入数据
        // @PrePersist 会自动设置 createdAt 和 updatedAt
        alarmSchemeMapper.insert(scheme);
    }
    
    @Override
    public void updateScheme(AlarmScheme scheme) {
        // 更新数据
        // @PreUpdate 会自动更新 updatedAt
        alarmSchemeMapper.updateById(scheme);
    }
    
    @Override
    public AlarmScheme getById(Long id) {
        // 查询数据
        // 自动过滤 deleted=1 的记录（逻辑删除）
        return alarmSchemeMapper.selectById(id);
    }
    
    @Override
    public List<AlarmScheme> listByStationType(Long stationTypeId) {
        // 条件查询
        return alarmSchemeMapper.selectList(
            new LambdaQueryWrapper<AlarmScheme>()
                .eq(AlarmScheme::getStationTypeId, stationTypeId)
                .eq(AlarmScheme::getStatus, 1)
                .orderByDesc(AlarmScheme::getCreatedAt)
        );
    }
    
    @Override
    public void deleteScheme(Long id) {
        // 逻辑删除
        // 自动设置 deleted=1
        alarmSchemeMapper.deleteById(id);
    }
}
```

---

## 🎨 JSON 字段处理

### 方案 1：存储为字符串（推荐）

```java
@Column(name = "enable_rule_config", columnDefinition = "jsonb")
private String enableRuleConfig;

// 使用时手动序列化/反序列化
public void setEnableRuleConfigMap(Map<String, Object> config) {
    this.enableRuleConfig = JSON.toJSONString(config);
}

public Map<String, Object> getEnableRuleConfigMap() {
    return JSON.parseObject(enableRuleConfig, new TypeReference<Map<String, Object>>() {});
}
```

### 方案 2：使用 JPA AttributeConverter

```java
@Converter
public class JsonConverter implements AttributeConverter<Map<String, Object>, String> {
    
    @Override
    public String convertToDatabaseColumn(Map<String, Object> attribute) {
        return JSON.toJSONString(attribute);
    }
    
    @Override
    public Map<String, Object> convertToEntityAttribute(String dbData) {
        return JSON.parseObject(dbData, new TypeReference<Map<String, Object>>() {});
    }
}

// 实体类中使用
@Column(name = "enable_rule_config", columnDefinition = "jsonb")
@Convert(converter = JsonConverter.class)
private Map<String, Object> enableRuleConfig;
```

---

## ⚠️ 注意事项

### 1. 不要混用注解
```java
// ❌ 错误：混用 JPA 和 MyBatis-Plus 注解
@Entity
@TableName("g3d_alarm_scheme") // MyBatis-Plus 注解
public class AlarmScheme { }

// ✅ 正确：只使用 JPA 注解
@Entity
@Table(name = "g3d_alarm_scheme") // JPA 注解
public class AlarmScheme { }
```

### 2. 字段名映射
```java
// ✅ 推荐：显式指定列名
@Column(name = "scheme_code")
private String schemeCode;

// ⚠️ 可以省略，但不推荐
// MyBatis-Plus 会自动将 schemeCode 转换为 scheme_code
private String schemeCode;
```

### 3. 逻辑删除
```java
// 使用 MyBatis-Plus 的逻辑删除配置
@Column(name = "deleted")
private Integer deleted = 0;

// 配置文件中设置
mybatis-plus:
  global-config:
    db-config:
      logic-delete-field: deleted
      logic-delete-value: 1
      logic-not-delete-value: 0
```

### 4. 主键生成策略
```java
// PostgreSQL 使用 IDENTITY
@GeneratedValue(strategy = GenerationType.IDENTITY)

// 或者使用 SEQUENCE
@GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "alarm_scheme_seq")
@SequenceGenerator(name = "alarm_scheme_seq", sequenceName = "g3d_alarm_scheme_id_seq")
```

---

## 📚 相关文档

1. `docs/MyBatis-Plus配置说明.md` - 详细配置说明
2. `.kiro/steering/database-standards.md` - 数据库设计规范
3. `.kiro/steering/coding-standards.md` - 编码规范
4. `TABLE_PREFIX_UPDATE.md` - 表名前缀说明

---

## ✅ 总结

- ✅ 使用 JPA 标准注解（`jakarta.persistence`）
- ✅ MyBatis-Plus 完全支持 JPA 注解
- ✅ 不需要混用 MyBatis-Plus 注解
- ✅ 使用 `@Table(name = "g3d_xxx")` 指定表名
- ✅ 使用 `@Column(name = "xxx")` 指定列名
- ✅ 使用 `@PrePersist` / `@PreUpdate` 自动设置时间
- ✅ 代码更标准、更通用、更易维护

---

**创建日期**：2026-03-05  
**版本**：V1.0

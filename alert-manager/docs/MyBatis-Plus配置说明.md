# MyBatis-Plus 配置说明（使用 JPA 注解）

## 技术选型说明

本项目使用 **MyBatis-Plus** 作为持久层框架，但实体类使用 **JPA 标准注解**（`jakarta.persistence`）。

### 为什么这样做？

1. **标准化**：JPA 注解是 Java 持久化标准，不绑定特定框架
2. **兼容性**：MyBatis-Plus 3.x+ 完全支持 JPA 注解
3. **灵活性**：将来可以切换到 Spring Data JPA 或混合使用
4. **可移植性**：代码更容易迁移到其他项目

### MyBatis-Plus 对 JPA 注解的支持

MyBatis-Plus 会自动识别以下 JPA 注解：
- `@Entity` - 标识实体类
- `@Table(name = "table_name")` - 指定表名
- `@Id` - 标识主键
- `@GeneratedValue` - 主键生成策略
- `@Column(name = "column_name")` - 指定列名
- `@Transient` - 忽略字段

---

## 表名前缀配置

### 问题说明
- **数据库表名**：使用 `g3d_` 前缀（例如：`g3d_alarm_scheme`）
- **Java 实体类名**：不包含前缀（例如：`AlarmScheme`）
- **注解选择**：使用 JPA 标准注解（`jakarta.persistence`）

### 解决方案

#### 方案 1：使用 JPA @Table 注解（推荐）

直接在实体类上使用 `@Table(name = "g3d_alarm_scheme")` 指定表名：

```java
import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
@Table(name = "g3d_alarm_scheme")
public class AlarmScheme {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "scheme_code")
    private String schemeCode;
    
    // ... 其他字段
}
```

**优点**：
- 使用标准 JPA 注解，更通用
- MyBatis-Plus 完全支持
- 代码清晰，一目了然

**MyBatis-Plus 配置**：
```yaml
mybatis-plus:
  global-config:
    db-config:
      # 主键类型
      id-type: auto
      # 逻辑删除字段
      logic-delete-field: deleted
      logic-delete-value: 1
      logic-not-delete-value: 0
  configuration:
    # 驼峰转下划线
    map-underscore-to-camel-case: true
```

---

#### 方案 2：全局配置 + JPA 注解

如果不想在每个类上写表名，可以配置全局前缀：

```yaml
mybatis-plus:
  global-config:
    db-config:
      # 表名前缀（可选）
      table-prefix: g3d_
```

然后实体类可以简化：

```java
@Data
@Entity
public class AlarmScheme {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "scheme_code")
    private String schemeCode;
}
```

MyBatis-Plus 会自动将 `AlarmScheme` 映射到 `g3d_alarm_scheme`。

**注意**：如果同时使用 `@Table(name = "...")` 和 `table-prefix`，`@Table` 的优先级更高。

---

## 完整配置示例

### application.yml

```yaml
spring:
  datasource:
    driver-class-name: org.postgresql.Driver
    url: jdbc:postgresql://localhost:5432/iot_alarm
    username: postgres
    password: your_password
    hikari:
      minimum-idle: 5
      maximum-pool-size: 20
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000

mybatis-plus:
  # 全局配置
  global-config:
    db-config:
      # 表名前缀
      table-prefix: g3d_
      # 主键类型：自增
      id-type: auto
      # 逻辑删除
      logic-delete-field: deleted
      logic-delete-value: 1
      logic-not-delete-value: 0
  
  # MyBatis 配置
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

---

## 实体类编写规范（使用 JPA 注解）

### 基础实体类

```java
package com.example.iot.alarm.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 告警方案实体类
 * 
 * @author 作者名
 * @since 2026-03-05
 */
@Data
@Entity
@Table(name = "g3d_alarm_scheme")
public class AlarmScheme {
    
    /**
     * 主键ID
     */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    /**
     * 告警方案编码（唯一）
     */
    @Column(name = "scheme_code", nullable = false, length = 50, unique = true)
    private String schemeCode;
    
    /**
     * 告警方案名称
     */
    @Column(name = "scheme_name", nullable = false, length = 100)
    private String schemeName;
    
    /**
     * 测站类型ID
     */
    @Column(name = "station_type_id", nullable = false)
    private Long stationTypeId;
    
    /**
     * 告警提示语
     */
    @Column(name = "alarm_message", nullable = false, length = 500)
    private String alarmMessage;
    
    /**
     * 启动规则类型：ALWAYS-始终启动,SCHEDULED-定时启动,CUSTOM-自定义时间,CONDITION-工况启动
     */
    @Column(name = "enable_rule_type", nullable = false, length = 20)
    private String enableRuleType;
    
    /**
     * 启动规则配置（JSONB）
     * 存储为 JSON 字符串，使用时需要序列化/反序列化
     */
    @Column(name = "enable_rule_config", nullable = false, columnDefinition = "jsonb")
    private String enableRuleConfig;
    
    /**
     * 关联设备数量（冗余字段）
     */
    @Column(name = "device_count", nullable = false)
    private Integer deviceCount = 0;
    
    /**
     * 状态：0-禁用,1-启用
     */
    @Column(name = "status", nullable = false)
    private Integer status = 1;
    
    /**
     * 创建人ID，0表示系统
     */
    @Column(name = "created_by", nullable = false, updatable = false)
    private Long createdBy = 0L;
    
    /**
     * 创建时间
     */
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    /**
     * 更新人ID，0表示系统
     */
    @Column(name = "updated_by", nullable = false)
    private Long updatedBy = 0L;
    
    /**
     * 更新时间
     */
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
    
    /**
     * 逻辑删除：0-未删除,1-已删除
     */
    @Column(name = "deleted", nullable = false)
    private Integer deleted = 0;
    
    /**
     * 插入前自动设置时间
     */
    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
    }
    
    /**
     * 更新前自动设置时间
     */
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
```

### 注解说明

#### @Entity
标识这是一个 JPA 实体类，MyBatis-Plus 会识别。

#### @Table(name = "g3d_alarm_scheme")
指定数据库表名，包含 `g3d_` 前缀。

#### @Id
标识主键字段。

#### @GeneratedValue(strategy = GenerationType.IDENTITY)
主键生成策略：
- `IDENTITY`：数据库自增（PostgreSQL 使用 SERIAL）
- `AUTO`：自动选择策略
- `SEQUENCE`：使用序列（PostgreSQL 推荐）

#### @Column
指定列名和约束：
- `name`：数据库列名
- `nullable`：是否允许为空
- `length`：字符串长度
- `unique`：是否唯一
- `updatable`：是否可更新
- `columnDefinition`：列定义（如 `jsonb`）

#### @PrePersist / @PreUpdate
JPA 生命周期回调：
- `@PrePersist`：插入前执行
- `@PreUpdate`：更新前执行
- 用于自动设置时间戳

#### @Transient
标识字段不映射到数据库：
```java
@Transient
private String tempField; // 不会映射到数据库
```

---

## 字段自动填充配置

### 方案 1：使用 JPA 生命周期回调（推荐）

直接在实体类中使用 `@PrePersist` 和 `@PreUpdate`：

```java
@Data
@Entity
@Table(name = "g3d_alarm_scheme")
public class AlarmScheme {
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
    
    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        createdAt = now;
        updatedAt = now;
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
```

**优点**：
- 使用 JPA 标准特性
- 不需要额外配置
- MyBatis-Plus 会自动调用

---

### 方案 2：使用 MyBatis-Plus MetaObjectHandler

如果需要更复杂的逻辑（如从上下文获取用户ID），可以使用 MyBatis-Plus 的 `MetaObjectHandler`：

```java
package com.example.iot.alarm.config;

import com.baomidou.mybatisplus.core.handlers.MetaObjectHandler;
import org.apache.ibatis.reflection.MetaObject;
import org.springframework.stereotype.Component;
import java.time.LocalDateTime;

@Component
public class MyMetaObjectHandler implements MetaObjectHandler {
    
    @Override
    public void insertFill(MetaObject metaObject) {
        // 创建时间
        this.strictInsertFill(metaObject, "createdAt", LocalDateTime.class, LocalDateTime.now());
        // 更新时间
        this.strictInsertFill(metaObject, "updatedAt", LocalDateTime.class, LocalDateTime.now());
        // 创建人（从上下文获取，这里默认0）
        this.strictInsertFill(metaObject, "createdBy", Long.class, getCurrentUserId());
        // 更新人
        this.strictInsertFill(metaObject, "updatedBy", Long.class, getCurrentUserId());
    }
    
    @Override
    public void updateFill(MetaObject metaObject) {
        // 更新时间
        this.strictUpdateFill(metaObject, "updatedAt", LocalDateTime.class, LocalDateTime.now());
        // 更新人（从上下文获取，这里默认0）
        this.strictUpdateFill(metaObject, "updatedBy", Long.class, getCurrentUserId());
    }
    
    private Long getCurrentUserId() {
        // TODO: 从 SecurityContext 或 ThreadLocal 获取当前用户ID
        return 0L;
    }
}
```

然后在实体类字段上添加 `@TableField` 注解（MyBatis-Plus 注解）：

```java
import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.TableField;

@Column(name = "created_at")
@TableField(fill = FieldFill.INSERT)
private LocalDateTime createdAt;

@Column(name = "updated_at")
@TableField(fill = FieldFill.INSERT_UPDATE)
private LocalDateTime updatedAt;
```

**注意**：这种方式混合使用了 JPA 和 MyBatis-Plus 注解。

---

## Mapper 接口

MyBatis-Plus 的 Mapper 接口与 JPA 注解完全兼容：

```java
package com.example.iot.alarm.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.example.iot.alarm.entity.AlarmScheme;
import org.apache.ibatis.annotations.Mapper;

/**
 * 告警方案 Mapper 接口
 * 
 * @author 作者名
 * @since 2026-03-05
 */
@Mapper
public interface AlarmSchemeMapper extends BaseMapper<AlarmScheme> {
    // 继承 BaseMapper 后，自动拥有 CRUD 方法
    // MyBatis-Plus 会自动识别实体类上的 JPA 注解
    
    // 可以添加自定义方法
}
```

**说明**：
- MyBatis-Plus 会自动读取 `AlarmScheme` 类上的 `@Table(name = "g3d_alarm_scheme")`
- 会自动读取字段上的 `@Column(name = "...")`
- 生成的 SQL 会使用正确的表名和列名

---

## 使用示例

```java
@Service
public class AlarmSchemeServiceImpl implements AlarmSchemeService {
    
    @Autowired
    private AlarmSchemeMapper alarmSchemeMapper;
    
    @Override
    public void createScheme(AlarmScheme scheme) {
        // 插入数据，自动添加表前缀 g3d_
        alarmSchemeMapper.insert(scheme);
    }
    
    @Override
    public AlarmScheme getById(Long id) {
        // 查询数据
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
}
```

---

## 注意事项

1. **表名前缀**：
   - 使用全局配置 `table-prefix: g3d_`
   - 所有实体类自动添加前缀
   - 无需在每个类上加 `@TableName`

2. **字段映射**：
   - 驼峰命名自动转下划线：`schemeCode` → `scheme_code`
   - 配置：`map-underscore-to-camel-case: true`

3. **逻辑删除**：
   - 配置 `logic-delete-field: deleted`
   - 查询时自动过滤 `deleted=1` 的记录
   - 删除时自动更新 `deleted=1`

4. **JSONB 字段**：
   - 使用 `@TableField(typeHandler = JacksonTypeHandler.class)`
   - 自动序列化/反序列化 JSON

5. **时间字段**：
   - 使用 `LocalDateTime` 类型
   - 配置自动填充 `@TableField(fill = FieldFill.INSERT)`

---

**创建日期**：2026-03-05  
**版本**：V1.0

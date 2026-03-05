# Spring Data JPA 配置说明

**项目技术栈**：Spring Data JPA + PostgreSQL + QueryDSL

---

## 📋 技术栈说明

本项目使用 **Spring Data JPA** 作为持久层框架，配合以下技术：

- **Spring Data JPA**：简化数据访问层
- **Hibernate**：JPA 实现
- **PostgreSQL**：数据库
- **QueryDSL**：类型安全查询
- **Hypersistence Utils**：JPA 性能优化
- **MapStruct**：对象映射

---

## 🎯 实体类编写规范

### 完整示例

```java
package club.g3d.iot.alarm.entity;

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
    
    // 使用 Hypersistence Utils 的 JsonType
    @Type(JsonType.class)
    @Column(name = "enable_rule_config", nullable = false, columnDefinition = "jsonb")
    private Map<String, Object> enableRuleConfig;
    
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

## 📦 Repository 接口

### 基础 Repository

```java
package club.g3d.iot.alarm.repository;

import club.g3d.iot.alarm.entity.AlarmScheme;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.querydsl.QuerydslPredicateExecutor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 告警方案 Repository
 */
@Repository
public interface AlarmSchemeRepository extends 
        JpaRepository<AlarmScheme, Long>,
        QuerydslPredicateExecutor<AlarmScheme> {
    
    // 方法命名查询
    Optional<AlarmScheme> findBySchemeCode(String schemeCode);
    
    List<AlarmScheme> findByStationTypeIdAndDeletedOrderByCreatedAtDesc(
        Long stationTypeId, Integer deleted
    );
    
    // 使用 @Query 注解
    @Query("SELECT a FROM AlarmScheme a WHERE a.status = :status AND a.deleted = 0")
    List<AlarmScheme> findActiveSchemes(@Param("status") Integer status);
}
```

### QueryDSL 查询示例

```java
@Service
public class AlarmSchemeService {
    
    @Autowired
    private AlarmSchemeRepository alarmSchemeRepository;
    
    public List<AlarmScheme> querySchemes(AlarmSchemeQuery query) {
        QAlarmScheme qScheme = QAlarmScheme.alarmScheme;
        
        BooleanBuilder builder = new BooleanBuilder();
        
        // 动态条件
        if (query.getStationTypeId() != null) {
            builder.and(qScheme.stationTypeId.eq(query.getStationTypeId()));
        }
        
        if (StringUtils.hasText(query.getSchemeName())) {
            builder.and(qScheme.schemeName.contains(query.getSchemeName()));
        }
        
        builder.and(qScheme.deleted.eq(0));
        
        // 执行查询
        return (List<AlarmScheme>) alarmSchemeRepository.findAll(builder);
    }
}
```

---

## ⚙️ application.yml 配置

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
  
  jpa:
    database-platform: org.hibernate.dialect.PostgreSQLDialect
    hibernate:
      ddl-auto: validate  # 生产环境使用 validate
    properties:
      hibernate:
        format_sql: true
        use_sql_comments: true
        jdbc:
          batch_size: 20
        order_inserts: true
        order_updates: true
    show-sql: true  # 开发环境显示 SQL
```

---

## 🔧 JSON 字段处理（Hypersistence Utils）

### 依赖配置

```xml
<dependency>
    <groupId>io.hypersistence</groupId>
    <artifactId>hypersistence-utils-hibernate-63</artifactId>
    <version>3.7.0</version>
</dependency>
```

### 实体类使用

```java
import io.hypersistence.utils.hibernate.type.json.JsonType;
import org.hibernate.annotations.Type;

@Entity
@Table(name = "g3d_alarm_scheme")
public class AlarmScheme {
    
    // JSONB 字段
    @Type(JsonType.class)
    @Column(name = "enable_rule_config", columnDefinition = "jsonb")
    private Map<String, Object> enableRuleConfig;
    
    // 或者使用自定义类型
    @Type(JsonType.class)
    @Column(name = "enable_rule_config", columnDefinition = "jsonb")
    private EnableRuleConfig enableRuleConfig;
}
```

---

## 📊 Service 层示例

```java
@Service
@Transactional(readOnly = true)
public class AlarmSchemeService {
    
    @Autowired
    private AlarmSchemeRepository alarmSchemeRepository;
    
    @Transactional
    public AlarmScheme createScheme(AlarmScheme scheme) {
        // @PrePersist 会自动设置时间
        return alarmSchemeRepository.save(scheme);
    }
    
    @Transactional
    public AlarmScheme updateScheme(Long id, AlarmScheme scheme) {
        AlarmScheme existing = alarmSchemeRepository.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("方案不存在"));
        
        // 更新字段
        existing.setSchemeName(scheme.getSchemeName());
        existing.setAlarmMessage(scheme.getAlarmMessage());
        // ... 其他字段
        
        // @PreUpdate 会自动更新时间
        return alarmSchemeRepository.save(existing);
    }
    
    public AlarmScheme getById(Long id) {
        return alarmSchemeRepository.findById(id)
            .filter(s -> s.getDeleted() == 0)
            .orElseThrow(() -> new EntityNotFoundException("方案不存在"));
    }
    
    public List<AlarmScheme> listByStationType(Long stationTypeId) {
        return alarmSchemeRepository
            .findByStationTypeIdAndDeletedOrderByCreatedAtDesc(stationTypeId, 0);
    }
    
    @Transactional
    public void deleteScheme(Long id) {
        AlarmScheme scheme = getById(id);
        scheme.setDeleted(1);
        alarmSchemeRepository.save(scheme);
    }
}
```

---

## 🎨 MapStruct 对象映射

### Mapper 接口

```java
@Mapper(componentModel = "spring")
public interface AlarmSchemeMapper {
    
    AlarmSchemeDTO toDTO(AlarmScheme entity);
    
    AlarmScheme toEntity(AlarmSchemeDTO dto);
    
    List<AlarmSchemeDTO> toDTOList(List<AlarmScheme> entities);
    
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    void updateEntity(AlarmSchemeDTO dto, @MappingTarget AlarmScheme entity);
}
```

---

## ✅ 总结

- ✅ 使用 Spring Data JPA
- ✅ 实体类使用 JPA 注解
- ✅ Repository 继承 JpaRepository
- ✅ 支持 QueryDSL 类型安全查询
- ✅ 使用 Hypersistence Utils 处理 JSONB
- ✅ 使用 MapStruct 进行对象映射
- ✅ 支持方法命名查询和 @Query 注解

---

**创建日期**：2026-03-05  
**版本**：V1.0

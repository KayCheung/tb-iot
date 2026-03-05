---
description: Java 编码规范和项目开发标准
inclusion: auto
---

# 编码规范

## 基本原则

遵循《阿里巴巴 Java 开发手册》，以下是项目特定的补充规范。

## 命名规范

### 包命名
```
com.example.iot.alarm
├── controller          # 控制器层
├── service             # 服务层
├── mapper              # MyBatis-Plus Mapper
├── entity              # 实体类
├── dto                 # 数据传输对象
├── enums               # 枚举类
├── config              # 配置类
├── consumer            # Kafka消费者
├── producer            # Kafka生产者
├── handler             # 处理器
├── exception           # 异常类
└── util                # 工具类
```

### 类命名
- **Controller**: 以 `Controller` 结尾，如 `AlarmController`
- **Service**: 以 `Service` 结尾，如 `AlarmService`
- **ServiceImpl**: 以 `ServiceImpl` 结尾，如 `AlarmServiceImpl`
- **Mapper**: 以 `Mapper` 结尾，如 `AlarmInstanceMapper`
- **Entity**: 使用名词，如 `AlarmInstance`（不包含表名前缀 `g3d_`）
- **DTO**: 以用途结尾，如 `AlarmQueryRequest`、`AlarmDetailResponse`
- **Enum**: 以 `Enum` 结尾，如 `AlarmLevelEnum`

### 实体类与数据库表映射
```java
import jakarta.persistence.*;
import lombok.Data;

// 数据库表名：g3d_alarm_scheme
// Java 实体类名：AlarmScheme
@Data
@Entity
@Table(name = "g3d_alarm_scheme")
public class AlarmScheme {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "scheme_code", nullable = false, length = 50)
    private String schemeCode;
    
    // 其他字段...
}
```

### 方法命名
- **查询单个**: `get` 开头，如 `getAlarmDetail`
- **查询列表**: `list` 或 `query` 开头，如 `listAlarms`、`queryAlarms`
- **分页查询**: `page` 或 `query` 开头，如 `pageAlarms`
- **新增**: `create` 或 `add` 开头，如 `createScheme`
- **修改**: `update` 开头，如 `updateScheme`
- **删除**: `delete` 或 `remove` 开头，如 `deleteScheme`
- **判断**: `check` 或 `is` 开头，如 `checkEnableRule`、`isValid`

### 变量命名
- 使用驼峰命名法
- 布尔类型以 `is`、`has`、`can` 开头
- 集合类型以复数形式命名，如 `alarms`、`schemes`

## 注释规范

### 类注释
```java
/**
 * 告警实例服务实现类
 * 
 * @author 作者名
 * @since 2026-03-03
 */
@Service
public class AlarmServiceImpl implements AlarmService {
}
```

### 方法注释
```java
/**
 * 分页查询告警列表
 * 
 * @param request 查询请求参数
 * @return 分页结果
 */
@Override
public IPage<AlarmListResponse> queryAlarms(AlarmQueryRequest request) {
}
```

### 复杂业务逻辑注释
```java
// 1. 查询告警方案设备规则映射
// 2. 反查告警方案详情
// 3. 查询设备关联的测站
// 4. 创建告警实例
```

## 代码结构规范

### Controller 层
- 只负责参数校验和调用 Service
- 使用 `@Valid` 进行参数校验
- 统一返回 `Result<T>` 格式

```java
@RestController
@RequestMapping("/api/v1/alarms")
public class AlarmController {
    
    @Autowired
    private AlarmService alarmService;
    
    @GetMapping
    public Result<IPage<AlarmListResponse>> queryAlarms(@Valid AlarmQueryRequest request) {
        IPage<AlarmListResponse> result = alarmService.queryAlarms(request);
        return Result.success(result);
    }
}
```

### Service 层
- 接口定义业务方法
- 实现类包含具体业务逻辑
- 使用 `@Transactional` 控制事务

```java
public interface AlarmService {
    IPage<AlarmListResponse> queryAlarms(AlarmQueryRequest request);
}

@Service
public class AlarmServiceImpl implements AlarmService {
    
    @Override
    @Transactional(rollbackFor = Exception.class)
    public IPage<AlarmListResponse> queryAlarms(AlarmQueryRequest request) {
        // 业务逻辑
    }
}
```

### Mapper 层
- 继承 `BaseMapper<T>`
- 复杂查询使用 XML 配置

```java
@Mapper
public interface AlarmInstanceMapper extends BaseMapper<AlarmInstance> {
    // 自定义方法
}
```

## 异常处理规范

### 自定义异常
```java
public class AlarmException extends RuntimeException {
    private final String code;
    
    public AlarmException(String code, String message) {
        super(message);
        this.code = code;
    }
}
```

### 全局异常处理
```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(AlarmException.class)
    public Result<Void> handleAlarmException(AlarmException e) {
        return Result.fail(e.getCode(), e.getMessage());
    }
}
```

## 日志规范

### 日志级别
- **ERROR**: 系统错误、异常
- **WARN**: 警告信息、业务异常
- **INFO**: 关键业务流程、状态变更
- **DEBUG**: 调试信息、详细日志

### 日志格式
```java
log.info("创建告警方案, schemeId={}, schemeName={}", schemeId, schemeName);
log.error("同步ThingsBoard告警规则失败, deviceId={}", deviceId, e);
```

## 常量定义规范

### 使用枚举代替魔法值
```java
// 不推荐
if ("ACTIVE".equals(status)) {
}

// 推荐
if (AlarmStatusEnum.ACTIVE.getCode().equals(status)) {
}
```

### 常量类
```java
public class AlarmConstants {
    public static final String CACHE_KEY_PREFIX = "alarm:scheme:";
    public static final long CACHE_EXPIRE_SECONDS = 3600L;
}
```

## 工具类规范

- 工具类使用 `final` 修饰，不允许实例化
- 方法使用 `static` 修饰
- 私有构造函数

```java
public final class AlarmUtil {
    
    private AlarmUtil() {
        throw new UnsupportedOperationException();
    }
    
    public static String generateTbAlarmType(String schemeCode, Long deviceId) {
        return schemeCode + "_" + deviceId;
    }
}
```

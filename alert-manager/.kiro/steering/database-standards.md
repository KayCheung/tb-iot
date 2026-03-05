---
description: PostgreSQL 数据库设计规范和最佳实践
inclusion: auto
---

# PostgreSQL 数据库设计规范

## 数据库类型

本项目使用 **PostgreSQL 14+** 作为数据库。

## 表命名约定

### 表名前缀
- **数据库表名**：统一使用 `g3d_` 前缀
  - 例如：`g3d_alarm_scheme`、`g3d_alarm_instance`
- **Java 实体类名**：不包含前缀
  - 例如：`AlarmScheme`、`AlarmInstance`
- **MyBatis-Plus 配置**：使用 `@TableName` 注解映射

### 示例
```java
@TableName("g3d_alarm_scheme")
public class AlarmScheme {
    // 实体类字段
}
```

## 核心设计原则

### 业务逻辑实现位置
- **所有业务逻辑必须在应用层（Java）实现**
- **禁止使用数据库视图（VIEW）**
- **禁止使用数据库触发器（TRIGGER）**
- **禁止使用数据库函数（FUNCTION）**
- **禁止使用存储过程（STORED PROCEDURE）**

### 原因说明
1. **可维护性**：业务逻辑集中在应用层，便于理解和维护
2. **可测试性**：Java 代码更容易编写单元测试
3. **可移植性**：不依赖特定数据库特性，便于迁移
4. **团队技能**：Java 开发人员更熟悉应用层开发
5. **调试便利**：应用层代码更容易调试和排查问题

### 实现示例
```java
// ✅ 正确：在应用层实现指标去重
List<String> uniqueMetrics = metricRules.stream()
    .map(AlarmSchemeMetricRule::getMetricName)
    .distinct()
    .collect(Collectors.toList());

// ✅ 正确：在应用层计算规则哈希
String ruleHash = DigestUtils.md5Hex(ruleContent.toString());

// ✅ 正确：在应用层实现增量同步判断
if (!currentHash.equals(deviceRule.getRuleHash())) {
    syncToThingsBoard(deviceRule);
}

// ❌ 错误：使用数据库视图
CREATE VIEW v_alarm_scheme_metrics AS ...

// ❌ 错误：使用触发器自动更新
CREATE TRIGGER auto_sync_trigger ...

// ❌ 错误：使用函数计算
CREATE FUNCTION calculate_rule_hash() ...
```

## 表设计规范

### 命名规范
- 表名使用小写字母，单词间用下划线分隔
- 表名使用名词，体现业务含义
- 关联表命名格式: `主表_关联表_rel` 或 `主表_从表`
- **统一使用 `g3d_` 前缀**（避免表名冲突）
  - 例如：`g3d_alarm_scheme`、`g3d_alarm_instance`

### 字段规范
- 字段名使用小写字母，单词间用下划线分隔
- 布尔类型字段以 `is_` 开头
- 时间字段以 `_time` 或 `_at` 结尾

### 必备字段
每张表必须包含以下字段：
```sql
id BIGSERIAL PRIMARY KEY,
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
```

### 软删除字段
需要软删除的表必须包含：
```sql
deleted SMALLINT NOT NULL DEFAULT 0  -- 0-未删除,1-已删除
```

### 审计字段
需要审计的表必须包含：
```sql
created_by BIGINT NOT NULL DEFAULT 0,  -- 创建人ID，0表示系统
updated_by BIGINT NOT NULL DEFAULT 0   -- 更新人ID，0表示系统
```

## 字段非空约束规范

### 核心原则
- **所有字段必须定义为 NOT NULL**
- **可空字段必须设置合理的默认值**
- **避免使用 NULL 值，使用默认值代替**

### 默认值设置规范

#### 字符串类型
```sql
column_name VARCHAR(100) NOT NULL DEFAULT ''
```

#### 数值类型
```sql
column_count INT NOT NULL DEFAULT 0
column_amount DECIMAL(20,6) NOT NULL DEFAULT 0.000000
```

#### 时间类型
```sql
-- 未设置时间使用 '1970-01-01 00:00:00'
column_time TIMESTAMP NOT NULL DEFAULT '1970-01-01 00:00:00'

-- 永久有效使用 '9999-12-31 23:59:59'
end_time TIMESTAMP NOT NULL DEFAULT '9999-12-31 23:59:59'
```

#### JSON 类型（PostgreSQL 使用 JSONB）
```sql
config_json JSONB NOT NULL DEFAULT '{}'   -- 空对象
list_json JSONB NOT NULL DEFAULT '[]'     -- 空数组
```

#### 外键字段
```sql
foreign_id BIGINT NOT NULL DEFAULT 0  -- 0表示未关联
```

## 字段类型规范

### 主键
- 使用 `BIGSERIAL` 类型（自增长整数）

### 字符串
- 短字符串（<50）: `VARCHAR(50)`
- 中等字符串（50-200）: `VARCHAR(200)`
- 长字符串（>200）: `TEXT`
- 固定长度: `CHAR(n)`

### 数值
- 整数: `INT`、`BIGINT`
- 小整数: `SMALLINT`（如状态、标志位）
- 金额: `DECIMAL(20,6)`
- 浮点数: `DOUBLE PRECISION`

### 时间
- 日期时间: `TIMESTAMP`
- 时间戳: `BIGINT`（毫秒）

### JSON
- 使用 `JSONB` 类型（推荐，支持索引）
- 或使用 `JSON` 类型（纯文本存储）

## 索引设计规范

### 主键索引
- 每张表必须有主键
- 使用 `PRIMARY KEY` 约束

### 唯一索引
- 业务唯一字段使用 `UNIQUE` 约束
- 命名格式: `uk_字段名`

```sql
CONSTRAINT uk_code UNIQUE (scheme_code)
```

### 普通索引
- 常用查询字段建立索引
- 命名格式: `idx_表名_字段名`
- 组合索引命名: `idx_表名_字段1_字段2`

```sql
CREATE INDEX idx_alarm_scheme_station_type ON alarm_scheme(station_type_id);
CREATE INDEX idx_alarm_scheme_status ON alarm_scheme(status, deleted);
```

### 索引设计原则
1. 频繁查询的字段建立索引
2. WHERE、ORDER BY、GROUP BY 字段建立索引
3. 外键字段建立索引
4. 区分度高的字段优先建立索引
5. 避免过多索引（单表不超过5个）
6. 组合索引遵循最左前缀原则

## 表注释规范

### 表注释
```sql
COMMENT ON TABLE alarm_scheme IS '告警方案表';
```

### 字段注释
```sql
COMMENT ON COLUMN alarm_scheme.id IS '主键ID';
COMMENT ON COLUMN alarm_scheme.scheme_code IS '告警方案编码（唯一）';
```

## 触发器规范

### 自动更新 updated_at 字段

创建通用触发器函数：
```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

为表创建触发器：
```sql
CREATE TRIGGER trigger_alarm_scheme_updated_at
BEFORE UPDATE ON alarm_scheme
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
```

## 表设计示例

```sql
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
COMMENT ON COLUMN g3d_alarm_scheme.device_count IS '关联设备数量（冗余字段）';
COMMENT ON COLUMN g3d_alarm_scheme.status IS '状态：0-禁用,1-启用';
COMMENT ON COLUMN g3d_alarm_scheme.deleted IS '逻辑删除：0-未删除,1-已删除';

CREATE INDEX idx_alarm_scheme_station_type ON g3d_alarm_scheme(station_type_id);
CREATE INDEX idx_alarm_scheme_status ON g3d_alarm_scheme(status, deleted);
CREATE INDEX idx_alarm_scheme_created_at ON g3d_alarm_scheme(created_at);

CREATE TRIGGER trigger_alarm_scheme_updated_at
BEFORE UPDATE ON g3d_alarm_scheme
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
```

**对应的 Java 实体类**：
```java
import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;
import java.util.Map;

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
    private String enableRuleConfig; // JSON 字符串，使用时转换为 Map
    
    @Column(name = "device_count", nullable = false)
    private Integer deviceCount;
    
    @Column(name = "status", nullable = false)
    private Integer status;
    
    @Column(name = "created_by", nullable = false)
    private Long createdBy;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @Column(name = "updated_by", nullable = false)
    private Long updatedBy;
    
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
    
    @Column(name = "deleted", nullable = false)
    private Integer deleted;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (createdBy == null) createdBy = 0L;
        if (updatedBy == null) updatedBy = 0L;
        if (deleted == null) deleted = 0;
        if (status == null) status = 1;
        if (deviceCount == null) deviceCount = 0;
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
```

## PostgreSQL 特性

### JSONB 类型优势
- 支持索引（GIN 索引）
- 查询性能更好
- 支持 JSON 操作符

```sql
-- 创建 JSONB 字段的 GIN 索引
CREATE INDEX idx_alarm_scheme_config ON alarm_scheme USING GIN (enable_rule_config);

-- 查询 JSON 字段
SELECT * FROM alarm_scheme WHERE enable_rule_config->>'type' = 'CUSTOM';
```

### 序列（SERIAL）
- `SERIAL` = `INT` + 自增
- `BIGSERIAL` = `BIGINT` + 自增
- 推荐使用 `BIGSERIAL` 作为主键

### 数组类型
PostgreSQL 支持数组类型，但本项目统一使用 JSONB 存储列表数据。

## 性能优化建议

### 分区表
对于数据量大的表（如告警实例、通知记录），建议使用分区表：
```sql
CREATE TABLE alarm_instance (
  -- 字段定义
) PARTITION BY RANGE (created_at);

CREATE TABLE alarm_instance_2026_01 PARTITION OF alarm_instance
FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE alarm_instance_2026_02 PARTITION OF alarm_instance
FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
```

### VACUUM 和 ANALYZE
定期执行 VACUUM 和 ANALYZE 维护数据库性能：
```sql
VACUUM ANALYZE alarm_instance;
```

### 连接池配置
- 使用 HikariCP 连接池
- 合理设置连接池大小
- 设置连接超时和空闲超时

## 数据库命名约定

### 数据库名
```
iot_alarm
```

### 表名前缀
- 统一使用 `g3d_` 前缀
- 例如：`g3d_alarm_scheme`、`g3d_alarm_instance`

### 字段名约定
- 主键: `id`
- 外键: `{关联表}_id`，如 `scheme_id`、`device_id`
- 创建时间: `created_at`
- 更新时间: `updated_at`
- 删除标记: `deleted`
- 创建人: `created_by`
- 更新人: `updated_by`


## 禁止使用的数据库特性

### 严格禁止
本项目严格禁止使用以下数据库特性，所有业务逻辑必须在应用层（Java）实现：

1. ❌ **数据库视图（VIEW）**
   - 不允许创建任何视图
   - 查询逻辑应在应用层实现

2. ❌ **业务触发器（TRIGGER）**
   - 除了 `update_updated_at_column` 触发器外，不允许创建其他触发器
   - 业务逻辑触发器应在应用层实现

3. ❌ **数据库函数（FUNCTION）**
   - 除了 `update_updated_at_column` 函数外，不允许创建其他函数
   - 计算逻辑应在应用层实现

4. ❌ **存储过程（STORED PROCEDURE）**
   - 不允许创建任何存储过程
   - 业务流程应在应用层实现

### 应用层实现示例

```java
// ✅ 正确：在应用层实现指标去重
@Service
public class AlarmSchemeService {
    public List<String> getUniqueMetrics(Long schemeId) {
        List<AlarmSchemeMetricRule> rules = metricRuleMapper.selectList(
            new LambdaQueryWrapper<AlarmSchemeMetricRule>()
                .eq(AlarmSchemeMetricRule::getSchemeId, schemeId)
        );
        
        return rules.stream()
            .map(AlarmSchemeMetricRule::getMetricName)
            .distinct()
            .collect(Collectors.toList());
    }
}

// ✅ 正确：在应用层计算规则哈希
@Service
public class RuleHashService {
    public String calculateHash(Long schemeId) {
        String ruleContent = buildRuleContent(schemeId);
        return DigestUtils.md5Hex(ruleContent);
    }
}

// ✅ 正确：在应用层实现增量同步
@Service
public class SyncService {
    public void syncIfChanged(Long deviceRuleId) {
        AlarmSchemeDeviceRule rule = deviceRuleMapper.selectById(deviceRuleId);
        String currentHash = ruleHashService.calculateHash(rule.getSchemeId());
        
        if (!currentHash.equals(rule.getRuleHash())) {
            syncToThingsBoard(rule);
            rule.setRuleHash(currentHash);
            deviceRuleMapper.updateById(rule);
        }
    }
}
```

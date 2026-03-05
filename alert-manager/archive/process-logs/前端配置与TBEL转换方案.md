# 前端配置与 TBEL 脚本转换方案

## 问题描述

虽然 ThingsBoard 支持 TBEL 脚本，但前端用户界面是**可视化配置**，用户不会直接编写脚本。

### 前端原型分析

```
水温-危险报警条件设置
├─ 阈值类型：常量区间类型
├─ 报警条件类型：持续时间 100s
└─ 描述：26.5 ℃ ≤ 水温 ≤ 30 ℃
```

**关键点**：
1. 用户通过下拉框、输入框配置条件
2. 不需要用户懂编程
3. 系统需要将配置转换为 TBEL 脚本

---

## 解决方案：配置 → TBEL 转换

### 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│ 前端界面（用户可视化配置）                                     │
├─────────────────────────────────────────────────────────────┤
│ - 选择指标：水温                                              │
│ - 选择操作符：区间（BETWEEN）                                 │
│ - 输入阈值：26.5 ~ 30                                        │
│ - 选择持续时间：100s                                          │
│ - 选择告警级别：危险（CRITICAL）                              │
└─────────────────────────────────────────────────────────────┘
                            ↓ JSON 配置
┌─────────────────────────────────────────────────────────────┐
│ 后端服务（配置存储）                                          │
├─────────────────────────────────────────────────────────────┤
│ {                                                            │
│   "metricKey": "water_temperature",                          │
│   "operator": "BETWEEN",                                     │
│   "thresholdMin": 26.5,                                      │
│   "thresholdMax": 30,                                        │
│   "durationSeconds": 100,                                    │
│   "alarmLevel": "CRITICAL"                                   │
│ }                                                            │
└─────────────────────────────────────────────────────────────┘
                            ↓ TBEL 生成器
┌─────────────────────────────────────────────────────────────┐
│ TBEL 脚本生成器                                               │
├─────────────────────────────────────────────────────────────┤
│ function expression(ctx, water_temperature) {                │
│   var currentTs = ctx.latestTs;                              │
│   var tempTs = ctx.args.water_temperature.ts;                │
│   var duration = (currentTs - tempTs) / 1000;                │
│                                                              │
│   return water_temperature >= 26.5 &&                        │
│          water_temperature <= 30 &&                          │
│          duration >= 100;                                    │
│ }                                                            │
└─────────────────────────────────────────────────────────────┘
                            ↓ API 调用
┌─────────────────────────────────────────────────────────────┐
│ ThingsBoard CalculatedField                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 数据库设计验证

### 当前表结构是否支持？✅ 完全支持

#### alarm_scheme_metric_rule 表
```sql
CREATE TABLE alarm_scheme_metric_rule (
  id BIGSERIAL PRIMARY KEY,
  scheme_id BIGINT NOT NULL,
  metric_key VARCHAR(100) NOT NULL,        -- ✅ 水温
  metric_name VARCHAR(100) NOT NULL,       -- ✅ 水温
  metric_alias VARCHAR(100) NOT NULL,      -- ✅ 别名
  device_id BIGINT NOT NULL DEFAULT 0,     -- ✅ 当前设备
  trigger_type VARCHAR(20) NOT NULL,       -- ✅ INDEPENDENT
  linkage_group_id BIGINT NOT NULL,        -- ✅ 联动组
  ...
);
```

#### alarm_level_condition 表
```sql
CREATE TABLE alarm_level_condition (
  id BIGSERIAL PRIMARY KEY,
  metric_rule_id BIGINT NOT NULL,
  alarm_level VARCHAR(20) NOT NULL,        -- ✅ CRITICAL
  condition_operator VARCHAR(20) NOT NULL, -- ✅ BETWEEN
  threshold_value DECIMAL(20,6),           -- ✅ 单值阈值
  threshold_min DECIMAL(20,6),             -- ✅ 26.5
  threshold_max DECIMAL(20,6),             -- ✅ 30
  duration_seconds INT NOT NULL,           -- ✅ 100
  ...
);
```

**结论**：✅ 表结构完全支持前端配置需求

---

## TBEL 脚本生成器实现

### 核心类：TbelScriptGenerator

```java
@Service
public class TbelScriptGenerator {
    
    /**
     * 生成 TBEL 脚本
     * 
     * @param scheme 告警方案
     * @param metricRules 指标规则列表
     * @param levelConditionsMap 级别条件映射
     * @return TBEL 脚本字符串
     */
    public String generateTbelScript(
        AlarmScheme scheme,
        List<AlarmSchemeMetricRule> metricRules,
        Map<Long, List<AlarmLevelCondition>> levelConditionsMap
    ) {
        StringBuilder script = new StringBuilder();
        
        // 1. 函数签名
        script.append("function expression(ctx");
        for (AlarmSchemeMetricRule rule : metricRules) {
            script.append(", ").append(sanitizeArgName(rule.getMetricKey()));
        }
        script.append(") {\n");
        
        // 2. 变量定义
        script.append("  var currentTs = ctx.latestTs;\n");
        
        // 3. 构建条件表达式
        List<String> conditions = new ArrayList<>();
        
        // 按触发类型分组
        Map<String, List<AlarmSchemeMetricRule>> groupedRules = 
            metricRules.stream().collect(Collectors.groupingBy(rule -> {
                if ("INDEPENDENT".equals(rule.getTriggerType())) {
                    return "INDEPENDENT";
                } else {
                    return "LINKAGE_" + rule.getLinkageGroupId();
                }
            }));
        
        // 处理独立触发
        if (groupedRules.containsKey("INDEPENDENT")) {
            for (AlarmSchemeMetricRule rule : groupedRules.get("INDEPENDENT")) {
                String condition = generateRuleCondition(rule, levelConditionsMap.get(rule.getId()));
                conditions.add(condition);
            }
        }
        
        // 处理联动触发
        for (Map.Entry<String, List<AlarmSchemeMetricRule>> entry : groupedRules.entrySet()) {
            if (entry.getKey().startsWith("LINKAGE_")) {
                List<String> linkageConditions = new ArrayList<>();
                for (AlarmSchemeMetricRule rule : entry.getValue()) {
                    String condition = generateRuleCondition(rule, levelConditionsMap.get(rule.getId()));
                    linkageConditions.add(condition);
                }
                // 联动条件用 AND 连接
                conditions.add("(" + String.join(" && ", linkageConditions) + ")");
            }
        }
        
        // 4. 返回语句（所有条件用 OR 连接）
        script.append("  return ").append(String.join(" || ", conditions)).append(";\n");
        script.append("}\n");
        
        return script.toString();
    }
    
    /**
     * 生成单个规则的条件表达式
     */
    private String generateRuleCondition(
        AlarmSchemeMetricRule rule,
        List<AlarmLevelCondition> conditions
    ) {
        String argName = sanitizeArgName(rule.getMetricKey());
        List<String> levelConditions = new ArrayList<>();
        
        // 按告警级别优先级排序
        conditions.sort(Comparator.comparing(this::getAlarmLevelPriority));
        
        for (AlarmLevelCondition condition : conditions) {
            String expr = generateConditionExpression(argName, condition);
            
            // 如果有持续时间要求
            if (condition.getDurationSeconds() > 0) {
                String durationCheck = String.format(
                    "(currentTs - ctx.args.%s.ts) / 1000 >= %d",
                    argName, condition.getDurationSeconds()
                );
                expr = String.format("(%s && %s)", expr, durationCheck);
            }
            
            levelConditions.add(expr);
        }
        
        // 多个级别条件用 OR 连接
        return "(" + String.join(" || ", levelConditions) + ")";
    }
    
    /**
     * 生成条件表达式
     */
    private String generateConditionExpression(String argName, AlarmLevelCondition condition) {
        switch (condition.getConditionOperator()) {
            case "GT":
                return String.format("%s > %s", argName, condition.getThresholdValue());
            case "GTE":
                return String.format("%s >= %s", argName, condition.getThresholdValue());
            case "LT":
                return String.format("%s < %s", argName, condition.getThresholdValue());
            case "LTE":
                return String.format("%s <= %s", argName, condition.getThresholdValue());
            case "EQ":
                return String.format("%s == %s", argName, condition.getThresholdValue());
            case "NEQ":
                return String.format("%s != %s", argName, condition.getThresholdValue());
            case "BETWEEN":
                return String.format(
                    "(%s >= %s && %s <= %s)",
                    argName, condition.getThresholdMin(),
                    argName, condition.getThresholdMax()
                );
            default:
                throw new IllegalArgumentException("Unknown operator: " + condition.getConditionOperator());
        }
    }
    
    /**
     * 清理参数名称（确保是合法的 JavaScript 变量名）
     */
    private String sanitizeArgName(String metricKey) {
        // 替换非法字符为下划线
        return metricKey.replaceAll("[^a-zA-Z0-9_]", "_");
    }
    
    /**
     * 获取告警级别优先级
     */
    private int getAlarmLevelPriority(AlarmLevelCondition condition) {
        switch (condition.getAlarmLevel()) {
            case "CRITICAL": return 1;
            case "MAJOR": return 2;
            case "MINOR": return 3;
            case "WARNING": return 4;
            case "INDETERMINATE": return 5;
            default: return 99;
        }
    }
}
```

---

## 前端配置示例

### 示例 1：水温危险报警（原型图）

#### 前端配置
```json
{
  "schemeCode": "WATER_TEMP_001",
  "schemeName": "水温危险报警",
  "metricRules": [
    {
      "metricKey": "water_temperature",
      "metricName": "水温",
      "triggerType": "INDEPENDENT",
      "levelConditions": [
        {
          "alarmLevel": "CRITICAL",
          "conditionOperator": "BETWEEN",
          "thresholdMin": 26.5,
          "thresholdMax": 30,
          "durationSeconds": 100
        }
      ]
    }
  ]
}
```

#### 生成的 TBEL 脚本
```javascript
function expression(ctx, water_temperature) {
  var currentTs = ctx.latestTs;
  return (water_temperature >= 26.5 && water_temperature <= 30 && (currentTs - ctx.args.water_temperature.ts) / 1000 >= 100);
}
```

### 示例 2：多条件独立触发

#### 前端配置
```json
{
  "schemeCode": "PUMP_MULTI_001",
  "schemeName": "水泵多指标监控",
  "metricRules": [
    {
      "metricKey": "temperature",
      "metricName": "温度",
      "triggerType": "INDEPENDENT",
      "levelConditions": [
        {
          "alarmLevel": "CRITICAL",
          "conditionOperator": "GT",
          "thresholdValue": 80,
          "durationSeconds": 0
        }
      ]
    },
    {
      "metricKey": "pressure",
      "metricName": "压力",
      "triggerType": "INDEPENDENT",
      "levelConditions": [
        {
          "alarmLevel": "WARNING",
          "conditionOperator": "LT",
          "thresholdValue": 20,
          "durationSeconds": 0
        }
      ]
    }
  ]
}
```

#### 生成的 TBEL 脚本
```javascript
function expression(ctx, temperature, pressure) {
  var currentTs = ctx.latestTs;
  return (temperature > 80) || (pressure < 20);
}
```

### 示例 3：联动触发

#### 前端配置
```json
{
  "schemeCode": "PUMP_LINKAGE_001",
  "schemeName": "水泵联动监控",
  "metricRules": [
    {
      "metricKey": "temperature",
      "metricName": "温度",
      "triggerType": "LINKAGE",
      "linkageGroupId": 1,
      "levelConditions": [
        {
          "alarmLevel": "MAJOR",
          "conditionOperator": "GT",
          "thresholdValue": 70,
          "durationSeconds": 0
        }
      ]
    },
    {
      "metricKey": "pressure",
      "metricName": "压力",
      "triggerType": "LINKAGE",
      "linkageGroupId": 1,
      "levelConditions": [
        {
          "alarmLevel": "MAJOR",
          "conditionOperator": "GT",
          "thresholdValue": 100,
          "durationSeconds": 0
        }
      ]
    }
  ]
}
```

#### 生成的 TBEL 脚本
```javascript
function expression(ctx, temperature, pressure) {
  var currentTs = ctx.latestTs;
  return (temperature > 70 && pressure > 100);
}
```

---

## 前端界面设计建议

### 配置表单结构

```
告警方案配置
├─ 基本信息
│  ├─ 方案编码
│  ├─ 方案名称
│  └─ 测站类型
│
├─ 指标规则配置（可添加多个）
│  ├─ 指标选择（下拉框）
│  ├─ 触发类型（独立/联动）
│  ├─ 联动组（如果是联动）
│  │
│  └─ 级别条件（可添加多个）
│     ├─ 告警级别（下拉框：危险/重要/次要/警告/轻微）
│     ├─ 条件类型（下拉框：大于/小于/等于/区间）
│     ├─ 阈值输入
│     │  ├─ 单值：threshold_value
│     │  └─ 区间：threshold_min ~ threshold_max
│     └─ 持续时间（秒）
│
├─ 启动规则配置
│  ├─ 规则类型（下拉框：始终/定时/自定义/工况）
│  └─ 规则配置（根据类型显示不同表单）
│
└─ 关联测站
   └─ 测站选择（多选）
```

### 前端组件示例（Vue 3）

```vue
<template>
  <el-form :model="form" label-width="120px">
    <!-- 基本信息 -->
    <el-form-item label="方案编码">
      <el-input v-model="form.schemeCode" />
    </el-form-item>
    
    <!-- 指标规则 -->
    <el-form-item label="指标规则">
      <div v-for="(rule, index) in form.metricRules" :key="index">
        <el-card>
          <el-form-item label="监测指标">
            <el-select v-model="rule.metricKey">
              <el-option label="水温" value="water_temperature" />
              <el-option label="温度" value="temperature" />
              <el-option label="压力" value="pressure" />
            </el-select>
          </el-form-item>
          
          <el-form-item label="触发类型">
            <el-radio-group v-model="rule.triggerType">
              <el-radio label="INDEPENDENT">独立触发</el-radio>
              <el-radio label="LINKAGE">联动触发</el-radio>
            </el-radio-group>
          </el-form-item>
          
          <!-- 级别条件 -->
          <div v-for="(condition, cIndex) in rule.levelConditions" :key="cIndex">
            <el-form-item label="告警级别">
              <el-select v-model="condition.alarmLevel">
                <el-option label="危险" value="CRITICAL" />
                <el-option label="重要" value="MAJOR" />
                <el-option label="次要" value="MINOR" />
                <el-option label="警告" value="WARNING" />
              </el-select>
            </el-form-item>
            
            <el-form-item label="条件类型">
              <el-select v-model="condition.conditionOperator">
                <el-option label="大于" value="GT" />
                <el-option label="小于" value="LT" />
                <el-option label="等于" value="EQ" />
                <el-option label="区间" value="BETWEEN" />
              </el-select>
            </el-form-item>
            
            <!-- 阈值输入 -->
            <el-form-item label="阈值" v-if="condition.conditionOperator !== 'BETWEEN'">
              <el-input-number v-model="condition.thresholdValue" />
            </el-form-item>
            
            <el-form-item label="阈值范围" v-if="condition.conditionOperator === 'BETWEEN'">
              <el-input-number v-model="condition.thresholdMin" />
              <span> ~ </span>
              <el-input-number v-model="condition.thresholdMax" />
            </el-form-item>
            
            <el-form-item label="持续时间">
              <el-input-number v-model="condition.durationSeconds" />
              <span> 秒</span>
            </el-form-item>
          </div>
        </el-card>
      </div>
    </el-form-item>
  </el-form>
</template>

<script setup>
import { ref } from 'vue'

const form = ref({
  schemeCode: '',
  schemeName: '',
  metricRules: [
    {
      metricKey: '',
      triggerType: 'INDEPENDENT',
      levelConditions: [
        {
          alarmLevel: 'CRITICAL',
          conditionOperator: 'GT',
          thresholdValue: 0,
          durationSeconds: 0
        }
      ]
    }
  ]
})
</script>
```

---

## 总结

### ✅ 方案完全可行

1. **前端**：用户通过可视化界面配置
2. **后端**：将配置转换为 TBEL 脚本
3. **ThingsBoard**：执行 TBEL 脚本触发告警
4. **数据库**：表结构完全支持配置存储

### 关键优势

1. **用户友好**：不需要用户懂编程
2. **灵活强大**：支持复杂条件组合
3. **性能优化**：逻辑在 ThingsBoard 执行
4. **易于维护**：配置和脚本分离

### 实施步骤

1. ✅ 数据库表结构（已完成）
2. ⏳ 实现 TBEL 脚本生成器
3. ⏳ 实现前端配置界面
4. ⏳ 实现配置保存和同步
5. ⏳ 测试和优化

---

**结论**：前端可视化配置 + 后端 TBEL 生成，完美解决方案！✅

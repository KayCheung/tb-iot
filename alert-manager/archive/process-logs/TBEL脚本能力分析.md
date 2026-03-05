# ThingsBoard TBEL 脚本能力分析

## 发现日期
2026-03-03

## 关键发现

ThingsBoard 支持 **TBEL (ThingsBoard Expression Language)** 脚本，这是一个用户自定义脚本语言，可以在告警规则中使用。

---

## 一、TBEL 核心能力

### 1.1 函数签名
```javascript
function expression(ctx, arg1, arg2, ...): boolean
```

### 1.2 参数类型
- **ctx**: 上下文对象，包含 `latestTs` 和所有参数
- **arg1, arg2, ...**: 配置的参数（attributes 或 latest telemetry）
- 支持类型：boolean, int64 (long), double, string, JSON

### 1.3 参数访问方式

#### 方式 1：直接访问参数
```javascript
var temperatureC = (temperatureF - 32) / 1.8;
return temperatureC > 36;
```

#### 方式 2：通过 ctx 对象访问
```javascript
var temperatureC = (ctx.args.temperatureF.value - 32) / 1.8;
var temperatureTs = ctx.args.temperatureF.ts;
return temperatureC > 36 && ((temperatureTs / 1000) % 3600) == 0;
```

### 1.4 ctx 对象结构
```javascript
{
  "temperatureF": {
    "ts": 1740644636669,  // 时间戳（毫秒）
    "value": 98.7         // 值
  },
  "latestTs": 1740644636669  // 最新时间戳
}
```

---

## 二、对告警管理系统的影响

### 2.1 表达式能力大幅提升 ✅

#### 之前的担忧
- 不确定是否支持复杂表达式
- 不确定是否支持时间判断
- 不确定是否支持多条件组合

#### 现在的能力
✅ **支持完整的 JavaScript 语法**
- 变量定义
- 条件判断（if/else）
- 循环（for/while）
- 函数调用
- 数学运算
- 字符串操作
- 时间戳处理

### 2.2 可以在 ThingsBoard 侧实现的功能

#### ✅ 持续时间判断
```javascript
function expression(ctx, temperature) {
  var currentTs = ctx.latestTs;
  var temperatureTs = ctx.args.temperature.ts;
  var durationSeconds = (currentTs - temperatureTs) / 1000;
  
  return temperature > 80 && durationSeconds >= 300; // 持续5分钟
}
```

#### ✅ 时间范围判断（部分）
```javascript
function expression(ctx, temperature) {
  var currentTs = ctx.latestTs;
  var hour = new Date(currentTs).getHours();
  
  // 只在 8:00-18:00 触发告警
  return temperature > 80 && hour >= 8 && hour < 18;
}
```

#### ✅ 复杂条件组合
```javascript
function expression(ctx, temperature, pressure, humidity) {
  // 独立触发：任一条件满足
  var condition1 = temperature > 80;
  var condition2 = pressure < 20;
  
  // 联动触发：多个条件同时满足
  var condition3 = temperature > 70 && pressure > 100 && humidity > 60;
  
  return condition1 || condition2 || condition3;
}
```

#### ✅ 跨设备联动（通过参数配置）
```javascript
function expression(ctx, device1_temp, device2_pressure) {
  // device1_temp 和 device2_pressure 可以配置为不同设备的指标
  return device1_temp > 80 && device2_pressure > 100;
}
```

---

## 三、更新后的架构设计

### 3.1 告警触发逻辑分工

#### ThingsBoard 侧（TBEL 脚本）
✅ **可以实现**：
1. 指标条件判断（阈值、操作符）
2. 多条件组合（OR/AND）
3. 持续时间判断
4. 简单时间范围判断（小时级别）
5. 跨设备联动（通过参数配置）

#### 告警系统侧（二次过滤）
⚠️ **仍需实现**：
1. 复杂启动规则（SCHEDULED、CUSTOM）
   - 星期判断（周一到周五）
   - 多个时间段（08:00-12:00, 14:00-18:00）
2. 工况启动规则（CONDITION）
3. 告警方案启用/禁用状态判断

### 3.2 推荐架构

```
┌─────────────────────────────────────────────────────────────┐
│ ThingsBoard (TBEL 脚本)                                      │
├─────────────────────────────────────────────────────────────┤
│ 1. 指标条件判断（temperature > 80）                          │
│ 2. 多条件组合（temp > 80 OR pressure < 20）                 │
│ 3. 持续时间判断（持续 5 分钟）                               │
│ 4. 简单时间判断（8:00-18:00）                                │
│ 5. 跨设备联动（device1.temp > 80 AND device2.pressure > 100）│
└─────────────────────────────────────────────────────────────┘
                            ↓ Kafka 消息
┌─────────────────────────────────────────────────────────────┐
│ 告警管理系统（二次过滤）                                      │
├─────────────────────────────────────────────────────────────┤
│ 1. 告警方案状态判断（status = 1）                            │
│ 2. 复杂启动规则判断                                          │
│    - SCHEDULED: 判断日期范围                                 │
│    - CUSTOM: 判断星期 + 多时间段                             │
│    - CONDITION: 判断工况条件                                 │
│ 3. 创建告警实例                                              │
│ 4. 触发通知                                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 四、TBEL 脚本生成策略

### 4.1 基础模板

```javascript
function expression(ctx, arg1, arg2, ...) {
  // 1. 提取参数值
  var value1 = arg1;
  var value2 = arg2;
  
  // 2. 条件判断
  var condition1 = value1 > threshold1;
  var condition2 = value2 < threshold2;
  
  // 3. 组合逻辑
  return condition1 || condition2;
}
```

### 4.2 包含持续时间的模板

```javascript
function expression(ctx, temperature) {
  var currentTs = ctx.latestTs;
  var temperatureTs = ctx.args.temperature.ts;
  var durationSeconds = (currentTs - temperatureTs) / 1000;
  
  // 温度超过 80 度，且持续 300 秒
  return temperature > 80 && durationSeconds >= 300;
}
```

### 4.3 包含时间范围的模板

```javascript
function expression(ctx, temperature) {
  var currentTs = ctx.latestTs;
  var hour = new Date(currentTs).getHours();
  
  // 温度超过 80 度，且在 8:00-18:00 之间
  return temperature > 80 && hour >= 8 && hour < 18;
}
```

### 4.4 复杂联动的模板

```javascript
function expression(ctx, temp1, temp2, pressure1, pressure2) {
  // 独立触发条件
  var independent1 = temp1 > 80;
  var independent2 = pressure1 < 20;
  
  // 联动触发条件（同时满足）
  var linkage1 = temp2 > 70 && pressure2 > 100;
  
  // 组合：独立条件 OR 联动条件
  return independent1 || independent2 || linkage1;
}
```

---

## 五、代码实现示例

### 5.1 TBEL 脚本生成器

```java
public class TbelScriptGenerator {
    
    /**
     * 生成 TBEL 脚本
     */
    public String generateScript(
        AlarmScheme scheme,
        List<AlarmSchemeMetricRule> metricRules,
        Map<Long, List<AlarmLevelCondition>> levelConditionsMap
    ) {
        StringBuilder script = new StringBuilder();
        
        // 1. 函数签名
        script.append("function expression(ctx");
        for (AlarmSchemeMetricRule rule : metricRules) {
            script.append(", ").append(getArgName(rule));
        }
        script.append(") {\n");
        
        // 2. 变量定义
        script.append("  var currentTs = ctx.latestTs;\n");
        
        // 3. 条件判断
        List<String> conditions = new ArrayList<>();
        
        // 按触发类型分组
        Map<String, List<AlarmSchemeMetricRule>> groupedRules = groupByTriggerType(metricRules);
        
        // 独立触发
        if (groupedRules.containsKey("INDEPENDENT")) {
            for (AlarmSchemeMetricRule rule : groupedRules.get("INDEPENDENT")) {
                String condition = generateRuleCondition(rule, levelConditionsMap.get(rule.getId()));
                conditions.add(condition);
            }
        }
        
        // 联动触发
        for (Map.Entry<String, List<AlarmSchemeMetricRule>> entry : groupedRules.entrySet()) {
            if (entry.getKey().startsWith("LINKAGE_")) {
                List<String> linkageConditions = new ArrayList<>();
                for (AlarmSchemeMetricRule rule : entry.getValue()) {
                    String condition = generateRuleCondition(rule, levelConditionsMap.get(rule.getId()));
                    linkageConditions.add(condition);
                }
                conditions.add("(" + String.join(" && ", linkageConditions) + ")");
            }
        }
        
        // 4. 返回结果
        script.append("  return ").append(String.join(" || ", conditions)).append(";\n");
        script.append("}\n");
        
        return script.toString();
    }
    
    /**
     * 生成单个规则的条件
     */
    private String generateRuleCondition(
        AlarmSchemeMetricRule rule,
        List<AlarmLevelCondition> conditions
    ) {
        String argName = getArgName(rule);
        List<String> levelConditions = new ArrayList<>();
        
        for (AlarmLevelCondition condition : conditions) {
            String expr = generateConditionExpression(argName, condition);
            
            // 如果有持续时间要求
            if (condition.getDurationSeconds() > 0) {
                expr = String.format(
                    "(%s && (currentTs - ctx.args.%s.ts) / 1000 >= %d)",
                    expr, argName, condition.getDurationSeconds()
                );
            }
            
            levelConditions.add(expr);
        }
        
        // 多个级别条件 OR 连接
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
     * 获取参数名称
     */
    private String getArgName(AlarmSchemeMetricRule rule) {
        return "arg_" + rule.getId();
    }
}
```

### 5.2 生成的 TBEL 脚本示例

#### 示例 1：简单条件
```javascript
function expression(ctx, arg_1) {
  var currentTs = ctx.latestTs;
  return (arg_1 > 80);
}
```

#### 示例 2：多条件 OR
```javascript
function expression(ctx, arg_1, arg_2) {
  var currentTs = ctx.latestTs;
  return (arg_1 > 80) || (arg_2 < 20);
}
```

#### 示例 3：联动触发
```javascript
function expression(ctx, arg_1, arg_2, arg_3) {
  var currentTs = ctx.latestTs;
  return (arg_1 > 80) || (arg_2 < 20) || (arg_2 > 70 && arg_3 > 100);
}
```

#### 示例 4：包含持续时间
```javascript
function expression(ctx, arg_1) {
  var currentTs = ctx.latestTs;
  return (arg_1 > 80 && (currentTs - ctx.args.arg_1.ts) / 1000 >= 300);
}
```

#### 示例 5：包含时间范围（可选）
```javascript
function expression(ctx, arg_1) {
  var currentTs = ctx.latestTs;
  var hour = new Date(currentTs).getHours();
  return (arg_1 > 80 && hour >= 8 && hour < 18);
}
```

---

## 六、更新后的可行性评估

### 6.1 风险等级调整

| 风险项 | 原评估 | 新评估 | 说明 |
|--------|--------|--------|------|
| 表达式能力不足 | 🔴 高风险 | 🟢 低风险 | TBEL 支持完整 JavaScript 语法 |
| 持续时间判断 | 🟡 中风险 | 🟢 低风险 | 可以通过 ctx.args.xxx.ts 实现 |
| 跨设备联动 | 🟡 中风险 | 🟢 低风险 | 通过参数配置实现 |
| 复杂时间规则 | 🟡 中风险 | 🟡 中风险 | 简单时间可在 TB 实现，复杂的仍需二次过滤 |

### 6.2 架构优化

#### 优化前
- ThingsBoard：简单表达式
- 告警系统：复杂逻辑 + 持续时间 + 时间规则

#### 优化后
- ThingsBoard：复杂表达式 + 持续时间 + 简单时间规则
- 告警系统：复杂时间规则（星期、多时间段）+ 工况规则

### 6.3 性能优化

通过在 ThingsBoard 侧实现更多逻辑：
- ✅ 减少 Kafka 消息量（不满足条件的不发送）
- ✅ 减少告警系统的计算压力
- ✅ 提高告警响应速度

---

## 七、实施建议更新

### 7.1 优先级调整

#### 高优先级（立即实施）
1. ✅ 实现 TBEL 脚本生成器
2. ✅ 测试 TBEL 脚本能力
3. ✅ 实现 CalculatedField 同步

#### 中优先级（后续实施）
1. 实现复杂启动规则的二次过滤
2. 实现工况启动规则
3. 性能优化和监控

#### 低优先级（可选）
1. 简单时间规则迁移到 ThingsBoard
2. 持续时间判断迁移到 ThingsBoard

### 7.2 测试计划

#### 测试用例 1：基础 TBEL 脚本
```javascript
function expression(ctx, temperature) {
  return temperature > 80;
}
```

#### 测试用例 2：持续时间判断
```javascript
function expression(ctx, temperature) {
  var currentTs = ctx.latestTs;
  var temperatureTs = ctx.args.temperature.ts;
  var durationSeconds = (currentTs - temperatureTs) / 1000;
  return temperature > 80 && durationSeconds >= 300;
}
```

#### 测试用例 3：复杂条件组合
```javascript
function expression(ctx, temp, pressure, humidity) {
  return (temp > 80) || (pressure < 20) || (temp > 70 && pressure > 100 && humidity > 60);
}
```

---

## 八、总结

### 8.1 关键发现

✅ **ThingsBoard TBEL 脚本能力远超预期**
- 支持完整的 JavaScript 语法
- 支持时间戳访问和计算
- 支持复杂条件组合
- 支持持续时间判断

### 8.2 架构优化

通过 TBEL 脚本，可以将更多逻辑下沉到 ThingsBoard：
- 减少 Kafka 消息量
- 减少告警系统计算压力
- 提高系统整体性能

### 8.3 实施信心

从 **可行但有风险** 提升到 **完全可行且性能更优**

---

**分析人**：Kiro AI Assistant  
**分析日期**：2026-03-03  
**文档版本**：V1.0

# ThingsBoard 接口分析与调整建议

## 一、ThingsBoard 实际接口分析

### 1.1 核心接口

根据提供的 `thingsboard-calculated-field-controller.json`，ThingsBoard 使用的是 **Calculated Field（计算字段）** 接口，而非标准的 Alarm API。

#### 主要接口：

1. **创建/更新计算字段**
   - 接口：`POST /api/calculatedField`
   - 说明：创建或更新计算字段，ThingsBoard 会生成 UUID
   - 权限：TENANT_ADMIN 或 CUSTOMER_USER

2. **查询计算字段**
   - 接口：`GET /api/calculatedField/{calculatedFieldId}`
   - 说明：根据 ID 获取计算字段详情

3. **删除计算字段**
   - 接口：`DELETE /api/calculatedField/{calculatedFieldId}`
   - 说明：删除指定的计算字段

4. **确认告警**
   - 接口：`POST /api/alarm/{alarmId}/ack`
   - 说明：确认告警，设置 ack_ts 时间戳

5. **清除告警**
   - 接口：`POST /api/alarm/{alarmId}/clear`
   - 说明：清除告警，设置 clear_ts 时间戳

### 1.2 CalculatedField 数据结构

```json
{
  "id": {
    "id": "uuid",
    "entityType": "CALCULATED_FIELD"
  },
  "tenantId": {
    "id": "uuid",
    "entityType": "TENANT"
  },
  "entityId": {
    "id": "device_uuid",
    "entityType": "DEVICE"
  },
  "type": "SIMPLE",  // 类型：SIMPLE, SCRIPT, ALARM, etc.
  "name": "计算字段名称",
  "configuration": {
    "arguments": {
      "arg1": {
        "refEntityKey": {
          "key": "temperature",
          "type": "TS_LATEST",  // TS_LATEST, ATTRIBUTE, TS_ROLLING
          "scope": "SERVER_SCOPE"
        },
        "defaultValue": "0",
        "limit": 1,
        "timeWindow": 60000
      }
    },
    "expression": "arg1 > 80",  // 表达式
    "output": {
      "name": "high_temp_alarm",
      "type": "ATTRIBUTE",  // ATTRIBUTE 或 TIME_SERIES
      "scope": "SERVER_SCOPE",
      "strategy": {
        "type": "IMMEDIATE",  // IMMEDIATE 或 RULE_CHAIN
        "saveAttribute": true,
        "sendWsUpdate": true,
        "processCfs": true
      }
    },
    "useLatestTs": true
  }
}
```

### 1.3 Kafka 消息结构

根据 `thingsboard-alert.json`，ThingsBoard 通过规则链发送的告警消息：

```json
{
  "id": {
    "entityType": "ALARM",
    "id": "21e12611-ff8b-4a1b-b9b9-687a05dcc7b7"
  },
  "type": "电量不足",  // 告警类型（唯一标识）
  "originator": {
    "entityType": "DEVICE",
    "id": "8ab42900-f92e-11f0-9cb1-415cd14764cd"
  },
  "severity": "WARNING",  // CRITICAL, MAJOR, MINOR, WARNING, INDETERMINATE
  "acknowledged": false,
  "cleared": false,
  "startTs": 1770301055898,
  "originatorName": "喜盈门地下1号井",
  "status": "ACTIVE_UNACK",
  "details": {}
}
```

## 二、当前设计存在的问题

### 2.1 接口映射错误

**问题**：`.kiro/steering/external-apis.md` 中定义的接口与实际不符

- 文档中使用：`POST /api/plugins/telemetry/DEVICE/{deviceId}/ALARM`
- 实际应使用：`POST /api/calculatedField`

**影响**：
- 无法正确创建告警规则
- 同步逻辑需要重新设计

### 2.2 数据库表结构不完整

**问题**：`alarm_scheme_device_rule` 表缺少关键字段

当前字段：
```sql
tb_alarm_rule_id VARCHAR(100) NOT NULL DEFAULT ''
```

**缺失信息**：
- 没有存储 CalculatedField ID（ThingsBoard 返回的 UUID）
- `tb_alarm_type` 作为唯一标识是正确的，但需要明确其生成规则

**建议调整**：
```sql
-- 重命名字段以更准确反映其含义
ALTER TABLE alarm_scheme_device_rule 
  RENAME COLUMN tb_alarm_rule_id TO tb_calculated_field_id;

COMMENT ON COLUMN alarm_scheme_device_rule.tb_calculated_field_id IS 'ThingsBoard计算字段ID（UUID）';
```

### 2.3 告警类型（tb_alarm_type）生成规则不明确

**问题**：`tb_alarm_type` 是 Kafka 消息中唯一能定位告警方案的字段，但生成规则未明确

**建议规则**：
```
格式：{scheme_code}_{device_id}
示例：PUMP_TEMP_001_3001

优点：
1. 全局唯一
2. 包含方案信息
3. 包含设备信息
4. 便于追溯和调试
```

### 2.4 CalculatedField 与告警方案的映射关系不清晰

**问题**：一个告警方案可能包含多个指标规则，如何映射到 CalculatedField？

**方案 A：一个设备一个 CalculatedField（推荐）**
- 将告警方案的所有指标规则合并成一个复杂表达式
- 优点：管理简单，同步效率高
- 缺点：表达式可能复杂

**方案 B：一个指标规则一个 CalculatedField**
- 每个指标规则创建独立的 CalculatedField
- 优点：规则清晰，易于维护
- 缺点：需要管理多个 CalculatedField，联动触发复杂

**推荐方案 A**，理由：
1. 告警方案本身就是一个整体
2. ThingsBoard 支持复杂表达式
3. 减少 API 调用次数
4. 简化同步逻辑

## 三、调整建议

### 3.1 数据库表结构调整

#### 增量脚本：`db/migration/V1.0.1__update_alarm_scheme_device_rule.sql`

```sql
-- 重命名字段以更准确反映其含义
ALTER TABLE alarm_scheme_device_rule 
  RENAME COLUMN tb_alarm_rule_id TO tb_calculated_field_id;

-- 更新注释
COMMENT ON COLUMN alarm_scheme_device_rule.tb_calculated_field_id IS 'ThingsBoard计算字段ID（UUID）';
COMMENT ON COLUMN alarm_scheme_device_rule.tb_alarm_type IS 'ThingsBoard告警类型（格式：{scheme_code}_{device_id}，全局唯一）';
```

### 3.2 告警类型生成规则

```java
/**
 * 生成 ThingsBoard 告警类型
 * 格式：{scheme_code}_{device_id}
 * 示例：PUMP_TEMP_001_3001
 */
public static String generateTbAlarmType(String schemeCode, Long deviceId) {
    return String.format("%s_%d", schemeCode, deviceId);
}
```

### 3.3 告警方案到 CalculatedField 的转换逻辑

#### 3.3.1 表达式生成

```java
/**
 * 将告警方案转换为 CalculatedField 表达式
 * 
 * 逻辑：
 * 1. 独立触发的规则：OR 连接
 * 2. 联动触发的规则：同一组内 AND 连接，组之间 OR 连接
 * 3. 每个规则包含多个级别条件：按优先级（CRITICAL > MAJOR > MINOR > WARNING > INDETERMINATE）
 */
public CalculatedFieldConfiguration convertToCalculatedField(
    AlarmScheme scheme,
    List<AlarmSchemeMetricRule> metricRules,
    Map<Long, List<AlarmLevelCondition>> levelConditionsMap,
    Device device
) {
    // 1. 构建 arguments（所有需要的指标）
    Map<String, Argument> arguments = new HashMap<>();
    for (AlarmSchemeMetricRule rule : metricRules) {
        String argName = "arg_" + rule.getId();
        Argument arg = new Argument();
        
        // 如果是当前设备的指标
        if (rule.getDeviceId() == 0) {
            arg.setRefEntityKey(new ReferencedEntityKey(
                rule.getMetricKey(),
                "TS_LATEST",
                "SERVER_SCOPE"
            ));
        } else {
            // 如果是其他设备的指标（联动）
            arg.setRefEntityId(new EntityId(
                "DEVICE",
                getDeviceTbId(rule.getDeviceId())
            ));
            arg.setRefEntityKey(new ReferencedEntityKey(
                rule.getMetricKey(),
                "TS_LATEST",
                "SERVER_SCOPE"
            ));
        }
        
        arg.setDefaultValue("0");
        arg.setLimit(1);
        arguments.put(argName, arg);
    }
    
    // 2. 构建 expression
    String expression = buildExpression(metricRules, levelConditionsMap);
    
    // 3. 构建 output（输出为属性，触发规则链）
    Output output = new AttributesOutput();
    output.setName(generateTbAlarmType(scheme.getSchemeCode(), device.getDeviceId()));
    output.setScope("SERVER_SCOPE");
    
    AttributesRuleChainOutputStrategy strategy = new AttributesRuleChainOutputStrategy();
    strategy.setType("RULE_CHAIN");
    output.setStrategy(strategy);
    
    // 4. 组装配置
    SimpleCalculatedFieldConfiguration config = new SimpleCalculatedFieldConfiguration();
    config.setArguments(arguments);
    config.setExpression(expression);
    config.setOutput(output);
    config.setUseLatestTs(true);
    
    return config;
}

/**
 * 构建表达式
 * 
 * 示例：
 * (arg_1 > 80) OR (arg_2 < 20 AND arg_3 > 100)
 */
private String buildExpression(
    List<AlarmSchemeMetricRule> metricRules,
    Map<Long, List<AlarmLevelCondition>> levelConditionsMap
) {
    // 按触发类型分组
    Map<String, List<AlarmSchemeMetricRule>> groupedRules = metricRules.stream()
        .collect(Collectors.groupingBy(rule -> {
            if ("INDEPENDENT".equals(rule.getTriggerType())) {
                return "INDEPENDENT";
            } else {
                return "LINKAGE_" + rule.getLinkageGroupId();
            }
        }));
    
    List<String> groupExpressions = new ArrayList<>();
    
    for (Map.Entry<String, List<AlarmSchemeMetricRule>> entry : groupedRules.entrySet()) {
        List<AlarmSchemeMetricRule> rules = entry.getValue();
        
        if (entry.getKey().equals("INDEPENDENT")) {
            // 独立触发：每个规则单独处理
            for (AlarmSchemeMetricRule rule : rules) {
                String ruleExpr = buildRuleExpression(rule, levelConditionsMap.get(rule.getId()));
                groupExpressions.add(ruleExpr);
            }
        } else {
            // 联动触发：同一组内 AND 连接
            List<String> linkageExprs = new ArrayList<>();
            for (AlarmSchemeMetricRule rule : rules) {
                String ruleExpr = buildRuleExpression(rule, levelConditionsMap.get(rule.getId()));
                linkageExprs.add(ruleExpr);
            }
            groupExpressions.add("(" + String.join(" AND ", linkageExprs) + ")");
        }
    }
    
    // 所有组之间 OR 连接
    return String.join(" OR ", groupExpressions);
}

/**
 * 构建单个规则的表达式
 * 按告警级别优先级：CRITICAL > MAJOR > MINOR > WARNING > INDETERMINATE
 */
private String buildRuleExpression(
    AlarmSchemeMetricRule rule,
    List<AlarmLevelCondition> conditions
) {
    String argName = "arg_" + rule.getId();
    
    // 按优先级排序
    List<AlarmLevelCondition> sortedConditions = conditions.stream()
        .sorted(Comparator.comparing(c -> getAlarmLevelPriority(c.getAlarmLevel())))
        .collect(Collectors.toList());
    
    List<String> conditionExprs = new ArrayList<>();
    for (AlarmLevelCondition condition : sortedConditions) {
        String condExpr = buildConditionExpression(argName, condition);
        conditionExprs.add(condExpr);
    }
    
    // 多个级别条件 OR 连接
    return "(" + String.join(" OR ", conditionExprs) + ")";
}

/**
 * 构建单个条件表达式
 */
private String buildConditionExpression(String argName, AlarmLevelCondition condition) {
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
            return String.format("(%s >= %s AND %s <= %s)", 
                argName, condition.getThresholdMin(),
                argName, condition.getThresholdMax());
        default:
            throw new IllegalArgumentException("Unknown operator: " + condition.getConditionOperator());
    }
}
```

### 3.4 同步流程

#### 创建告警方案时同步到 ThingsBoard

```java
@Transactional
public void createAlarmScheme(AlarmSchemeDTO dto) {
    // 1. 保存告警方案
    AlarmScheme scheme = saveAlarmScheme(dto);
    
    // 2. 保存测站关联
    saveStationRelations(scheme.getId(), dto.getStationIds());
    
    // 3. 保存指标规则和级别条件
    saveMetricRulesAndConditions(scheme.getId(), dto.getMetricRules());
    
    // 4. 查询所有关联的设备
    List<Device> devices = getDevicesByStations(dto.getStationIds());
    
    // 5. 为每个设备创建 ThingsBoard CalculatedField
    for (Device device : devices) {
        syncDeviceToThingsBoard(scheme, device);
    }
    
    // 6. 更新设备数量
    updateDeviceCount(scheme.getId());
}

/**
 * 同步单个设备到 ThingsBoard
 */
private void syncDeviceToThingsBoard(AlarmScheme scheme, Device device) {
    try {
        // 1. 生成告警类型
        String tbAlarmType = generateTbAlarmType(scheme.getSchemeCode(), device.getDeviceId());
        
        // 2. 保存映射记录（状态：PENDING）
        AlarmSchemeDeviceRule mapping = new AlarmSchemeDeviceRule();
        mapping.setSchemeId(scheme.getId());
        mapping.setDeviceId(device.getDeviceId());
        mapping.setTbDeviceId(device.getTbDeviceId());
        mapping.setTbAlarmType(tbAlarmType);
        mapping.setSyncStatus("PENDING");
        alarmSchemeDeviceRuleMapper.insert(mapping);
        
        // 3. 构建 CalculatedField
        CalculatedField calculatedField = new CalculatedField();
        calculatedField.setEntityId(new EntityId("DEVICE", device.getTbDeviceId()));
        calculatedField.setType("SIMPLE");
        calculatedField.setName(tbAlarmType);
        
        // 转换配置
        CalculatedFieldConfiguration config = convertToCalculatedField(
            scheme,
            getMetricRules(scheme.getId()),
            getLevelConditionsMap(scheme.getId()),
            device
        );
        calculatedField.setConfiguration(config);
        
        // 4. 调用 ThingsBoard API
        CalculatedField result = thingsBoardClient.saveCalculatedField(calculatedField);
        
        // 5. 更新映射记录（状态：SUCCESS）
        mapping.setTbCalculatedFieldId(result.getId().getId());
        mapping.setSyncStatus("SUCCESS");
        mapping.setSyncTime(LocalDateTime.now());
        alarmSchemeDeviceRuleMapper.updateById(mapping);
        
    } catch (Exception e) {
        // 6. 更新映射记录（状态：FAILED）
        mapping.setSyncStatus("FAILED");
        mapping.setSyncError(e.getMessage());
        alarmSchemeDeviceRuleMapper.updateById(mapping);
        
        log.error("同步设备到ThingsBoard失败: scheme={}, device={}", 
            scheme.getId(), device.getDeviceId(), e);
    }
}
```

### 3.5 Kafka 消息处理

```java
@KafkaListener(topics = "${thingsboard.alarm.topic}")
public void handleAlarmMessage(String message) {
    try {
        // 1. 解析消息
        ThingsBoardAlarm alarm = JSON.parseObject(message, ThingsBoardAlarm.class);
        
        // 2. 根据 tb_alarm_type 查询告警方案
        AlarmSchemeDeviceRule mapping = alarmSchemeDeviceRuleMapper.selectOne(
            new LambdaQueryWrapper<AlarmSchemeDeviceRule>()
                .eq(AlarmSchemeDeviceRule::getTbAlarmType, alarm.getType())
        );
        
        if (mapping == null) {
            log.warn("未找到告警方案映射: tbAlarmType={}", alarm.getType());
            return;
        }
        
        // 3. 查询告警方案详情
        AlarmScheme scheme = alarmSchemeMapper.selectById(mapping.getSchemeId());
        if (scheme == null || scheme.getStatus() == 0) {
            log.info("告警方案不存在或已禁用: schemeId={}", mapping.getSchemeId());
            return;
        }
        
        // 4. 二次过滤（启动规则判断）
        if (!checkEnableRule(scheme, alarm)) {
            log.info("告警不满足启动规则: schemeId={}, alarmId={}", 
                scheme.getId(), alarm.getId().getId());
            return;
        }
        
        // 5. 创建告警实例
        createAlarmInstance(scheme, mapping, alarm);
        
        // 6. 触发通知
        triggerNotification(scheme, alarm);
        
    } catch (Exception e) {
        log.error("处理告警消息失败: message={}", message, e);
    }
}
```

### 3.6 更新 external-apis.md

需要更新 `.kiro/steering/external-apis.md` 文件，替换为实际的 CalculatedField API。

## 四、总结

### 4.1 关键变更

1. **接口变更**：从 Alarm API 改为 CalculatedField API
2. **字段重命名**：`tb_alarm_rule_id` → `tb_calculated_field_id`
3. **告警类型规则**：`{scheme_code}_{device_id}` 格式
4. **映射关系**：一个设备一个 CalculatedField（包含所有指标规则）
5. **表达式构建**：独立触发 OR 连接，联动触发 AND 连接

### 4.2 优势

1. **唯一标识清晰**：通过 `tb_alarm_type` 准确定位告警方案
2. **同步逻辑简化**：一个设备一个 CalculatedField，减少 API 调用
3. **扩展性好**：支持复杂的联动触发逻辑
4. **可追溯性强**：告警类型包含方案编码和设备ID

### 4.3 后续工作

1. 更新数据库表结构（增量脚本）
2. 更新 external-apis.md 文档
3. 实现 CalculatedField 转换逻辑
4. 实现同步服务
5. 实现 Kafka 消息处理
6. 编写单元测试和集成测试

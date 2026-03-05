---
description: 外部依赖接口规范和集成说明
inclusion: auto
---

# 外部依赖接口规范

## ThingsBoard API

### 认证方式
```
POST /api/auth/login
{
  "username": "your_username",
  "password": "your_password"
}

响应：
{
  "token": "eyJhbGciOiJIUzUxMiJ9...",
  "refreshToken": "eyJhbGciOiJIUzUxMiJ9..."
}

后续请求携带 Token：
Authorization: Bearer {token}
```

### 创建/更新计算字段（告警规则）
```
POST /api/calculatedField

说明：ThingsBoard 使用 Calculated Field（计算字段）实现告警规则
创建时不传 id，更新时传入已存在的 id

请求体：
{
  "entityId": {
    "id": "8ab42900-f92e-11f0-9cb1-415cd14764cd",
    "entityType": "DEVICE"
  },
  "type": "SIMPLE",
  "name": "PUMP_TEMP_001_3001",
  "configuration": {
    "arguments": {
      "temperature": {
        "refEntityKey": {
          "key": "temperature",
          "type": "TS_LATEST",
          "scope": "SERVER_SCOPE"
        },
        "defaultValue": "0",
        "limit": 1
      }
    },
    "expression": "temperature > 80",
    "output": {
      "name": "PUMP_TEMP_001_3001",
      "type": "ATTRIBUTE",
      "scope": "SERVER_SCOPE",
      "strategy": {
        "type": "RULE_CHAIN"
      }
    },
    "useLatestTs": true
  }
}

响应：
{
  "id": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "entityType": "CALCULATED_FIELD"
  },
  "entityId": {
    "id": "8ab42900-f92e-11f0-9cb1-415cd14764cd",
    "entityType": "DEVICE"
  },
  "type": "SIMPLE",
  "name": "PUMP_TEMP_001_3001",
  "configuration": { ... },
  "createdTime": 1709452800000
}
```

### 查询计算字段
```
GET /api/calculatedField/{calculatedFieldId}

响应：同创建接口响应
```

### 删除计算字段
```
DELETE /api/calculatedField/{calculatedFieldId}

响应：200 OK（无响应体）
```

### 确认告警
```
POST /api/alarm/{alarmId}/ack

说明：确认告警，设置 ack_ts 时间戳，触发 ALARM_ACK 规则链事件

响应：
{
  "id": {
    "entityType": "ALARM",
    "id": "21e12611-ff8b-4a1b-b9b9-687a05dcc7b7"
  },
  "type": "电量不足",
  "acknowledged": true,
  "ackTs": 1709452800000,
  ...
}
```

### 清除告警
```
POST /api/alarm/{alarmId}/clear

说明：清除告警，设置 clear_ts 时间戳，触发 ALARM_CLEAR 规则链事件

响应：
{
  "id": {
    "entityType": "ALARM",
    "id": "21e12611-ff8b-4a1b-b9b9-687a05dcc7b7"
  },
  "type": "电量不足",
  "cleared": true,
  "clearTs": 1709452800000,
  ...
}
```

### Kafka 告警消息格式
```
说明：ThingsBoard 通过规则链 MQTT 节点发送告警消息

消息示例：
{
  "id": {
    "entityType": "ALARM",
    "id": "21e12611-ff8b-4a1b-b9b9-687a05dcc7b7"
  },
  "type": "电量不足",
  "originator": {
    "entityType": "DEVICE",
    "id": "8ab42900-f92e-11f0-9cb1-415cd14764cd"
  },
  "severity": "WARNING",
  "acknowledged": false,
  "cleared": false,
  "startTs": 1770301055898,
  "endTs": 1772469953511,
  "ackTs": 0,
  "clearTs": 0,
  "originatorName": "喜盈门地下1号井",
  "status": "ACTIVE_UNACK",
  "details": {}
}

关键字段说明：
- type: 告警类型（格式：{scheme_code}_{device_id}），用于定位告警方案
- severity: 告警级别（CRITICAL, MAJOR, MINOR, WARNING, INDETERMINATE）
- status: 告警状态（ACTIVE_UNACK, ACTIVE_ACK, CLEARED_UNACK, CLEARED_ACK）
- originator: 告警来源设备
```

### 错误处理
```
ThingsBoard API 错误响应：
{
  "status": 400,
  "message": "Invalid request body",
  "errorCode": 31,
  "timestamp": 1709452800000
}

常见错误码：
- 2: 通用错误 (500)
- 10: 认证失败 (401)
- 11: JWT token 过期 (401)
- 15: 凭证过期 (401)
- 20: 权限不足 (403)
- 30: 参数错误 (400)
- 31: 请求参数错误 (400)
- 32: 资源不存在 (404)
- 33: 请求过多 (429)
- 40: 订阅违规 (403)
- 41: 实体数量超限 (403)
```

## 外部系统接口（设备管理、测站管理）

### 查询测站关联的设备
```
GET /api/stations/{stationId}/devices

响应：
{
  "code": "200",
  "message": "成功",
  "data": [
    {
      "deviceId": 3001,
      "deviceName": "喜盈门地下1号井",
      "deviceCode": "DEV_001",
      "tbDeviceId": "8ab42900-f92e-11f0-9cb1-415cd14764cd",
      "productId": 2001,
      "productName": "智能水泵",
      "status": "ONLINE"
    }
  ]
}
```

### 查询设备关联的测站
```
GET /api/devices/{deviceId}/stations

响应：
{
  "code": "200",
  "message": "成功",
  "data": [
    {
      "stationId": 1001,
      "stationName": "泵站A",
      "stationCode": "STATION_001",
      "stationTypeId": 1001,
      "stationTypeName": "管网液位测站"
    }
  ]
}
```

### 查询设备详情
```
GET /api/devices/{deviceId}

响应：
{
  "code": "200",
  "message": "成功",
  "data": {
    "deviceId": 3001,
    "deviceName": "喜盈门地下1号井",
    "deviceCode": "DEV_001",
    "tbDeviceId": "8ab42900-f92e-11f0-9cb1-415cd14764cd",
    "productId": 2001,
    "productName": "智能水泵",
    "status": "ONLINE",
    "location": "上海市浦东新区",
    "longitude": 121.5,
    "latitude": 31.2
  }
}
```

### 查询产品详情
```
GET /api/products/{productId}

响应：
{
  "code": "200",
  "message": "成功",
  "data": {
    "productId": 2001,
    "productName": "智能水泵",
    "productCode": "PROD_001",
    "telemetrySchema": {
      "temperature": {
        "name": "温度",
        "unit": "℃",
        "type": "double",
        "min": -20,
        "max": 100
      },
      "pressure": {
        "name": "压力",
        "unit": "kPa",
        "type": "double",
        "min": 0,
        "max": 200
      }
    }
  }
}
```

### 批量查询设备信息
```
POST /api/devices/batch

请求体：
{
  "deviceIds": [3001, 3002, 3003]
}

响应：
{
  "code": "200",
  "message": "成功",
  "data": [
    {
      "deviceId": 3001,
      "deviceName": "喜盈门地下1号井",
      ...
    }
  ]
}
```

## 接口调用规范

### 超时设置
- 连接超时：5 秒
- 读取超时：10 秒
- ThingsBoard API：15 秒（创建/更新规则）

### 重试策略
- 重试次数：3 次
- 重试间隔：1 秒、3 秒、5 秒（指数退避）
- 可重试的错误：网络超时、5xx 错误
- 不可重试的错误：4xx 错误（除 429）

### 限流策略
- ThingsBoard API：50 次/秒
- 外部系统 API：100 次/秒
- 使用令牌桶算法限流

### 熔断策略
- 失败率阈值：50%
- 最小请求数：20
- 熔断时间：30 秒
- 半开状态请求数：5

### 降级策略
1. **ThingsBoard API 降级**
   - 同步失败时，记录失败状态
   - 定时任务重试
   - 不影响告警方案创建

2. **外部系统 API 降级**
   - 查询失败时，使用缓存数据
   - 缓存过期时，返回默认值
   - 记录失败日志，后续补偿

## 接口监控

### 监控指标
- 调用次数
- 成功率
- 平均响应时间
- P95 响应时间
- P99 响应时间
- 错误率

### 告警规则
- 成功率 < 95%：告警
- 平均响应时间 > 1s：告警
- P99 响应时间 > 3s：告警
- 错误率 > 5%：告警

## 接口文档维护

### 文档更新
- 接口变更时，及时更新文档
- 标注接口版本和变更日期
- 保留历史版本文档

### 变更通知
- 接口变更提前 1 周通知
- 重大变更提前 1 个月通知
- 废弃接口保留至少 6 个月

## Mock 数据

### 开发环境 Mock
```java
@Profile("dev")
@Service
public class MockExternalApiService implements ExternalApiService {
    
    @Override
    public List<Device> getStationDevices(Long stationId) {
        // 返回 Mock 数据
        return Arrays.asList(
            new Device(3001L, "设备1", "uuid_001"),
            new Device(3002L, "设备2", "uuid_002")
        );
    }
}
```

### 测试环境 Mock
- 使用 WireMock 或 MockServer
- 模拟各种响应场景（成功、失败、超时）
- 支持动态配置 Mock 数据

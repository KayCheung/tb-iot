---
description: API 接口设计规范和 RESTful 标准
inclusion: auto
---

# API 接口设计规范

## RESTful API 规范

### URL 设计
- 使用名词复数形式
- 使用小写字母，单词间用连字符分隔
- 版本号放在 URL 中: `/api/v1/`

```
GET    /api/v1/alarms           # 查询告警列表
GET    /api/v1/alarms/{id}      # 查询告警详情
POST   /api/v1/alarms           # 创建告警
PUT    /api/v1/alarms/{id}      # 更新告警
DELETE /api/v1/alarms/{id}      # 删除告警
PATCH  /api/v1/alarms/{id}      # 部分更新告警
```

### HTTP 方法
- **GET**: 查询资源
- **POST**: 创建资源
- **PUT**: 完整更新资源
- **PATCH**: 部分更新资源
- **DELETE**: 删除资源

### 资源嵌套
不超过两层嵌套：
```
GET /api/v1/alarm-schemes/{id}/stations      # 查询告警方案关联的测站
POST /api/v1/alarms/{id}/handle-log          # 添加告警处理记录
```

## 请求格式规范

### 请求头
```
Content-Type: application/json
Authorization: Bearer {token}
```

### 查询参数
```
GET /api/v1/alarms?page=1&size=20&status=ACTIVE&level=CRITICAL
```

### 请求体
```json
{
  "schemeName": "泵站高温规则",
  "stationTypeId": 1001,
  "stationIds": [1001, 1002],
  "alarmMessage": "温度超过阈值，请及时处理"
}
```

## 响应格式规范

### 统一响应结构
```json
{
  "code": "200",
  "msg": "成功",
  "data": {}
}
```

### 成功响应
```json
{
  "code": "200",
  "msg": "成功",
  "data": {
    "id": 10001,
    "schemeName": "泵站高温规则"
  }
}
```

### 分页响应
```json
{
  "code": "200",
  "msg": "成功",
  "data": {
    "page": 1,
    "size": 20,
    "total": 100,
    "pages": 5,
    "items": []
  }
}
```

### 错误响应
```json
{
  "code": "400",
  "msg": "参数校验失败：告警方案名称不能为空",
  "data": null
}
```

## HTTP 状态码规范

### 成功状态码
- **200 OK**: 请求成功
- **201 Created**: 创建成功
- **204 No Content**: 删除成功（无返回内容）

### 客户端错误
- **400 Bad Request**: 请求参数错误
- **401 Unauthorized**: 未授权
- **403 Forbidden**: 无权限
- **404 Not Found**: 资源不存在
- **409 Conflict**: 资源冲突

### 服务端错误
- **500 Internal Server Error**: 服务器内部错误
- **503 Service Unavailable**: 服务不可用

## 错误码规范

### 错误码格式
```
{模块代码}{错误类型}{序号}
```

### 模块代码
- `ALARM`: 告警模块 (01)
- `NOTIFY`: 通知模块 (02)
- `SCHEME`: 告警方案模块 (03)

### 错误类型
- `01`: 参数错误
- `02`: 业务错误
- `03`: 系统错误

### 示例
```
ALARM_01_001: 告警ID不能为空
ALARM_02_001: 告警不存在
ALARM_03_001: 数据库操作失败
```

## 参数校验规范

### 使用注解校验
```java
public class AlarmSchemeCreateRequest {
    @NotBlank(message = "告警方案名称不能为空")
    private String schemeName;
    
    @NotNull(message = "测站类型不能为空")
    private Long stationTypeId;
    
    @NotEmpty(message = "关联测站不能为空")
    private List<Long> stationIds;
}
```

### 常用校验注解
- `@NotNull`: 不能为 null
- `@NotBlank`: 不能为空字符串
- `@NotEmpty`: 集合不能为空
- `@Min`: 最小值
- `@Max`: 最大值
- `@Size`: 长度限制
- `@Pattern`: 正则表达式

## 接口文档规范

### 接口描述格式
```
接口说明：告警模块 - 分页查询告警列表
接口地址：GET /api/v1/alarms
请求类型：GET
```

### 请求参数表格
| 字段名 | 类型 | 是否必填 | 描述 | 示例值 |
|--------|------|----------|------|--------|
| page | integer | 否 | 页码，默认1 | 1 |
| size | integer | 否 | 每页数量，默认20 | 20 |

### 响应参数表格
| 字段名 | 类型 | 是否必需 | 描述 | 示例值 |
|--------|------|----------|------|--------|
| code | string | 是 | 状态码 | 200 |
| message | string | 是 | 消息 | 成功 |

## 接口版本管理

### 版本号规则
- 主版本号: 不兼容的 API 修改
- 次版本号: 向下兼容的功能性新增
- 修订号: 向下兼容的问题修正

### 版本控制
- 在 URL 中体现版本: `/api/v1/`、`/api/v2/`
- 旧版本保留至少 6 个月
- 提前通知客户端版本废弃

## 接口安全规范

### 认证
- 使用 JWT Token 认证
- Token 放在 Authorization 请求头

### 权限控制
- 使用 RBAC 权限模型
- 接口级别权限控制

### 数据脱敏
- 敏感信息不返回（如密码）
- 手机号脱敏: `138****8000`
- 身份证脱敏: `330***********1234`

### 防重放攻击
- 使用 nonce 和 timestamp
- 请求签名验证

## 接口性能规范

### 响应时间
- 查询接口: < 200ms
- 创建/更新接口: < 500ms
- 批量操作接口: < 1s

### 分页限制
- 默认每页 20 条
- 最大每页 100 条

### 批量操作限制
- 批量创建: 最多 100 条
- 批量删除: 最多 100 条

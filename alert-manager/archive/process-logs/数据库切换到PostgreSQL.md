# 数据库切换到 PostgreSQL

## 更新时间
2026-03-04

## 变更说明

用户反馈数据库使用 PostgreSQL 而非 MySQL，需要调整所有数据库相关的设计和脚本。

## 主要变更

### 1. 创建 PostgreSQL 版本的初始化脚本
✅ 创建 `db/init-schema-postgresql.sql`
- 包含所有 12 张表的 PostgreSQL DDL
- 使用 PostgreSQL 特有语法

### 2. 更新 Steering 文件
✅ 更新 `.kiro/steering/project-overview.md`
- 数据库从 MySQL 8.0+ 改为 PostgreSQL 14+

✅ 创建 `.kiro/steering/database-standards-postgresql.md`
- PostgreSQL 专用的数据库设计规范
- 包含 PostgreSQL 特性说明

### 3. 更新文档
✅ 更新 `db/migration/README.md`
- 更新执行方式为 PostgreSQL 命令

## MySQL vs PostgreSQL 语法差异

### 1. 主键自增
```sql
-- MySQL
id BIGINT PRIMARY KEY AUTO_INCREMENT

-- PostgreSQL
id BIGSERIAL PRIMARY KEY
```

### 2. 注释
```sql
-- MySQL
CREATE TABLE table_name (...) COMMENT='表注释';
column_name VARCHAR(100) COMMENT '字段注释'

-- PostgreSQL
COMMENT ON TABLE table_name IS '表注释';
COMMENT ON COLUMN table_name.column_name IS '字段注释';
```

### 3. JSON 类型
```sql
-- MySQL
config_json JSON NOT NULL DEFAULT (JSON_OBJECT())

-- PostgreSQL
config_json JSONB NOT NULL DEFAULT '{}'
```

### 4. 小整数类型
```sql
-- MySQL
status TINYINT NOT NULL DEFAULT 1

-- PostgreSQL
status SMALLINT NOT NULL DEFAULT 1
```

### 5. 时间类型
```sql
-- MySQL
created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

-- PostgreSQL
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
-- 需要使用触发器实现自动更新
```

### 6. 索引创建
```sql
-- MySQL
INDEX idx_name (column_name)

-- PostgreSQL
CREATE INDEX idx_name ON table_name(column_name);
```

### 7. 唯一约束
```sql
-- MySQL
UNIQUE KEY uk_name (column_name)

-- PostgreSQL
CONSTRAINT uk_name UNIQUE (column_name)
```

### 8. 存储引擎
```sql
-- MySQL
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4

-- PostgreSQL
-- 不需要指定存储引擎和字符集（在数据库级别设置）
```

## PostgreSQL 特有功能

### 1. 自动更新 updated_at 触发器
```sql
-- 创建触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为表创建触发器
CREATE TRIGGER trigger_table_name_updated_at
BEFORE UPDATE ON table_name
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
```

### 2. JSONB 类型
- 支持索引（GIN 索引）
- 查询性能更好
- 支持 JSON 操作符

```sql
-- 创建 GIN 索引
CREATE INDEX idx_config ON table_name USING GIN (config_json);

-- 查询 JSON 字段
SELECT * FROM table_name WHERE config_json->>'key' = 'value';
```

### 3. 数组类型
PostgreSQL 原生支持数组类型，但本项目统一使用 JSONB 存储列表数据。

## 文件清单

### 使用文件
- `db/init-schema.sql` - PostgreSQL 初始化脚本
- `.kiro/steering/database-standards.md` - PostgreSQL 数据库规范

### 已删除文件
- ~~`db/init-schema-postgresql.sql`~~ - 已重命名为 `init-schema.sql`
- ~~`.kiro/steering/database-standards-postgresql.md`~~ - 已重命名为 `database-standards.md`
- ~~`db/init-schema.sql` (MySQL版本)~~ - 已删除
- ~~`.kiro/steering/database-standards.md` (MySQL版本)~~ - 已删除

## 执行方式

```bash
# 1. 创建数据库
psql -U postgres -c "CREATE DATABASE iot_alarm WITH ENCODING='UTF8' LC_COLLATE='zh_CN.UTF-8' LC_CTYPE='zh_CN.UTF-8' TEMPLATE=template0;"

# 2. 执行初始化脚本
psql -U postgres -d iot_alarm -f db/init-schema.sql

# 3. 验证表结构
psql -U postgres -d iot_alarm -c "\dt"
psql -U postgres -d iot_alarm -c "\d alarm_scheme"
```

## 后续工作

1. 更新应用配置（application.yml）
   - 数据库驱动改为 PostgreSQL
   - 连接 URL 改为 PostgreSQL 格式

2. 更新 MyBatis-Plus 配置
   - 数据库类型设置为 PostgreSQL
   - 调整 SQL 方言

3. 测试数据库连接和基本操作

## 注意事项

1. PostgreSQL 对大小写敏感（如果使用双引号）
2. PostgreSQL 的序列（SERIAL）是独立对象
3. PostgreSQL 的 JSONB 性能优于 JSON
4. PostgreSQL 需要手动创建触发器实现 updated_at 自动更新
5. PostgreSQL 的分区表语法与 MySQL 不同

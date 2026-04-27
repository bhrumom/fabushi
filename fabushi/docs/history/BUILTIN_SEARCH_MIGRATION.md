# 内置内容迁移到D1全文搜索

## 概述

本文档描述如何将内置内容（特别是乾隆大藏经等GBK编码文件）迁移到Cloudflare D1数据库，并实现高效的全文搜索功能。

## 功能特性

- ✅ **GBK编码支持**: 自动检测和处理乾隆大藏经的GBK编码
- ✅ **批量迁移**: 支持大量文件的批量处理和上传
- ✅ **全文搜索**: 基于SQLite FTS5的高性能全文搜索
- ✅ **分类管理**: 自动提取和管理文档分类
- ✅ **内容清理**: 自动清理文件中的无关内容
- ✅ **错误处理**: 完善的错误处理和重试机制

## 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    迁移架构图                                │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  本地文件    │  │  Python脚本  │  │  D1数据库    │        │
│  │  (GBK编码)   │  │  (编码转换)  │  │  (FTS搜索)   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│         │                 │                 │             │
│         └─────────────────┼─────────────────┘             │
│                           │                               │
│  ┌─────────────────────────▼─────────────────────────┐    │
│  │            Cloudflare Worker API                  │    │
│  │  - /migrate-builtin-complete (迁移)               │    │
│  │  - /api/builtin/search (搜索)                     │    │
│  │  - /api/builtin/categories (分类)                 │    │
│  └───────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## 文件结构

```
├── migrate_builtin_to_d1.py          # 主迁移脚本
├── test_builtin_migration.py         # 测试脚本
├── deploy_builtin_search.sh          # 部署脚本
├── web/
│   ├── migrate-builtin-handler.js    # 后端处理器
│   ├── schema-builtin-search.sql     # 数据库schema
│   └── src/router.js                 # 路由配置
└── assets/built_in/                  # 内置内容目录
    ├── 乾隆大藏经txt版/               # GBK编码文件
    ├── 咒语/                         # 咒语文本
    ├── 经文/                         # 经文文本
    └── 房山石经陀罗尼梵音音频/        # 音频文件
```

## 快速开始

### 1. 部署后端服务

```bash
# 运行部署脚本
./deploy_builtin_search.sh
```

### 2. 执行迁移

```bash
# 安装Python依赖
pip install requests chardet pathlib

# 运行迁移脚本
python3 migrate_builtin_to_d1.py
```

### 3. 测试功能

```bash
# 运行测试脚本
python3 test_builtin_migration.py
```

## 详细说明

### 数据库Schema

```sql
-- 主表：存储文本内容
CREATE TABLE texts (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    file_path TEXT NOT NULL,
    category TEXT NOT NULL,
    file_name TEXT NOT NULL,
    word_count INTEGER DEFAULT 0,
    source TEXT DEFAULT 'builtin',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- FTS5虚拟表：全文搜索
CREATE VIRTUAL TABLE texts_fts USING fts5(
    title,
    content,
    category,
    content='texts',
    content_rowid='rowid'
);
```

### API端点

#### 1. 迁移API
```http
POST /migrate-builtin-complete
Content-Type: application/json

{
  "texts": [
    {
      "id": "unique_id",
      "title": "文档标题",
      "content": "文档内容",
      "filePath": "相对路径",
      "category": "分类",
      "fileName": "文件名",
      "wordCount": 字数,
      "source": "builtin"
    }
  ]
}
```

#### 2. 搜索API
```http
GET /api/builtin/search?q=关键词&category=分类&limit=20&offset=0
```

响应：
```json
{
  "success": true,
  "data": {
    "results": [
      {
        "id": "文档ID",
        "title": "标题",
        "content": "内容",
        "snippet": "高亮片段",
        "category": "分类",
        "wordCount": 字数
      }
    ],
    "pagination": {
      "total": 总数,
      "limit": 限制,
      "offset": 偏移,
      "hasMore": true
    }
  }
}
```

#### 3. 分类API
```http
GET /api/builtin/categories
```

响应：
```json
{
  "success": true,
  "data": [
    {
      "category": "分类名",
      "count": 文档数量
    }
  ]
}
```

### 编码处理

脚本自动处理不同编码：

```python
def detect_encoding(self, file_path):
    """检测文件编码"""
    try:
        with open(file_path, 'rb') as f:
            raw_data = f.read(10000)
            result = chardet.detect(raw_data)
            return result.get('encoding', 'utf-8')
    except Exception as e:
        return 'utf-8'

def read_file_content(self, file_path):
    """读取文件内容，自动处理编码"""
    encoding = self.detect_encoding(file_path)
    
    # 乾隆大藏经通常是GBK编码
    if "乾隆大藏经" in str(file_path):
        encoding = 'gbk'
    
    with open(file_path, 'r', encoding=encoding, errors='ignore') as f:
        content = f.read()
        return self.clean_content(content)
```

### 内容清理

自动清理文件中的无关内容：

```python
def clean_content(self, content):
    """清理文件内容"""
    # 移除ChmDecompiler标记
    content = content.replace(
        "This file is decompiled by an unregistered version...", 
        ""
    )
    
    # 移除多余的空行和空格
    lines = [line.strip() for line in content.split('\n') if line.strip()]
    return '\n'.join(lines)
```

## 性能优化

### 批量处理
- 每批处理10个文件，避免内存溢出
- 支持断点续传和错误重试

### 搜索优化
- 使用FTS5全文搜索引擎
- 支持中文分词和高亮显示
- 分页查询减少响应时间

### 数据库优化
- 创建必要的索引
- 使用触发器保持FTS表同步
- 统计表记录搜索性能

## 监控和维护

### 日志记录
```python
print(f"📖 处理文件: {file_path.name}")
print(f"✅ 处理完成: {metadata['title']} ({word_count}字)")
print(f"🚀 上传 {len(texts)} 个文本到D1数据库...")
```

### 错误处理
```python
try:
    # 处理逻辑
except Exception as e:
    print(f"❌ 处理文件失败 {file_path}: {e}")
    continue
```

### 统计信息
```python
print(f"📊 总计上传: {total_uploaded} 个文本")
print(f"📁 总计文件: {len(files)} 个")
```

## 故障排除

### 常见问题

1. **编码错误**
   - 确保文件编码检测正确
   - 对于乾隆大藏经使用GBK编码

2. **上传失败**
   - 检查网络连接
   - 验证API端点可用性
   - 查看后端日志

3. **搜索无结果**
   - 确认数据已成功迁移
   - 检查FTS表是否正确创建
   - 验证搜索关键词

### 调试命令

```bash
# 测试API连通性
curl -X GET "https://flutter.ombhrum.com/health"

# 测试搜索功能
curl -X GET "https://flutter.ombhrum.com/api/builtin/search?q=般若"

# 查看分类
curl -X GET "https://flutter.ombhrum.com/api/builtin/categories"
```

## 扩展功能

### 支持更多文件格式
- PDF文档解析
- Word文档处理
- HTML内容提取

### 高级搜索功能
- 模糊搜索
- 正则表达式搜索
- 语义搜索

### 性能监控
- 搜索响应时间统计
- 热门搜索词分析
- 用户行为追踪

## 总结

本迁移方案提供了完整的内置内容到D1数据库的迁移解决方案，特别针对乾隆大藏经等GBK编码文件进行了优化。通过FTS5全文搜索引擎，用户可以快速准确地搜索佛教经典内容。

系统具有良好的扩展性和维护性，支持大规模文档的处理和高并发的搜索请求。
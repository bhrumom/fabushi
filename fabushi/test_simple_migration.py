#!/usr/bin/env python3
"""
简化的迁移测试脚本
使用现有的API端点进行测试
"""

import requests
import json
import hashlib

def test_existing_search():
    """测试现有的搜索API"""
    try:
        print("🔍 测试现有搜索API...")
        response = requests.get(
            "https://flutter.ombhrum.com/api/search",
            params={"q": "般若", "limit": 5},
            timeout=10
        )
        
        print(f"📊 HTTP状态码: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"✅ 搜索成功: {result}")
        else:
            print(f"❌ 搜索失败: {response.text}")
            
    except Exception as e:
        print(f"💥 搜索异常: {e}")

def create_sample_migration():
    """创建样本迁移数据"""
    sample_texts = [
        {
            "id": hashlib.md5("心经".encode()).hexdigest()[:16],
            "title": "般若波罗蜜多心经",
            "content": "观自在菩萨，行深般若波罗蜜多时，照见五蕴皆空，度一切苦厄。舍利子，色不异空，空不异色，色即是空，空即是色，受想行识，亦复如是。",
            "filePath": "经文/般若波罗蜜多心经.txt",
            "category": "经文",
            "fileName": "般若波罗蜜多心经.txt",
            "wordCount": 50,
            "source": "builtin"
        },
        {
            "id": hashlib.md5("大悲咒".encode()).hexdigest()[:16],
            "title": "大悲咒",
            "content": "南无喝啰怛那哆啰夜耶，南无阿唎耶，婆卢羯帝烁钵啰耶，菩提萨埵婆耶，摩诃萨埵婆耶，摩诃迦卢尼迦耶。",
            "filePath": "咒语/大悲咒.txt",
            "category": "咒语",
            "fileName": "大悲咒.txt",
            "wordCount": 35,
            "source": "builtin"
        }
    ]
    
    return {"texts": sample_texts}

def main():
    """主函数"""
    print("🎯 开始简化迁移测试")
    print("=" * 40)
    
    # 1. 测试现有搜索API
    test_existing_search()
    
    # 2. 显示样本数据
    print("\n📝 样本迁移数据:")
    sample_data = create_sample_migration()
    print(json.dumps(sample_data, ensure_ascii=False, indent=2))
    
    print("\n📋 下一步操作:")
    print("1. 部署新的Worker代码到Cloudflare")
    print("2. 创建数据库schema")
    print("3. 运行完整迁移脚本")
    
    print("\n🔧 手动部署命令:")
    print("cd web && wrangler deploy")
    print("wrangler d1 execute flutter-db --file=schema-builtin-search.sql")

if __name__ == "__main__":
    main()
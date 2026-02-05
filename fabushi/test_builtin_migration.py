#!/usr/bin/env python3
import requests
import json
import os
from pathlib import Path

def test_migration():
    """测试迁移API"""
    url = "https://flutter.ombhrum.com/migrate-builtin-complete"
    
    # 简单的测试数据
    test_data = {
        "texts": [
            {
                "id": "test001",
                "title": "般若波罗蜜多心经",
                "content": "观自在菩萨，行深般若波罗蜜多时，照见五蕴皆空，度一切苦厄。舍利子，色不异空，空不异色，色即是空，空即是色，受想行识，亦复如是。",
                "filePath": "经文/般若波罗蜜多心经.txt",
                "category": "经文",
                "fileName": "般若波罗蜜多心经.txt",
                "wordCount": 50,
                "source": "builtin"
            },
            {
                "id": "test002",
                "title": "大悲咒",
                "content": "南无喝啰怛那哆啰夜耶，南无阿唎耶，婆卢羯帝烁钵啰耶，菩提萨埵婆耶，摩诃萨埵婆耶，摩诃迦卢尼迦耶。",
                "filePath": "咒语/大悲咒.txt",
                "category": "咒语",
                "fileName": "大悲咒.txt",
                "wordCount": 35,
                "source": "builtin"
            }
        ]
    }
    
    try:
        print("🧪 测试内置内容迁移API...")
        response = requests.post(
            url,
            json=test_data,
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        print(f"📊 HTTP状态码: {response.status_code}")
        print(f"📝 响应内容: {response.text}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ 迁移成功: {result}")
            return True
        else:
            print(f"❌ 迁移失败: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"💥 迁移异常: {e}")
        return False

def test_search():
    """测试搜索API"""
    base_url = "https://flutter.ombhrum.com"
    
    # 测试搜索
    search_queries = [
        "般若",
        "菩萨",
        "大悲"
    ]
    
    for query in search_queries:
        try:
            print(f"\n🔍 测试搜索: '{query}'")
            response = requests.get(
                f"{base_url}/api/builtin/search",
                params={"q": query, "limit": 5},
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get('success'):
                    results = result['data']['results']
                    print(f"✅ 搜索成功，找到 {len(results)} 条结果")
                    for i, item in enumerate(results[:3]):
                        print(f"  {i+1}. {item.get('title', 'N/A')}")
                else:
                    print(f"❌ 搜索失败: {result.get('error')}")
            else:
                print(f"❌ 搜索请求失败: {response.status_code}")
                
        except Exception as e:
            print(f"💥 搜索异常: {e}")

def test_categories():
    """测试分类API"""
    try:
        print("\n📂 测试获取分类...")
        response = requests.get(
            "https://flutter.ombhrum.com/api/builtin/categories",
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                categories = result['data']
                print(f"✅ 获取分类成功，共 {len(categories)} 个分类")
                for cat in categories:
                    print(f"  - {cat.get('category')}: {cat.get('count')} 个文档")
            else:
                print(f"❌ 获取分类失败: {result.get('error')}")
        else:
            print(f"❌ 分类请求失败: {response.status_code}")
            
    except Exception as e:
        print(f"💥 分类异常: {e}")

def run_full_test():
    """运行完整测试"""
    print("🎯 开始测试内置内容迁移和搜索功能")
    print("=" * 50)
    
    # 1. 测试迁移
    if test_migration():
        print("\n⏳ 等待数据处理...")
        import time
        time.sleep(2)
        
        # 2. 测试搜索
        test_search()
        
        # 3. 测试分类
        test_categories()
    
    print("\n🎉 测试完成！")

if __name__ == "__main__":
    run_full_test()
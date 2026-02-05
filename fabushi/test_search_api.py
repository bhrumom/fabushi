#!/usr/bin/env python3
"""
测试搜索API功能
"""

import requests
import json

def test_search_api():
    base_url = "https://flutter.ombhrum.com"
    
    print("🧪 测试搜索API功能")
    print("=" * 50)
    
    # 测试1: 获取分类
    print("\n1. 测试获取分类...")
    try:
        response = requests.get(f"{base_url}/api/builtin/categories")
        print(f"状态码: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"响应: {json.dumps(data, ensure_ascii=False, indent=2)}")
        else:
            print(f"错误响应: {response.text}")
    except Exception as e:
        print(f"请求失败: {e}")
    
    # 测试2: 搜索功能
    print("\n2. 测试搜索功能...")
    search_queries = ["般若", "心经", "佛", "法"]
    
    for query in search_queries:
        print(f"\n搜索关键词: {query}")
        try:
            response = requests.get(f"{base_url}/api/builtin/search?q={query}&limit=5")
            print(f"状态码: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    results = data.get('data', {}).get('results', [])
                    print(f"找到 {len(results)} 条结果")
                    for i, result in enumerate(results[:3]):  # 只显示前3条
                        print(f"  {i+1}. {result.get('title', 'N/A')} ({result.get('category', 'N/A')})")
                else:
                    print(f"搜索失败: {data}")
            else:
                print(f"错误响应: {response.text}")
        except Exception as e:
            print(f"搜索请求失败: {e}")
    
    # 测试3: 分类搜索
    print("\n3. 测试分类搜索...")
    try:
        response = requests.get(f"{base_url}/api/builtin/search?q=心经&category=乾隆大藏经&limit=3")
        print(f"状态码: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"分类搜索结果: {json.dumps(data, ensure_ascii=False, indent=2)}")
        else:
            print(f"错误响应: {response.text}")
    except Exception as e:
        print(f"分类搜索失败: {e}")

if __name__ == "__main__":
    test_search_api()
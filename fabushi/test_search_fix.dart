import 'dart:convert';
import 'package:http/http.dart' as http;

// 测试搜索API的类型转换修复
void main() async {
  await testSearchAPI();
}

Future<void> testSearchAPI() async {
  const baseUrl = 'https://flutter.ombhrum.com';
  const query = '心经';
  
  try {
    print('🔍 测试搜索API...');
    
    final url = '$baseUrl/api/builtin/search?q=${Uri.encodeComponent(query)}&limit=5';
    print('📡 请求URL: $url');
    
    final response = await http.get(Uri.parse(url));
    
    print('📊 响应状态码: ${response.statusCode}');
    print('📝 响应内容: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('📊 解析数据: $data');
      
      if (data['success'] == true && data['data'] != null) {
        final dataMap = data['data'] as Map<String, dynamic>;
        final results = dataMap['results'] as List;
        final pagination = dataMap['pagination'] as Map<String, dynamic>?;
        
        print('✅ 找到 ${results.length} 条结果');
        
        if (pagination != null) {
          print('📄 分页信息:');
          print('  - total: ${pagination['total']} (${pagination['total'].runtimeType})');
          print('  - limit: ${pagination['limit']} (${pagination['limit'].runtimeType})');
          print('  - offset: ${pagination['offset']} (${pagination['offset'].runtimeType})');
          print('  - hasMore: ${pagination['hasMore']} (${pagination['hasMore'].runtimeType})');
        }
        
        // 测试结果解析
        for (int i = 0; i < results.length && i < 3; i++) {
          final json = results[i];
          print('📄 结果 ${i + 1}:');
          print('  - id: ${json['id']} (${json['id'].runtimeType})');
          print('  - title: ${json['title']} (${json['title'].runtimeType})');
          print('  - category: ${json['category']} (${json['category'].runtimeType})');
          
          // 测试安全的ID解析
          final id = parseIdSafe(json['id']);
          print('  - 解析后的ID: $id (${id.runtimeType})');
        }
        
        print('🎉 API测试成功！');
      } else {
        print('⚠️ API返回数据格式不正确');
      }
    } else {
      print('❌ HTTP请求失败: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 测试异常: $e');
  }
}

// 安全解析ID的函数
int? parseIdSafe(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
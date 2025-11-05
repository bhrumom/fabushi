import 'package:flutter/foundation.dart';
import 'package:tobias/tobias.dart';
import 'package:url_launcher/url_launcher.dart';

class AlipayService {
  // 单例模式
  static final AlipayService _instance = AlipayService._internal();
  factory AlipayService() => _instance;
  AlipayService._internal();

  // Tobias实例
  final Tobias _tobias = Tobias();

  /// 初始化支付宝SDK
  Future<Map<String, dynamic>> initAlipay() async {
    try {
      if (kIsWeb) {
        return {
          'success': false,
          'message': '支付宝APP支付不支持Web平台',
        };
      }

      debugPrint('初始化支付宝SDK');
      
      // 检查支付宝是否安装
      bool isInstalled = await isAlipayInstalled();
      if (!isInstalled) {
        return {
          'success': false,
          'message': '未安装支付宝APP',
        };
      }

      return {
        'success': true,
          'message': '支付宝SDK初始化成功',
      };
    } catch (e) {
      debugPrint('支付宝SDK初始化失败: $e');
      return {
        'success': false,
        'message': '初始化失败: $e',
      };
    }
  }

  /// 发起支付宝APP支付
  Future<Map<String, dynamic>> payWithAlipay(String orderString) async {
    try {
      if (kIsWeb) {
        return {
          'success': false,
          'message': '支付宝APP支付不支持Web平台',
        };
      }

      // 验证支付参数
      if (!validatePayParameters(orderString)) {
        return {
          'success': false,
          'message': '支付参数验证失败',
        };
      }

      debugPrint('发起支付宝APP支付，订单字符串: ${orderString.substring(0, 50)}...');
      
      // 调用支付宝SDK进行支付
      final result = await _tobias.pay(orderString);

      debugPrint('支付宝支付结果: $result');

      // 解析支付结果
      final payResult = _parsePayResult(result);
      return payResult;
    } catch (e) {
      debugPrint('支付宝支付失败: $e');
      return {
        'success': false,
        'message': '支付失败: $e',
      };
    }
  }

  /// 解析支付结果
  Map<String, dynamic> _parsePayResult(Map<dynamic, dynamic> result) {
    try {
      // 支付宝支付结果码
      // 9000 - 订单支付成功
      // 8000 - 正在处理中
      // 4000 - 订单支付失败
      // 5000 - 重复请求
      // 6001 - 用户中途取消
      // 6002 - 网络连接出错
      // 6004 - 支付结果未知
      
      final resultStatus = result['resultStatus']?.toString() ?? '';
      final memo = result['memo']?.toString() ?? '';
      final resultData = result['result']?.toString() ?? '';

      debugPrint('支付结果状态: $resultStatus');
      debugPrint('支付结果描述: $memo');
      debugPrint('支付结果数据: $resultData');

      bool success = false;
      String message = '';

      switch (resultStatus) {
        case '9000':
          success = true;
          message = '支付成功';
          break;
        case '8000':
          message = '正在处理中';
          break;
        case '4000':
          message = '订单支付失败';
          break;
        case '5000':
          message = '重复请求';
          break;
        case '6001':
          message = '用户取消支付';
          break;
        case '6002':
          message = '网络连接错误';
          break;
        case '6004':
          message = '支付结果未知，请查询订单状态';
          break;
        default:
          message = '未知错误: $memo';
      }

      return {
        'success': success,
        'message': message,
        'resultStatus': resultStatus,
        'memo': memo,
        'result': resultData,
      };
    } catch (e) {
      debugPrint('解析支付结果失败: $e');
      return {
        'success': false,
        'message': '解析支付结果失败: $e',
      };
    }
  }

  /// 检查是否安装了支付宝
  Future<bool> isAlipayInstalled() async {
    try {
      // 使用Tobias实例的检查安装属性（异步）
      return await _tobias.isAliPayInstalled;
    } catch (e) {
      debugPrint('检查支付宝安装状态异常: $e');
      return false;
    }
  }

  /// 获取支付宝SDK版本
  Future<String> getAlipayVersion() async {
    try {
      if (kIsWeb) {
        return 'Web平台不支持';
      }
      
      // 使用Tobias实例的异步版本属性
      return await _tobias.aliPayVersion;
    } catch (e) {
      debugPrint('获取支付宝版本失败: $e');
      return '获取版本失败';
    }
  }

  /// 处理支付结果回调（用于原生平台回调）
  void handlePayResult(Map<dynamic, dynamic> result) {
    debugPrint('收到支付结果回调: $result');
    // final resultData = _parsePayResult(result);
    
    // 这里可以发送事件通知UI更新
    // 例如使用Provider、Bloc或EventBus等状态管理方案
  }

  /// 验证支付参数
  bool validatePayParameters(String orderString) {
    if (orderString.isEmpty) {
      debugPrint('订单字符串为空');
      return false;
    }
    
    try {
      // 验证订单字符串格式
      // 支付宝订单字符串通常包含以下关键字段
      // final requiredFields = ['app_id', 'method', 'charset', 'sign_type', 'sign', 'timestamp', 'version', 'biz_content'];
      
      // 简单的格式验证，实际应该解析具体的订单字符串格式
      if (!orderString.contains('app_id=')) {
        debugPrint('订单字符串缺少app_id字段');
        return false;
      }
      
      if (!orderString.contains('sign=')) {
        debugPrint('订单字符串缺少sign字段');
        return false;
      }
      
      debugPrint('支付参数验证通过');
      return true;
    } catch (e) {
      debugPrint('支付参数验证失败: $e');
      return false;
    }
  }

  /// 获取详细的错误信息
  String getDetailedErrorMessage(String resultStatus, String memo) {
    switch (resultStatus) {
      case '4000':
        return '系统异常，请稍后重试或联系客服';
      case '5000':
        return '重复请求，请勿重复提交订单';
      case '6001':
        return '用户取消支付，可重新发起支付';
      case '6002':
        return '网络连接异常，请检查网络后重试';
      case '6004':
        return '支付结果未知，请查询订单状态确认是否支付成功';
      default:
        return '支付异常：$memo';
    }
  }

  /// 生成安全的订单字符串（示例）
  String generateSecureOrderString(Map<String, dynamic> orderData) {
    try {
      // 这里应该实现订单字符串的生成逻辑
      // 包括参数排序、签名等步骤
      // 实际项目中这部分应该在服务端完成
      
      final orderString = orderData.entries
          .map((e) => '${e.key}="${e.value}"')
          .join('&');
      
      debugPrint('生成订单字符串: $orderString');
      return orderString;
    } catch (e) {
      debugPrint('生成订单字符串失败: $e');
      return '';
    }
  }

  /// Web端支付宝支付
  Future<Map<String, dynamic>> payWithAlipayWeb(String orderString) async {
    try {
      if (kIsWeb) {
        // Web端暂不支持支付宝支付
        return {
          'success': false,
          'message': 'Web端暂不支持支付宝支付',
        };
      }
      
      // 桌面端使用APP支付
      return await payWithAlipay(orderString);
    } catch (e) {
      debugPrint('Web端支付宝支付失败: $e');
      return {
        'success': false,
        'message': 'Web端支付宝支付失败: $e',
      };
    }
  }

  /// 启动支付宝电脑网站支付
  Future<Map<String, dynamic>> launchAlipayWebPayment(String paymentUrl) async {
    try {
      if (kIsWeb) {
        // Web端直接打开支付URL
        if (await canLaunchUrl(Uri.parse(paymentUrl))) {
          await launchUrl(
            Uri.parse(paymentUrl),
            webOnlyWindowName: '_self', // 在当前窗口打开
          );
          return {
            'success': true,
            'message': '正在跳转到支付宝支付页面...',
          };
        } else {
          return {
            'success': false,
            'message': '无法打开支付宝支付页面',
          };
        }
      } else {
        // 桌面端也使用URL启动
        if (await canLaunchUrl(Uri.parse(paymentUrl))) {
          await launchUrl(Uri.parse(paymentUrl));
          return {
            'success': true,
            'message': '正在打开支付宝支付页面...',
          };
        } else {
          return {
            'success': false,
            'message': '无法打开支付宝支付页面',
          };
        }
      }
    } catch (e) {
      debugPrint('启动支付宝Web支付失败: $e');
      return {
        'success': false,
        'message': '启动支付宝Web支付失败: $e',
      };
    }
  }
}
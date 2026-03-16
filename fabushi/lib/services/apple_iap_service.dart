import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Apple IAP 支付服务
/// 仅用于 iOS 端会员充值，其他平台不使用
class AppleIapService {
  static final AppleIapService _instance = AppleIapService._internal();
  factory AppleIapService() => _instance;
  AppleIapService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // IAP Product IDs - 必须和 App Store Connect 里的产品 ID 完全一致
  static const String monthlyProductId = 'monthly';
  static const String quarterlyProductId = 'Quarterly';
  static const String yearlyProductId = 'Annual';

  static const Set<String> _productIds = {
    monthlyProductId,
    quarterlyProductId,
    yearlyProductId,
  };

  // 产品信息缓存
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isInitialized = false;

  // 已处理的交易 ID（防止重复触发后端验证）
  final Set<String> _processedTransactionIds = {};

  // 购买结果回调
  void Function(PurchaseDetails)? onPurchaseSuccess;
  void Function(String error)? onPurchaseError;

  /// 是否为 iOS 平台
  static bool get isAppleIapPlatform {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// 将 priceType 映射到 Product ID
  static String getProductId(String priceType) {
    String result;
    switch (priceType) {
      case 'monthly':
        result = monthlyProductId;
        break;
      case 'quarterly':
        result = quarterlyProductId;
        break;
      case 'yearly':
        result = yearlyProductId;
        break;
      default:
        result = monthlyProductId;
    }
    debugPrint('AppleIapService: getProductId($priceType) -> $result');
    return result;
  }

  /// 初始化 IAP
  Future<bool> initialize() async {
    debugPrint('AppleIapService: 进入 initialize(), 当前 _isInitialized = $_isInitialized');
    if (_isInitialized) {
      debugPrint('AppleIapService: 已经初始化过，跳过基本步骤，但重新尝试加载产品');
      await _loadProducts(); // 即使初始化过，也尝试重新加载一次产品
      return _isAvailable;
    }
    _isInitialized = true;

    try {
      _isAvailable = await _iap.isAvailable();
      debugPrint('AppleIapService: _iap.isAvailable() = $_isAvailable');
      if (!_isAvailable) {
        debugPrint('AppleIapService: IAP 不可用');
        return false;
      }

      // 监听购买更新流
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdated,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          debugPrint('AppleIapService: 购买流错误: $error');
        },
      );

      // 查询可用产品
      await _loadProducts();
    } catch (e) {
      debugPrint('AppleIapService: initialize 过程中发生异常: $e');
      _isInitialized = false; // 出错允许下次重试
    }
    return _isAvailable;
  }

  /// 加载可用产品
  Future<void> _loadProducts() async {
    try {
      debugPrint('AppleIapService: 开始查询产品: $_productIds');
      final response = await _iap.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('AppleIapService: [警告] 未找到产品 (notFoundIDs): ${response.notFoundIDs}');
        debugPrint('这可能意味着: 1. 商品 ID 填写错误; 2. 协议没签署; 3. 没在真机测试; 4. Bundle ID 不匹配');
      }

      if (response.error != null) {
        debugPrint('AppleIapService: [错误] 查询产品出错: ${response.error}');
        return;
      }

      _products = response.productDetails.toList();
      debugPrint('AppleIapService: 成功加载了 ${_products.length} 个产品');
      for (final p in _products) {
        debugPrint('  - 加载成功: ${p.id}: ${p.title} (${p.price})');
      }
    } catch (e) {
      debugPrint('AppleIapService: 加载产品过程中抛出异常: $e');
    }
  }

  /// 获取已加载的产品列表
  List<ProductDetails> get products => _products;

  /// 根据 priceType 获取产品详情
  ProductDetails? getProduct(String priceType) {
    final productId = getProductId(priceType);
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// 发起购买
  Future<bool> purchase(String priceType) async {
    debugPrint('AppleIapService: purchase() 被调用, priceType = $priceType');
    debugPrint('AppleIapService: 当前 _isAvailable = $_isAvailable, 产品数量 = ${_products.length}');

    if (!_isAvailable) {
      debugPrint('AppleIapService: [错误] purchase() 失败，因为 _isAvailable 为 false');
      onPurchaseError?.call('Apple IAP 不可用');
      return false;
    }

    final productId = getProductId(priceType);
    final product = getProduct(priceType);
    debugPrint('AppleIapService: 匹配结果 for $productId -> ${product != null ? "找到" : "未找到"}');

    if (product == null) {
      debugPrint('AppleIapService: [错误] 无法在已加载列表中找到 $productId');
      onPurchaseError?.call('未找到对应的产品信息，请稍后重试');
      return false;
    }

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      // 会员充值使用非消耗型购买
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      debugPrint('AppleIapService: 发起购买: $success');
      return success;
    } catch (e) {
      debugPrint('AppleIapService: 发起购买失败: $e');
      onPurchaseError?.call('发起购买失败: $e');
      return false;
    }
  }

  /// 恢复购买（App Store 审核要求）
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('AppleIapService: 恢复购买失败: $e');
      onPurchaseError?.call('恢复购买失败: $e');
    }
  }

  /// 处理购买更新
  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      debugPrint('AppleIapService: 购买更新 - ${purchase.productID} 状态: ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchase);
          break;
        case PurchaseStatus.error:
          onPurchaseError?.call(purchase.error?.message ?? '购买失败');
          break;
        case PurchaseStatus.canceled:
          onPurchaseError?.call('用户取消购买');
          break;
        case PurchaseStatus.pending:
          debugPrint('AppleIapService: 购买待处理');
          break;
      }

      // 完成交易（必须调用，否则交易会卡住）
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  /// 处理成功的购买
  void _handleSuccessfulPurchase(PurchaseDetails purchase) {
    final txId = purchase.purchaseID;
    
    // 去重：防止同一笔交易被多次处理
    if (txId != null && _processedTransactionIds.contains(txId)) {
      debugPrint('AppleIapService: 交易 $txId 已处理过，跳过重复回调');
      return;
    }
    if (txId != null) {
      _processedTransactionIds.add(txId);
    }
    
    debugPrint('AppleIapService: 购买成功 - ${purchase.productID}');
    debugPrint('AppleIapService: 交易ID: $txId');
    onPurchaseSuccess?.call(purchase);
  }

  /// 获取交易ID（用于 v2 API 通过 transactionId 验证）
  String? getTransactionId(PurchaseDetails purchase) {
    // purchaseID 是 String?，对于 App Store 它包含 transaction identifier
    return purchase.purchaseID;
  }

  /// 释放资源
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    onPurchaseSuccess = null;
    onPurchaseError = null;
  }
}

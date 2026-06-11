class AppleIapService {
  void Function(dynamic purchaseDetails)? onPurchaseSuccess;
  void Function(String error)? onPurchaseError;

  static bool get isAppleIapPlatform => false;

  Future<bool> initialize() async => false;

  Future<bool> purchase(String productId) async {
    onPurchaseError?.call('Apple IAP 不支持 Web 平台');
    return false;
  }

  String? getTransactionId(dynamic purchaseDetails) => null;
}

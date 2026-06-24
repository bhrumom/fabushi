class OpenClawLocalActionResult {
  final String message;
  final Map<String, dynamic> raw;

  const OpenClawLocalActionResult({required this.message, this.raw = const {}});
}

class OpenClawLocalActionExecutor {
  OpenClawLocalActionExecutor._();

  static final OpenClawLocalActionExecutor instance =
      OpenClawLocalActionExecutor._();

  Future<OpenClawLocalActionResult?> tryExecute({
    required String message,
    Map<String, dynamic>? client,
  }) async {
    return null;
  }
}

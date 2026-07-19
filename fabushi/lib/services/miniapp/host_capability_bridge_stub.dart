typedef MiniAppCapabilityProgress = void Function(Map<String, dynamic> update);

class MiniAppHostCapabilityBridge {
  const MiniAppHostCapabilityBridge();

  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> request, {
    required MiniAppCapabilityProgress onProgress,
  }) async {
    return {
      'handled': false,
      'capability': request['capability'],
      'reason': '当前宿主不支持该系统能力',
    };
  }
}

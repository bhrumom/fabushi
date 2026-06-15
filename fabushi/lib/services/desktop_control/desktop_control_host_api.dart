abstract class DesktopControlHostApi {
  Future<Map<String, dynamic>> status();

  Future<Map<String, dynamic>> observe();

  Future<Map<String, dynamic>> screenshot(Map<String, dynamic> arguments);

  Future<Map<String, dynamic>> windows();

  Future<Map<String, dynamic>> click(Map<String, dynamic> arguments);

  Future<Map<String, dynamic>> type(Map<String, dynamic> arguments);

  Future<Map<String, dynamic>> hotkey(Map<String, dynamic> arguments);

  Future<Map<String, dynamic>> scroll(Map<String, dynamic> arguments);
}

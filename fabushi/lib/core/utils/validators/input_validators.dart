class InputValidators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return '请输入邮箱';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return '邮箱格式不正确';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return '请输入密码';
    if (value.length < 6) return '密码至少6位';
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) return '请输入用户名';
    if (value.length < 3) return '用户名至少3位';
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) return '请输入$fieldName';
    return null;
  }
}

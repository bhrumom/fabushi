import 'package:flutter/widgets.dart';

import 'bootstrap/app_bootstrap.dart'
    if (dart.library.html) 'bootstrap/web_bootstrap.dart'
    if (dart.library.io) 'bootstrap/native_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapApplication();
}

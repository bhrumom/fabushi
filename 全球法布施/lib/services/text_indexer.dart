import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextIndexer {
  TextIndexer();

  Future<void> indexAssets() async {
    debugPrint('TextIndexer not supported on web');
  }
}

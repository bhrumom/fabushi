import 'dart:async';

import 'package:flutter/services.dart';

class IncomingSharePayload {
  final String text;
  final String url;
  final String title;
  final String mimeType;
  final String sourcePackage;
  final DateTime receivedAt;

  const IncomingSharePayload({
    required this.text,
    required this.url,
    required this.title,
    required this.mimeType,
    required this.sourcePackage,
    required this.receivedAt,
  });

  factory IncomingSharePayload.fromMap(Map<dynamic, dynamic> map) {
    return IncomingSharePayload(
      text: (map['text'] ?? '').toString(),
      url: (map['url'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      mimeType: (map['mimeType'] ?? '').toString(),
      sourcePackage: (map['sourcePackage'] ?? '').toString(),
      receivedAt: _parseReceivedAt(map['receivedAt']),
    );
  }

  static DateTime _parseReceivedAt(dynamic value) {
    final raw = (value ?? '').toString();
    final parsedIso = DateTime.tryParse(raw);
    if (parsedIso != null) return parsedIso;
    final millis = int.tryParse(raw);
    if (millis != null && millis > 0) {
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return DateTime.now();
  }

  String get bestText {
    if (url.trim().isNotEmpty) return url.trim();
    return text.trim();
  }

  bool get isEmpty => bestText.isEmpty;

  String get displaySource {
    if (sourcePackage.trim().isNotEmpty) return sourcePackage.trim();
    if (mimeType.trim().isNotEmpty) return mimeType.trim();
    return '外部应用';
  }
}

class InboundShareService {
  InboundShareService._();

  static final InboundShareService instance = InboundShareService._();

  static const MethodChannel _channel = MethodChannel(
    'com.ombhrum.fabushi/inbound_share',
  );

  final StreamController<IncomingSharePayload> _incomingController =
      StreamController<IncomingSharePayload>.broadcast();

  bool _started = false;

  Stream<IncomingSharePayload> get incomingShares =>
      _incomingController.stream;

  void start() {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<IncomingSharePayload?> takeInitialShare() async {
    start();
    try {
      final payload = await _channel.invokeMethod<dynamic>('getInitialShare');
      if (payload is Map && payload.isNotEmpty) {
        return IncomingSharePayload.fromMap(payload);
      }
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    return null;
  }

  Future<void> clearInitialShare() async {
    try {
      await _channel.invokeMethod<void>('clearInitialShare');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onIncomingShare') return;
    final args = call.arguments;
    if (args is Map && args.isNotEmpty) {
      final payload = IncomingSharePayload.fromMap(args);
      if (!payload.isEmpty) _incomingController.add(payload);
    }
  }
}

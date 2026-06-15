import 'dart:math';

import 'desktop_control_models.dart';
import 'desktop_control_policy.dart';

class DesktopControlConfirmationStore {
  DesktopControlConfirmationStore({
    this.ttl = const Duration(minutes: 2),
    Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? Random.secure(),
       _clock = clock ?? DateTime.now;

  final Duration ttl;
  final Random _random;
  final DateTime Function() _clock;
  final Map<String, DesktopControlPendingConfirmation> _items = {};

  DesktopControlPendingConfirmation create({
    required String toolName,
    required Map<String, dynamic> arguments,
  }) {
    purgeExpired();
    final now = _clock();
    final item = DesktopControlPendingConfirmation(
      id: _newId(),
      toolName: toolName,
      arguments: Map<String, dynamic>.from(arguments),
      summary: DesktopControlPolicy.summarize(toolName, arguments),
      state: DesktopControlConfirmationState.pending,
      createdAt: now,
      expiresAt: now.add(ttl),
    );
    _items[item.id] = item;
    return item;
  }

  List<DesktopControlPendingConfirmation> list({bool activeOnly = true}) {
    purgeExpired();
    final values = _items.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return activeOnly ? values.where((item) => item.isActive).toList() : values;
  }

  DesktopControlPendingConfirmation? get(String id) {
    purgeExpired();
    return _items[id];
  }

  DesktopControlPendingConfirmation? approve(String id) {
    final item = get(id);
    if (item == null || !item.isActive) return null;
    final approved = item.copyWith(
      state: DesktopControlConfirmationState.approved,
    );
    _items[id] = approved;
    return approved;
  }

  DesktopControlPendingConfirmation? reject(String id) {
    final item = get(id);
    if (item == null) return null;
    final rejected = item.copyWith(
      state: DesktopControlConfirmationState.rejected,
    );
    _items[id] = rejected;
    return rejected;
  }

  bool consumeApproved({
    required String id,
    required String toolName,
    required Map<String, dynamic> arguments,
  }) {
    purgeExpired();
    final item = _items[id];
    if (item == null ||
        item.state != DesktopControlConfirmationState.approved ||
        item.toolName != toolName ||
        !_sameArguments(item.arguments, arguments)) {
      return false;
    }
    _items.remove(id);
    return true;
  }

  void purgeExpired() {
    final now = _clock();
    for (final entry in _items.entries.toList()) {
      if (entry.value.state == DesktopControlConfirmationState.pending &&
          now.isAfter(entry.value.expiresAt)) {
        _items[entry.key] = entry.value.copyWith(
          state: DesktopControlConfirmationState.expired,
        );
      }
    }
  }

  String _newId() {
    final bytes = List<int>.generate(18, (_) => _random.nextInt(256));
    final chars = StringBuffer('confirm_');
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    for (final byte in bytes) {
      chars.write(alphabet[byte % alphabet.length]);
    }
    return chars.toString();
  }

  bool _sameArguments(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (b[entry.key]?.toString() != entry.value?.toString()) return false;
    }
    return true;
  }
}

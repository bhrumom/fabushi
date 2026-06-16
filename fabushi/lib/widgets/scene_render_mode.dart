import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_model.dart';

enum SceneRenderMode { twoD, threeD }

extension SceneRenderModeLabel on SceneRenderMode {
  String get shortLabel {
    return switch (this) {
      SceneRenderMode.twoD => '2D',
      SceneRenderMode.threeD => '3D',
    };
  }
}

class SceneRenderAccess {
  const SceneRenderAccess._();

  static bool canUseThreeD({
    required bool hasPremiumAccess,
    required bool isAdmin,
  }) {
    return hasPremiumAccess || isAdmin;
  }

  static bool canUseThreeDFor(AuthModel? authModel) {
    if (authModel == null) return false;
    return canUseThreeD(
      hasPremiumAccess: authModel.hasPremiumAccess,
      isAdmin: authModel.isAdmin,
    );
  }
}

void showThreeDMemberPrompt(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  final controller = messenger.showSnackBar(
    SnackBar(
      content: const Text('3D 模式为有效会员专享，当前已切换为高性能 2D。'),
      backgroundColor: const Color(0xFF8B6A12),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      dismissDirection: DismissDirection.horizontal,
      action: SnackBarAction(
        label: '开通会员',
        textColor: Colors.white,
        onPressed: () {
          messenger.hideCurrentSnackBar();
          Navigator.pushNamed(context, '/membership');
        },
      ),
    ),
  );

  Timer(const Duration(seconds: 4), () {
    try {
      controller.close();
    } catch (_) {}
  });
}

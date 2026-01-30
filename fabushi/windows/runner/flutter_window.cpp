#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

#include <app_links/app_links_plugin_c_api.h>
// Firebase removed for Windows compatibility
// #include <cloud_firestore/cloud_firestore_plugin_c_api.h>
#include <connectivity_plus/connectivity_plus_windows_plugin.h>
// #include <firebase_auth/firebase_auth_plugin_c_api.h>
// #include <firebase_core/firebase_core_plugin_c_api.h>
#include <flutter_angle/flutter_angle_plugin.h>
#include <flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h>
#include <flutter_sound/flutter_sound_plugin_c_api.h>
#include <flutter_tts/flutter_tts_plugin.h>
#include <flutter_volume_controller/flutter_volume_controller_plugin_c_api.h>
#include <geolocator_windows/geolocator_windows.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>
#include <record_windows/record_windows_plugin_c_api.h>
#include <screen_retriever_windows/screen_retriever_windows_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>
#include <window_manager/window_manager_plugin.h>

void CustomRegisterPlugins(flutter::PluginRegistry* registry) {
  // AppLinksPluginCApiRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("AppLinksPluginCApi"));
  // CloudFirestorePluginCApiRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("CloudFirestorePluginCApi"));
  // ConnectivityPlusWindowsPluginRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("ConnectivityPlusWindowsPlugin"));
  // FirebaseAuthPluginCApiRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("FirebaseAuthPluginCApi"));
  // FirebaseCorePluginCApiRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("FirebaseCorePluginCApi"));
  // FlutterAnglePluginRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("FlutterAnglePlugin"));
  // FlutterInappwebviewWindowsPluginCApiRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("FlutterInappwebviewWindowsPluginCApi"));
  // FlutterSoundPluginCApiRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("FlutterSoundPluginCApi"));
  // FlutterTtsPluginRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("FlutterTtsPlugin"));
  // FlutterVolumeControllerPluginCApiRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("FlutterVolumeControllerPluginCApi"));
  // GeolocatorWindowsRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("GeolocatorWindows"));
  // PermissionHandlerWindowsPluginRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
  // RecordWindowsPluginCApiRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("RecordWindowsPluginCApi"));
  // ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  // UrlLauncherWindowsRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("UrlLauncherWindows"));
  // WindowManagerPluginRegisterWithRegistrar(
  //     registry->GetRegistrarForPlugin("WindowManagerPlugin"));
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  CustomRegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

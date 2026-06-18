#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  app_links
  cloud_firestore
  connectivity_plus
  firebase_auth
  firebase_core
  flutter_inappwebview_windows
  flutter_tts
  flutter_volume_controller
  geolocator_windows
  permission_handler_windows
  record_windows
  rive_common
  screen_retriever_windows
  url_launcher_windows
  window_manager
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  flutter_local_notifications_windows
  sherpa_onnx_windows
)

set(PLUGIN_BUNDLED_LIBRARIES)

add_subdirectory(flutter/ephemeral/.plugin_symlinks/flutter_sound/windows plugins/flutter_sound)
target_link_libraries(${BINARY_NAME} PRIVATE taudio_plugin)
list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:taudio_plugin>)
list(APPEND PLUGIN_BUNDLED_LIBRARIES ${taudio_bundled_libraries})

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)

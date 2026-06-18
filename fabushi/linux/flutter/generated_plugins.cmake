#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  flutter_volume_controller
  gtk
  record_linux
  rive_common
  screen_retriever_linux
  url_launcher_linux
  window_manager
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  sherpa_onnx_linux
)

set(PLUGIN_BUNDLED_LIBRARIES)

add_subdirectory(flutter/ephemeral/.plugin_symlinks/flutter_sound/linux plugins/flutter_sound)
target_link_libraries(${BINARY_NAME} PRIVATE taudio_plugin)
list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:taudio_plugin>)
list(APPEND PLUGIN_BUNDLED_LIBRARIES ${taudio_bundled_libraries})

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/linux plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/linux plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)

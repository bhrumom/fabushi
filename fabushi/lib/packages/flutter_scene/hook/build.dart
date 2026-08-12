import 'package:native_assets_cli/native_assets_cli.dart';

import 'package:flutter_gpu_shaders/build.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {
    // flutter_scene_importer >=0.11 ships generated flatbuffer code and uses a
    // pure-Dart import pipeline. The old generateImporterFlatbufferDart call
    // was CMake-specific and was removed upstream.
    await buildShaderBundleJson(
      buildInput: config,
      buildOutput: output,
      manifestFileName: 'shaders/base.shaderbundle.json',
    );
  });
}

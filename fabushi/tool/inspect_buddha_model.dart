// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_scene_importer/flatbuffer.dart' as fb;

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : null;
  if (path == null || path.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/inspect_buddha_model.dart <downloaded .model path>',
    );
    exitCode = 64;
    return;
  }

  final data = File(path).readAsBytesSync();
  final scene = fb.Scene(data);
  print(
    'scene nodes=${scene.nodes?.length} textures=${scene.textures?.length}',
  );
  if (scene.nodes == null || scene.nodes!.isEmpty) {
    return;
  }

  for (var i = 0; i < scene.nodes!.length; i++) {
    final node = scene.nodes![i];
    final primitives = node.meshPrimitives;
    print('node[$i] name=${node.name} primitives=${primitives?.length}');
    if (primitives == null) continue;
    for (var j = 0; j < primitives.length; j++) {
      final primitive = primitives[j];
      final mat = primitive.material;
      print(
        '  primitive[$j] matType=${mat?.type} '
        'baseColorTexture=${mat?.baseColorTexture} '
        'metallicRoughnessTexture=${mat?.metallicRoughnessTexture} '
        'normalTexture=${mat?.normalTexture} '
        'occlusionTexture=${mat?.occlusionTexture}',
      );
      final color = mat?.baseColorFactor;
      if (color != null) {
        print(
          '    baseColorFactor=${color.r},${color.g},${color.b},${color.a}',
        );
      }
      print('    verticesType=${primitive.vertices.runtimeType}');
    }
  }
}

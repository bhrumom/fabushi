import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_scene_importer/flatbuffer.dart' as fb;
import 'package:vector_math/vector_math.dart' as vector;

/// 模型边界框数据
class ModelBounds {
  final vector.Vector3 min;
  final vector.Vector3 max;

  ModelBounds({required this.min, required this.max});

  /// 几何中心
  vector.Vector3 get center => (min + max) * 0.5;

  /// 尺寸
  vector.Vector3 get size => max - min;

  /// 最大轴尺寸
  double get maxDimension => math.max(size.x, math.max(size.y, size.z));

  @override
  String toString() =>
      'ModelBounds(min: $min, max: $max, size: $size, maxDim: $maxDimension)';
}

/// 3D 模型自动适配工具
///
/// 从 flutter_scene 的 .model (flatbuffer) 文件中解析顶点数据，
/// 计算边界框，并生成适配摄像机视野的变换矩阵。
class ModelAutoFit {
  /// 从 .model flatbuffer 字节数据中计算模型的边界框
  ///
  /// 通过解析 flatbuffer 中所有 Node 的 MeshPrimitive 顶点位置实现。
  /// Unskinned 顶点 = 48 字节 (position 前 12 字节)
  /// Skinned 顶点 = 80 字节 (position 前 12 字节)
  static ModelBounds computeBoundsFromModelBytes(Uint8List bytes) {
    final scene = fb.Scene(bytes);

    double minX = double.infinity,
        minY = double.infinity,
        minZ = double.infinity;
    double maxX = double.negativeInfinity,
        maxY = double.negativeInfinity,
        maxZ = double.negativeInfinity;
    int totalVertices = 0;

    for (final node in scene.nodes ?? <fb.Node>[]) {
      for (final primitive in node.meshPrimitives ?? <fb.MeshPrimitive>[]) {
        final verticesType = primitive.verticesType;
        if (verticesType == null) continue;

        List<int>? rawBytes;
        int vertexCount = 0;
        int vertexStride = 0;

        if (verticesType == fb.VertexBufferTypeId.UnskinnedVertexBuffer) {
          final vb = primitive.vertices as fb.UnskinnedVertexBuffer;
          rawBytes = vb.vertices;
          vertexCount = vb.vertexCount;
          vertexStride = 48; // Vertex struct size
        } else if (verticesType == fb.VertexBufferTypeId.SkinnedVertexBuffer) {
          final vb = primitive.vertices as fb.SkinnedVertexBuffer;
          rawBytes = vb.vertices;
          vertexCount = vb.vertexCount;
          vertexStride = 80; // SkinnedVertex struct size
        }

        if (rawBytes == null || vertexCount == 0) continue;

        // 将 List<int> 转为 ByteData 以便读取 float32
        final byteData = ByteData.sublistView(Uint8List.fromList(rawBytes));

        for (int i = 0; i < vertexCount; i++) {
          final offset = i * vertexStride;
          if (offset + 12 > byteData.lengthInBytes) break;

          final x = byteData.getFloat32(offset, Endian.little);
          final y = byteData.getFloat32(offset + 4, Endian.little);
          final z = byteData.getFloat32(offset + 8, Endian.little);

          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (z < minZ) minZ = z;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
          if (z > maxZ) maxZ = z;
        }

        totalVertices += vertexCount;
      }
    }

    if (totalVertices == 0) {
      debugPrint('⚠️ [ModelAutoFit] 未找到顶点数据，使用默认边界框');
      return ModelBounds(
        min: vector.Vector3(-1, -1, -1),
        max: vector.Vector3(1, 1, 1),
      );
    }

    debugPrint(
      '✅ [ModelAutoFit] 解析完成: $totalVertices 个顶点, '
      'bounds: ($minX, $minY, $minZ) ~ ($maxX, $maxY, $maxZ)',
    );

    return ModelBounds(
      min: vector.Vector3(minX, minY, minZ),
      max: vector.Vector3(maxX, maxY, maxZ),
    );
  }

  /// 根据边界框计算适配变换矩阵
  ///
  /// [bounds] 模型边界框
  /// [targetSize] 目标适配大小（模型缩放后的最大轴尺寸）
  /// [yOffset] Y 轴额外偏移（正值向上，用于视觉微调）
  static vector.Matrix4 computeFitTransform(
    ModelBounds bounds, {
    double targetSize = 150.0,
    double yOffset = 20.0,
    vector.Matrix4? originalTransform,
    double tiltCorrectionX = 0.12,
    double facingCorrectionY = math.pi,
  }) {
    final scale = targetSize / bounds.maxDimension;
    final center = bounds.center;

    debugPrint(
      '📐 [ModelAutoFit] scale=$scale, center=$center, '
      'maxDim=${bounds.maxDimension}',
    );

    return vector.Matrix4.identity()
      ..multiply(originalTransform ?? vector.Matrix4.identity())
      ..rotateY(facingCorrectionY)
      ..rotateX(tiltCorrectionX)
      ..translate(
        -center.x * scale,
        -center.y * scale + yOffset,
        -center.z * scale,
      )
      ..scale(scale, scale, scale);
  }
}

import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as v;

class GlobeMathUtils {
  static const double earthRadius = 1.0;

  // 经纬度转3D坐标
  static v.Vector3 latLngToVector3(double lat, double lng, {double altitude = 0.0}) {
    final phi = (90 - lat) * (math.pi / 180);
    final theta = (lng + 180) * (math.pi / 180);
    final radius = earthRadius + altitude;

    final x = -(radius * math.sin(phi) * math.cos(theta));
    final y = radius * math.cos(phi);
    final z = radius * math.sin(phi) * math.sin(theta);

    return v.Vector3(x, y, z);
  }

  // 计算两点间的大圆距离
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }

  // 计算弧线控制点（用于贝塞尔曲线）
  static v.Vector3 calculateArcControlPoint(
    double startLat,
    double startLng,
    double endLat,
    double endLng, {
    double heightFactor = 0.3,
  }) {
    final distance = calculateDistance(startLat, startLng, endLat, endLng);
    final altitude = math.min(distance * heightFactor / 6371.0, 0.5);

    final midLat = (startLat + endLat) / 2;
    final midLng = (startLng + endLng) / 2;

    return latLngToVector3(midLat, midLng, altitude: altitude);
  }

  // 二次贝塞尔曲线插值
  static v.Vector3 quadraticBezier(v.Vector3 p0, v.Vector3 p1, v.Vector3 p2, double t) {
    final u = 1 - t;
    return (p0 * (u * u)) + (p1 * (2 * u * t)) + (p2 * (t * t));
  }

  // 三次贝塞尔曲线插值（更平滑）
  static v.Vector3 cubicBezier(v.Vector3 p0, v.Vector3 p1, v.Vector3 p2, v.Vector3 p3, double t) {
    final u = 1 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;

    return (p0 * uuu) + (p1 * (3 * uu * t)) + (p2 * (3 * u * tt)) + (p3 * ttt);
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}

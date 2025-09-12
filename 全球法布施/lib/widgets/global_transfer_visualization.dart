class Config {
  static const Map<String, String> countryNames = {
    'US': '美国',
    'CN': '中国',
    'IN': '印度',
    'DE': '德国',
    'FR': '法国',
    'BR': '巴西',
    'RU': '俄罗斯',
    'JP': '日本',
    'KR': '韩国',
    'AU': '澳大利亚',
    // 添加更多国家代码和名称映射
  };
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';
import '../core/locations.dart';
import '../core/config.dart'; // 新增配置导入
import 'package:flutter/services.dart'; // 新增系统服务
import 'dart:math' as math;

class GlobalTransferVisualization extends StatefulWidget {
  final String currentNode;
  final bool showTransferDetails; // 是否显示传输详情

  GlobalTransferVisualization({
    required this.currentNode,
    this.showTransferDetails = true, // 默认显示详情
  });

  @override
  _GlobalTransferVisualizationState createState() =>
      _GlobalTransferVisualizationState();
}

class _GlobalTransferVisualizationState
    extends State<GlobalTransferVisualization> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Particle> particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<FileTransferModel>(context);
    final isActive = model.status == TransferStatus.transferring;
    
    // 强制横屏显示
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  '全球发送可视化',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // 地图可视化部分
            Stack(
              children: [
                SizedBox(
                  height: 200,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          if (isActive && particles.isEmpty) {
                            Future.delayed(Duration.zero, () {
                              setState(() {
                                particles = _createParticles(constraints.biggest);
                              });
                            });
                          } else if (!isActive && particles.isNotEmpty) {
                            Future.delayed(Duration.zero, () {
                              setState(() {
                                particles.clear();
                              });
                            });
                          }
                          
                          for (var particle in particles) {
                            particle.update(_controller.value);
                          }

                          return CustomPaint(
                            painter: GlobalMapPainter(
                              animationValue: _controller.value,
                              isActive: isActive,
                              particles: particles,
                              primaryColor: Theme.of(context).primaryColor,
                              secondaryColor: Theme.of(context).colorScheme.secondary,
                            ),
                            size: Size.infinite,
                          );
                        },
                      );
                    }
                  ),
                ),
                
                // 中心节点图标
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.cloud_upload,
                        size: 20,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // 国家进度
            if (widget.showTransferDetails)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '当前国家: ${Config.countryNames[model.selectedCountry] ?? model.selectedCountry}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: model.countryList.isNotEmpty 
                      ? model.countryList.indexOf(model.selectedCountry) / (model.countryList.length - 1) 
                      : 0,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('开始'),
                      Text('完成'),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 数据传输进度
                  if (model.dataSentInMB > 0 || model.hasFiles)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.file_upload, size: 16),
                            SizedBox(width: 4),
                            Text('文件传输进度'),
                          ],
                        ),
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: model.hasFiles 
                            ? model.dataSentInMB / (model.selectedFiles.first.size / 1024 / 1024) 
                            : 0,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${model.dataSentInMB.toStringAsFixed(2)} MB'),
                            Text('${(model.selectedFiles.first.size / 1024 / 1024).toStringAsFixed(2)} MB'),
                          ],
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  
                  // 网络状态
                  Row(
                    children: [
                      Icon(
                        Icons.cloud,
                        color: isActive ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        isActive ? '正在发送...' : '等待发送',
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            
            // 当前节点信息
            if (widget.currentNode.isNotEmpty && !widget.showTransferDetails)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '当前节点: ${widget.currentNode}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Particle> _createParticles(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final List<Particle> newParticles = [];
    final random = math.Random();

    for (var location in globalLocations) {
      final destination = _latLonToPoint(location.lat, location.lon, size);
      // Create particles with varying characteristics based on the country
      final baseSpeed = random.nextDouble() * 0.005 + 0.005;
      final baseSize = random.nextDouble() * 1.5 + 1;
      
      // Add 3 particles per location with slight variations
      for (int i = 0; i < 3; i++) {
        newParticles.add(Particle(
          start: center,
          end: destination,
          speed: baseSpeed + (i * 0.001),
          size: baseSize + (i * 0.3),
          color: Theme.of(context).colorScheme.secondary.withOpacity(
              0.5 + (random.nextDouble() * 0.3)),
          delay: random.nextDouble() * 19, // delay up to 19 seconds
        ));
      }
    }
    return newParticles;
  }

  Offset _latLonToPoint(double lat, double lon, Size size) {
    // A simple mercator projection
    final x = (lon + 180) * (size.width / 360);
    final latRad = lat * math.pi / 180;
    final mercN = math.log(math.tan((math.pi / 4) + (latRad / 2)));
    final y = (size.height / 2) - (size.width * mercN / (2 * math.pi));
    return Offset(x, y);
  }
}

class Particle {
  final Offset start;
  final Offset end;
  final double speed;
  final double size;
  final Color color;
  final double delay;
  double _progress = 0;
  double _elapsedTime = 0;
  bool _isDelayed = true;

  Particle({
    required this.start,
    required this.end,
    required this.speed,
    required this.size,
    required this.color,
    this.delay = 0,
  });

  void update(double animationValue) {
    _elapsedTime = animationValue * 20; // Match controller duration
    if (_isDelayed && _elapsedTime >= delay) {
      _isDelayed = false;
      _progress = 0;
    }
    
    if (!_isDelayed) {
      _progress += speed;
      if (_progress > 1) {
        _progress = 0;
        _isDelayed = true; // Reset for next cycle
      }
    }
  }

  Offset get currentPosition {
    return Offset.lerp(start, end, _progress)!;
  }
  
  bool get isVisible => !_isDelayed;
}

class GlobalMapPainter extends CustomPainter {
  final double animationValue;
  final bool isActive;
  final List<Particle> particles;
  final Color primaryColor;
  final Color secondaryColor;

  GlobalMapPainter({
    required this.animationValue,
    required this.isActive,
    required this.particles,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    final center = Offset(size.width / 2, size.height / 2);

    final locations = globalLocations
        .map((loc) => _latLonToPoint(loc.lat, loc.lon, size))
        .toList();

    _drawNodes(canvas, size, center, locations);

    if (isActive) {
      _drawTransferLines(canvas, size, center, locations);
      _drawParticles(canvas, size);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 0.5;
    for (int i = 0; i < size.width / 20; i++) {
      canvas.drawLine(Offset(i * 20.0, 0), Offset(i * 20.0, size.height), gridPaint);
    }
    for (int i = 0; i < size.height / 20; i++) {
      canvas.drawLine(Offset(0, i * 20.0), Offset(size.width, i * 20.0), gridPaint);
    }
  }

  Offset _latLonToPoint(double lat, double lon, Size size) {
    final x = (lon + 180) * (size.width / 360);
    final latRad = lat * math.pi / 180;
    final mercN = math.log(math.tan((math.pi / 4) + (latRad / 2)));
    final y = (size.height / 2) - (size.width * mercN / (2 * math.pi));
    return Offset(x, y);
  }

  void _drawNodes(Canvas canvas, Size size, Offset center, List<Offset> nodePoints) {
    final nodePaint = Paint()..color = secondaryColor;
    final pulsePaint = Paint()..color = secondaryColor.withOpacity(0.5);

    // Draw center node (user)
    final centerPulse = (math.sin(animationValue * math.pi * 2) + 1) / 2;
    canvas.drawCircle(center, 8 + centerPulse * 4, pulsePaint);
    canvas.drawCircle(center, 6, nodePaint);

    // Draw destination nodes
    for (var point in nodePoints) {
      final pulse = (math.sin(animationValue * math.pi * 2 + point.dx) + 1) / 2;
      canvas.drawCircle(point, 4 + pulse * 3, pulsePaint);
      canvas.drawCircle(point, 3, nodePaint);
    }
  }

  void _drawTransferLines(Canvas canvas, Size size, Offset center, List<Offset> nodePoints) {
    final linePaint = Paint()
      ..color = secondaryColor.withOpacity(0.3)
      ..strokeWidth = 1.5;
    
    // Add animated pulsing effect to lines
    final pulse = (math.sin(animationValue * math.pi * 2) + 1) / 2;
    linePaint.strokeWidth += pulse * 0.5;

    for (var point in nodePoints) {
      canvas.drawLine(center, point, linePaint);
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    final particlePaint = Paint();
    for (var p in particles) {
      if (p.isVisible) {
        // Add a glow effect to particles
        particlePaint.color = p.color.withOpacity(0.8);
        canvas.drawCircle(p.currentPosition, p.size + 1, particlePaint..color = p.color.withOpacity(0.3));
        canvas.drawCircle(p.currentPosition, p.size, particlePaint..color = p.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GlobalMapPainter oldDelegate) {
    return true;
  }
}
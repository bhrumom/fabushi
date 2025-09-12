import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';
import 'dart:math' as math;

/// 虚空传输可视化组件
/// 
/// 这个组件用于可视化虚空传输的状态，展示数据包如何被发送到"虚空"中
class VoidTransferVisualization extends StatefulWidget {
  const VoidTransferVisualization({Key? key}) : super(key: key);

  @override
  State<VoidTransferVisualization> createState() => _VoidTransferVisualizationState();
}

class _VoidTransferVisualizationState extends State<VoidTransferVisualization> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_DataPacket> _packets = [];
  final math.Random _random = math.Random();
  final int _maxPackets = 50;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
    
    _controller.addListener(_updatePackets);
  }
  
  @override
  void dispose() {
    _controller.removeListener(_updatePackets);
    _controller.dispose();
    super.dispose();
  }
  
  void _updatePackets() {
    final model = Provider.of<FileTransferModel>(context, listen: false);
    
    if (model.status == TransferStatus.transferring && model.isVoidSendEnabled) {
      if (_packets.length < _maxPackets && _random.nextDouble() < 0.3) {
        // 添加新的数据包
        _packets.add(_DataPacket(
          startX: 0.5,
          startY: 0.5,
          angle: _random.nextDouble() * 2 * math.pi,
          speed: _random.nextDouble() * 3 + 1,
          size: _random.nextDouble() * 8 + 4,
          color: _getRandomColor(),
        ));
      }
      
      // 更新现有数据包
      for (int i = _packets.length - 1; i >= 0; i--) {
        final packet = _packets[i];
        packet.update();
        
        // 如果数据包超出边界，移除它
        if (packet.x < -0.1 || packet.x > 1.1 || packet.y < -0.1 || packet.y > 1.1) {
          _packets.removeAt(i);
        }
      }
      
      setState(() {});
    } else if (_packets.isNotEmpty) {
      // 如果不在传输状态，清空所有数据包
      setState(() {
        _packets.clear();
      });
    }
  }
  
  Color _getRandomColor() {
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.purple.shade400,
      Colors.orange.shade400,
      Colors.teal.shade400,
      Colors.pink.shade400,
    ];
    return colors[_random.nextInt(colors.length)];
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<FileTransferModel>(
      builder: (context, model, child) {
        final isActive = model.status == TransferStatus.transferring && model.isVoidSendEnabled;
        
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // 背景网格
              CustomPaint(
                size: const Size(double.infinity, double.infinity),
                painter: _GridPainter(),
              ),
              
              // 数据包
              ...List.generate(_packets.length, (index) {
                final packet = _packets[index];
                return Positioned(
                  left: packet.x * MediaQuery.of(context).size.width,
                  top: packet.y * 200,
                  child: Container(
                    width: packet.size,
                    height: packet.size,
                    decoration: BoxDecoration(
                      color: packet.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: packet.color.withOpacity(0.6),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              
              // 中心发射点
              Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.blue : Colors.grey,
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.6),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ]
                        : null,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              
              // 状态信息
              Positioned(
                left: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '虚空传输',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已发送: ${model.voidSentCount} 文件',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '数据量: ${model.voidDataSentMB.toStringAsFixed(2)} MB',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 状态指示器
              Positioned(
                right: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive ? '活跃' : '待机',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 网格背景绘制器
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    // 绘制水平线
    for (double y = 0; y <= size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    // 绘制垂直线
    for (double x = 0; x <= size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }
  
  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

/// 数据包类
class _DataPacket {
  double x;
  double y;
  final double angle;
  final double speed;
  final double size;
  final Color color;
  
  _DataPacket({
    required double startX,
    required double startY,
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  })  : x = startX,
        y = startY;
  
  void update() {
    x += math.cos(angle) * speed * 0.01;
    y += math.sin(angle) * speed * 0.01;
  }
}
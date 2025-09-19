import 'dart:async';
import 'package:flutter/material.dart';
import '../services/global_transfer_service.dart';
import '../config/dharma_assets.dart';

class GlobalDharmaScreen extends StatefulWidget {
  const GlobalDharmaScreen({super.key});

  @override
  State<GlobalDharmaScreen> createState() => _GlobalDharmaScreenState();
}

class _GlobalDharmaScreenState extends State<GlobalDharmaScreen> {
  final GlobalTransferService _transferService = GlobalTransferService();
  TransferProgress _progress = TransferProgress();
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  late StreamSubscription _progressSubscription;

  // State for asset selection
  final List<Map<String, String>> _allAssets = DHARMA_ASSETS;
  final Set<String> _selectedAssetPaths = {}; // Use path as unique identifier

  bool _loopMode = false;
  double _concurrency = 5.0;

  @override
  void initState() {
    super.initState();
    // Pre-select all assets by default
    for (var asset in _allAssets) {
      _selectedAssetPaths.add(asset['path']!);
    }

    _progressSubscription = _transferService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _progress = progress;
          if (progress.logMessage.isNotEmpty && (_logs.isEmpty || _logs.last != progress.logMessage)) {
            _logs.add(progress.logMessage);
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && _scrollController.position.hasContentDimensions) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    _transferService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startSending() {
    final selectedAssets = _allAssets.where((asset) => _selectedAssetPaths.contains(asset['path'])).toList();
    if (selectedAssets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个要发送的素材'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _logs.clear();
    });
    _transferService.start(
      assets: selectedAssets,
      loop: _loopMode,
      concurrency: _concurrency.toInt(),
    );
  }

  void _stopSending() {
    _transferService.stop();
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedAssetPaths.addAll(_allAssets.map((a) => a['path']!));
      } else {
        _selectedAssetPaths.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isRunning = _progress.status == TransferStatus.running;
    bool allSelected = _selectedAssetPaths.length == _allAssets.length;
    bool isIndeterminate = _selectedAssetPaths.isNotEmpty && !allSelected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🙏 高级全球法布施'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Asset Selection List
          Expanded(
            flex: 2,
            child: Card(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: Text('选择素材 (${_selectedAssetPaths.length}/${_allAssets.length})'),
                    value: allSelected,
                    tristate: true,
                    onChanged: isRunning ? null : _toggleSelectAll,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _allAssets.length,
                      itemBuilder: (context, index) {
                        final asset = _allAssets[index];
                        final path = asset['path']!;
                        final isSelected = _selectedAssetPaths.contains(path);
                        return CheckboxListTile(
                          title: Text(asset['name']!),
                          subtitle: Text(path, style: Theme.of(context).textTheme.bodySmall),
                          value: isSelected,
                          onChanged: isRunning ? null : (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedAssetPaths.add(path);
                              } else {
                                _selectedAssetPaths.remove(path);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Controls and Logs
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Control Area
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('开始'),
                                onPressed: isRunning ? null : _startSending,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.stop),
                                label: const Text('停止'),
                                onPressed: isRunning ? _stopSending : null,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              ),
                            ],
                          ),
                          SwitchListTile(
                            title: const Text('循环发送'),
                            value: _loopMode,
                            onChanged: isRunning ? null : (value) => setState(() => _loopMode = value),
                          ),
                          Row(
                            children: [
                              const Text('并发数:'),
                              Expanded(
                                child: Slider(
                                  value: _concurrency,
                                  min: 1,
                                  max: 20,
                                  divisions: 19,
                                  label: _concurrency.round().toString(),
                                  onChanged: isRunning ? null : (value) {
                                    setState(() {
                                      _concurrency = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress and Logs
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('实时日志', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Text(
                                    _logs[index],
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
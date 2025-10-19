import 'package:flutter/foundation.dart';

class PracticeSession {
  final String sutraName;
  final DateTime startTime;
  DateTime? endTime;
  int count;
  
  PracticeSession({
    required this.sutraName,
    required this.startTime,
    this.endTime,
    this.count = 0,
  });
  
  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
}

class PracticeModel extends ChangeNotifier {
  PracticeSession? _currentSession;
  final List<PracticeSession> _history = [];
  
  PracticeSession? get currentSession => _currentSession;
  List<PracticeSession> get history => List.unmodifiable(_history);
  
  int get totalCount => _history.fold(0, (sum, s) => sum + s.count);
  Duration get totalDuration => _history.fold(Duration.zero, (sum, s) => sum + s.duration);
  
  void startSession(String sutraName) {
    _currentSession = PracticeSession(sutraName: sutraName, startTime: DateTime.now());
    notifyListeners();
  }
  
  void incrementCount() {
    if (_currentSession != null) {
      _currentSession!.count++;
      notifyListeners();
    }
  }
  
  void endSession() {
    if (_currentSession != null) {
      _currentSession!.endTime = DateTime.now();
      _history.add(_currentSession!);
      _currentSession = null;
      notifyListeners();
    }
  }
}

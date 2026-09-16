import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, Process, File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Telemetry state received from OpenCV Attention Tracker
class AttentionState {
  final bool isTracking;
  final bool isAttentive;
  final bool alertNeeded;
  final double attentionPercentage;
  final String gazeDirection;
  final bool faceDetected;
  final bool eyesDetected;
  final double attentiveSeconds;
  final double distractedSeconds;
  final double totalSeconds;
  final int distractionCount;
  final bool isConnected;

  const AttentionState({
    this.isTracking = false,
    this.isAttentive = true,
    this.alertNeeded = false,
    this.attentionPercentage = 100.0,
    this.gazeDirection = 'CENTER',
    this.faceDetected = false,
    this.eyesDetected = false,
    this.attentiveSeconds = 0.0,
    this.distractedSeconds = 0.0,
    this.totalSeconds = 0.0,
    this.distractionCount = 0,
    this.isConnected = false,
  });

  factory AttentionState.fromJson(Map<String, dynamic> json, {bool isConnected = true}) {
    return AttentionState(
      isTracking: json['is_tracking'] == true,
      isAttentive: json['is_attentive'] == true,
      alertNeeded: json['alert_needed'] == true,
      attentionPercentage: (json['attention_percentage'] as num?)?.toDouble() ?? 100.0,
      gazeDirection: (json['gaze_direction'] as String?) ?? 'CENTER',
      faceDetected: json['face_detected'] == true,
      eyesDetected: json['eyes_detected'] == true,
      attentiveSeconds: (json['attentive_seconds'] as num?)?.toDouble() ?? 0.0,
      distractedSeconds: (json['distracted_seconds'] as num?)?.toDouble() ?? 0.0,
      totalSeconds: (json['total_seconds'] as num?)?.toDouble() ?? 0.0,
      distractionCount: (json['distraction_count'] as num?)?.toInt() ?? 0,
      isConnected: isConnected,
    );
  }

  factory AttentionState.disconnected() {
    return const AttentionState(
      isTracking: false,
      isAttentive: true,
      alertNeeded: false,
      attentionPercentage: 100.0,
      gazeDirection: 'OFFLINE',
      isConnected: false,
    );
  }
}

/// Final attention metrics summary upon assessment completion
class AttentionSummary {
  final double attentionPercentage;
  final double attentiveSeconds;
  final double distractedSeconds;
  final double totalSeconds;
  final int distractionCount;

  const AttentionSummary({
    required this.attentionPercentage,
    required this.attentiveSeconds,
    required this.distractedSeconds,
    required this.totalSeconds,
    required this.distractionCount,
  });

  factory AttentionSummary.fromJson(Map<String, dynamic> json) {
    return AttentionSummary(
      attentionPercentage: (json['attention_percentage'] as num?)?.toDouble() ?? 100.0,
      attentiveSeconds: (json['attentive_seconds'] as num?)?.toDouble() ?? 0.0,
      distractedSeconds: (json['distracted_seconds'] as num?)?.toDouble() ?? 0.0,
      totalSeconds: (json['total_seconds'] as num?)?.toDouble() ?? 0.0,
      distractionCount: (json['distraction_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory AttentionSummary.defaultFallback({double fallbackPercentage = 100.0}) {
    return AttentionSummary(
      attentionPercentage: fallbackPercentage,
      attentiveSeconds: 0.0,
      distractedSeconds: 0.0,
      totalSeconds: 0.0,
      distractionCount: 0,
    );
  }
}

/// Service managing communication between Flutter and the OpenCV Attention Tracker server
class AttentionTrackerService {
  AttentionTrackerService._internal();
  static final AttentionTrackerService instance = AttentionTrackerService._internal();

  static const String baseUrl = 'http://127.0.0.1:8008';

  final StreamController<AttentionState> _stateController =
      StreamController<AttentionState>.broadcast();
  Stream<AttentionState> get stream => _stateController.stream;

  AttentionState _currentState = const AttentionState();
  AttentionState get currentState => _currentState;

  Timer? _pollingTimer;
  bool _isPolling = false;
  bool _isServerAvailable = false;
  bool get isServerAvailable => _isServerAvailable;

  /// Check if the local OpenCV Python server is running
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(milliseconds: 1200));
      _isServerAvailable = (response.statusCode == 200);
      return _isServerAvailable;
    } catch (_) {
      _isServerAvailable = false;
      return false;
    }
  }

  /// Attempts to automatically start the OpenCV Python backend on Windows desktop if not already running
  Future<void> _maybeAutoLaunchServerOnWindows() async {
    if (kIsWeb) return;
    try {
      if (Platform.isWindows) {
        final bool healthy = await checkHealth();
        if (!healthy) {
          debugPrint('[AttentionTracker] Server offline. Searching for Python OpenCV backend...');
          final List<String> possiblePaths = [
            r'C:\Users\janha\Documents\neurol\NeuroLearn\attention_tracker\server.py',
            '../attention_tracker/server.py',
            'attention_tracker/server.py',
            '../../attention_tracker/server.py',
            '../../../attention_tracker/server.py',
            '../../../../attention_tracker/server.py',
          ];
          for (final path in possiblePaths) {
            final file = File(path);
            if (file.existsSync()) {
              debugPrint('[AttentionTracker] Found server script at: ${file.path}');
              try {
                Process.start(
                  'python',
                  ['server.py', '--port', '8008'],
                  workingDirectory: file.parent.path,
                  runInShell: true,
                );
                debugPrint('[AttentionTracker] Launched process successfully in: ${file.parent.path}');
                break;
              } catch (err) {
                debugPrint('[AttentionTracker] Process.start error: $err');
              }
            }
          }
          // Give the server up to 4 seconds to initialize
          for (int i = 0; i < 8; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (await checkHealth()) {
              debugPrint('[AttentionTracker] Python backend connected successfully!');
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AttentionTracker] Error during auto-launch check: $e');
    }
  }

  /// Starts the tracking session and begins polling telemetry
  Future<bool> startTracking() async {
    await _maybeAutoLaunchServerOnWindows();
    final bool available = await checkHealth();

    if (!available) {
      debugPrint('[AttentionTracker] Server not reachable at $baseUrl. Tracker offline.');
      _currentState = AttentionState.disconnected();
      _stateController.add(_currentState);
      return false;
    }

    try {
      final response = await http.post(Uri.parse('$baseUrl/start')).timeout(
            const Duration(seconds: 4),
          );
      if (response.statusCode == 200) {
        _startPolling();
        return true;
      }
    } catch (e) {
      debugPrint('[AttentionTracker] Error starting tracking session: $e');
    }
    return false;
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _isPolling = true;
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 350), (_) async {
      if (!_isPolling) return;
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/status'))
            .timeout(const Duration(milliseconds: 800));
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          _currentState = AttentionState.fromJson(data, isConnected: true);
          _stateController.add(_currentState);
        }
      } catch (_) {
        // Transient network jitter or offline
      }
    });
  }

  /// Manually resets the alert state on the server (e.g. child tapped 'I am looking')
  Future<void> resetAlert() async {
    try {
      await http
          .post(Uri.parse('$baseUrl/reset_alert'))
          .timeout(const Duration(milliseconds: 600));
    } catch (_) {}
    // Clear locally immediately
    _currentState = AttentionState(
      isTracking: _currentState.isTracking,
      isAttentive: true,
      alertNeeded: false,
      attentionPercentage: _currentState.attentionPercentage,
      gazeDirection: _currentState.gazeDirection,
      faceDetected: _currentState.faceDetected,
      eyesDetected: _currentState.eyesDetected,
      attentiveSeconds: _currentState.attentiveSeconds,
      distractedSeconds: _currentState.distractedSeconds,
      totalSeconds: _currentState.totalSeconds,
      distractionCount: _currentState.distractionCount,
      isConnected: _currentState.isConnected,
    );
    _stateController.add(_currentState);
  }

  /// Stops tracking session and retrieves final summary
  Future<AttentionSummary> stopTracking() async {
    _isPolling = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;

    try {
      final response = await http
          .post(Uri.parse('$baseUrl/stop'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final Map<String, dynamic> summaryJson = data['summary'] ?? {};
        return AttentionSummary.fromJson(summaryJson);
      }
    } catch (e) {
      debugPrint('[AttentionTracker] Error stopping session: $e');
    }

    return AttentionSummary.defaultFallback(
      fallbackPercentage: _currentState.attentionPercentage,
    );
  }

  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
  }
}

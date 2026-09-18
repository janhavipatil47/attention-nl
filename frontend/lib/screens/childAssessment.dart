import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/age_calculator_service.dart';
import '../services/assessment_report_service.dart';
import '../services/attention_tracker_service.dart';
import 'report.dart';

const Duration _shakeDuration = Duration(milliseconds: 600);

class ChildAssessmentScreen extends StatefulWidget {
  const ChildAssessmentScreen({super.key});

  @override
  State<ChildAssessmentScreen> createState() => _ChildAssessmentScreenState();
}

class _ChildAssessmentScreenState extends State<ChildAssessmentScreen>
    with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  late AnimationController _shakeController;

  int _childAge = 3;
  bool _ageLoaded = false;

  int? _soundMatchChoice;
  int? _rhymeChoice;
  int? _animalChoice;
  int? _picturePairChoice;

  int? _writingWizardLetter;
  double _writingWizardProgress = 0.0;
  int _tracingPathPoints = 0;
  Set<int> _busyShapesPlaced = <int>{};
  bool _drawingStarted = false;

  final Set<int> _countTapped = <int>{};
  int? _dotsChoice;
  int? _sizeChoice;
  int? _sequenceChoice;

  final Set<int> _dinoFedItems = <int>{};
  
  // New games variables
  String? _selectedColorForFish;
  Set<String> _gardenColored = <String>{};
  int? _missingLetterChoice;
  double? _arrowTracingProgress;
  bool _circleCreationStarted = false;
  double _circleCompletionPercent = 0.0;
  Set<int> _numberDragDropPlaced = <int>{};
  Set<int> _patternDragPlaced = <int>{};
  bool _isFinalizing = false;
  final DateTime _assessmentStartedAt = DateTime.now();

  final Map<String, int> _activityAttempts = <String, int>{};
  final Map<String, int> _correctAnswers = <String, int>{};

  void _recordAttempt(String activityId, bool isCorrect) {
    setState(() {
      _activityAttempts[activityId] = (_activityAttempts[activityId] ?? 0) + 1;
      if (isCorrect) {
        _correctAnswers[activityId] = (_correctAnswers[activityId] ?? 0) + 1;
      }
    });
  }

  StreamSubscription<AttentionState>? _attentionSubscription;
  bool _isAlertShowing = false;
  DateTime? _lastAlertShownTime;
  AttentionState _currentAttention = const AttentionState();
  AttentionSummary? _finalAttentionSummary;
  bool _isConnectingTracker = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(duration: _shakeDuration, vsync: this)
      ..repeat();
    _setupTts();
    _loadChildAge();
    _initAttentionTracking();
  }

  Future<void> _initAttentionTracking() async {
    final bool ok = await AttentionTrackerService.instance.startTracking();
    if (!ok && mounted) {
      debugPrint('[ChildAssessment] OpenCV tracker not currently running.');
    }
    _attentionSubscription = AttentionTrackerService.instance.stream.listen(
      _handleAttentionUpdate,
    );
  }

  Future<void> _retryStartTracker() async {
    setState(() => _isConnectingTracker = true);
    final bool success = await AttentionTrackerService.instance.startTracking();
    if (mounted) {
      setState(() => _isConnectingTracker = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not connect to OpenCV tracker. Please run: python attention_tracker/server.py in terminal.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _handleAttentionUpdate(AttentionState state) {
    if (!mounted) return;
    setState(() {
      _currentAttention = state;
    });

    if (state.alertNeeded && !_isAlertShowing) {
      final DateTime now = DateTime.now();
      if (_lastAlertShownTime == null ||
          now.difference(_lastAlertShownTime!).inSeconds >= 30) {
        _showAlertPopup();
      }
    } else if (!state.alertNeeded && _isAlertShowing) {
      _dismissAlertPopup();
    }
  }

  void _dismissAlertPopup() {
    if (_isAlertShowing && mounted) {
      _isAlertShowing = false;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _showAlertPopup() {
    if (_isAlertShowing || !mounted) return;
    _isAlertShowing = true;
    _lastAlertShownTime = DateTime.now();
    _speak('Look at the screen!');

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 12,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFC107), width: 2.5),
                  ),
                  child: const Center(
                    child: Text('👀', style: TextStyle(fontSize: 42)),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Look at the Screen!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B47),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Hey there! Please keep your eyes on the screen so you don\'t miss the fun! ⭐',
                  style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.3),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () {
                    _lastAlertShownTime = DateTime.now();
                    AttentionTrackerService.instance.resetAlert();
                    _dismissAlertPopup();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6E56CF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    "I'm Looking!",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isAlertShowing = false;
      _lastAlertShownTime = DateTime.now();
    });
  }

  Future<void> _setupTts() async {
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _loadChildAge() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ChildAgeResult? ageResult = AgeCalculatorService.getAgeResultFromPrefs(prefs);
    final int parsedAge = ageResult?.years ?? prefs.getInt('childAgeValue') ?? 3;

    if (!mounted) {
      return;
    }

    setState(() {
      _childAge = parsedAge;
      _ageLoaded = true;
    });
  }

  bool get _isAge45 => _childAge >= 3 && _childAge <= 5;

  int get _countTarget => _isAge45 ? 5 : 3;

  int get _dinoTarget => _isAge45 ? 4 : 3;

  bool get _isDinoHappy => _dinoFedItems.length >= _dinoTarget;

  int get _attemptedCount {
    final List<bool> attempted = <bool>[
      _soundMatchChoice != null,
      _rhymeChoice != null,
      _animalChoice != null,
      _picturePairChoice != null,
      _writingWizardProgress > 0,
      _busyShapesPlaced.isNotEmpty,
      _gardenColored.isNotEmpty,
      _missingLetterChoice != null,
      _arrowTracingProgress != null,
      _circleCompletionPercent > 0,
      _dinoFedItems.isNotEmpty,
      _countTapped.isNotEmpty,
      _dotsChoice != null,
      _sizeChoice != null,
      _sequenceChoice != null,
    ];
    return attempted.where((a) => a).length;
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Widget _buildShakingDino() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final double wave =
            math.sin(_shakeController.value * 2 * math.pi) * 4;
        final double offsetX = _isDinoHappy ? 0 : wave;
        return Transform.translate(offset: Offset(offsetX, 0), child: child);
      },
      child: Text(
        _isDinoHappy ? '🦖😄' : '🦖😣',
        style: const TextStyle(fontSize: 32),
      ),
    );
  }

  @override
  void dispose() {
    _attentionSubscription?.cancel();
    AttentionTrackerService.instance.stopTracking();
    _tts.stop();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ageLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String ageLabel = _isAge45 ? '4-5 Years' : '3 Years';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black54),
        title: const Column(
          children: [
            Text(
              'Child Assessment',
              style: TextStyle(
                color: Color(0xFF1A2B47),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Interactive Activities',
              style: TextStyle(color: Colors.purple, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _currentAttention.isConnected
                      ? (_currentAttention.attentionPercentage >= 75
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0))
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _currentAttention.isConnected
                        ? (_currentAttention.attentionPercentage >= 75
                            ? const Color(0xFF81C784)
                            : const Color(0xFFFFB74D))
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.remove_red_eye_rounded,
                      size: 14,
                      color: _currentAttention.isConnected
                          ? (_currentAttention.attentionPercentage >= 75
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE65100))
                          : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentAttention.isConnected
                          ? '${_currentAttention.attentionPercentage.toStringAsFixed(0)}%'
                          : 'Tracker',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _currentAttention.isConnected
                            ? (_currentAttention.attentionPercentage >= 75
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE65100))
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Play and Learn (3 - 5 Years)',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2B47),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Attempted $_attemptedCount of 12 activities',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          _buildTrackerStatusBanner(),
          const SizedBox(height: 8),
          _sectionCard(
            title: 'Listening Activities',
            subtitle: _isAge45
                ? 'Age 3-5 set with upgraded challenges.'
                : 'Age 3 set (kept as designed).',
            color: const Color(0xFFEAF4FF),
            children: [
              _soundMatchCard(),
              _rhymeCard(),
              _animalSoundCard(),
              _picturePairCard(),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Writing & Motor Skills 🎮',
            subtitle: _isAge45 ? 'Dysgraphia Games - Building handwriting confidence.' : 'Age 3: Simple drawing and motor activities.',
            color: const Color(0xFFFFF3E6),
            children: _isAge45
                ? [
                    _writingWizardCard(),
                    _busyShapesCard(),
                    _drawingForKidsCard(),
                    _missingLetterCard(),
                    _arrowTracingCard(),
                    _circleCreationCard(),
                    _dinoFeedingCard(),
                  ]
                : [
                    // Writing games removed
                  ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Math Activities',
            subtitle: _isAge45
                ? 'Age 3-5 set with upgraded challenges.'
                : 'Age 3 set (kept as designed).',
            color: const Color(0xFFEAFBEF),
            children: [
              _countObjectsCard(),
              _findDotsCard(),
              _sizeCard(),
              _sequenceCard(),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isFinalizing ? null : _completeAssessment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6E56CF),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(_isFinalizing ? 'Generating Report...' : 'Complete Assessment'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTrackerStatusBanner() {
    final bool isLive = _currentAttention.isConnected && _currentAttention.isTracking;

    if (isLive) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF81C784), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'OpenCV Camera Tracker: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'ACTIVE 🟢',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Gaze: ${_currentAttention.gazeDirection}  •  Attention: ${_currentAttention.attentionPercentage.toStringAsFixed(0)}%  •  Alerts: ${_currentAttention.distractionCount}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.videocam_off, color: Color(0xFFE65100), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Camera Tracker is NOT Connected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                      fontSize: 13,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isConnectingTracker ? null : _retryStartTracker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6E56CF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(_isConnectingTracker ? 'Starting...' : 'Connect Camera'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Start tracker to track gaze & trigger look-away alerts: run "python attention_tracker/server.py" or double-click "start_tracker.bat".',
              style: TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _completeAssessment() async {
    setState(() => _isFinalizing = true);
    try {
      // Stop OpenCV attention tracker and retrieve session metrics
      try {
        _finalAttentionSummary = await AttentionTrackerService.instance.stopTracking();
      } catch (e) {
        debugPrint('Error stopping attention tracker: $e');
      }

      final Map<String, double> skillScores = _calculateDomainScores();
      final Map<String, dynamic> rawMetrics = _buildRawMetrics();
      final Map<String, String> skillLabels = <String, String>{
        'reading_language': 'Reading & Language',
        'listening': 'Listening',
        'writing_tracing': 'Writing & Tracing',
        'math': 'Math & Number Sense',
        'attention': 'Attention & Focus',
        'memory': 'Memory & Matching',
      };
      final List<String> assessedActivities = _isAge45
          ? <String>[
              'Sound Match',
              'Rhyme Match',
              'Animal Sound',
              'Picture Pair',
              'Writing Wizard',
              'Busy Shapes',
              'Color Garden',
              'Missing Letter',
              'Arrow Tracing',
              'Circle Creation',
              'Dino Feeding',
              'Count Objects',
              'Find Dots',
              'Size Comparison',
              'Number Sequence',
            ]
          : <String>[
              'Sound Match',
              'Rhyme Match',
              'Animal Sound',
              'Picture Pair',
              'Writing Wizard',
              'Busy Shapes',
              'Color Garden',
              'Missing Letter',
              'Count Objects',
              'Find Dots',
              'Size Comparison',
              'Number Sequence',
            ];

      final String reportId = await AssessmentReportService.createAssessmentReport(
        assessmentType: 'age_3_to_5',
        childAge: _childAge,
        skillScores: skillScores,
        skillLabels: skillLabels,
        assessedActivities: assessedActivities,
        rawMetrics: rawMetrics,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (BuildContext context) => ReportScreen(reportId: reportId)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate report: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isFinalizing = false);
      }
    }
  }

  Map<String, double> _calculateDomainScores() {
    final int motorTarget = _isAge45 ? 4 : 3;

    final double? soundScore = _soundMatchChoice != null ? _choiceScore(_soundMatchChoice, 0) : null;
    final double? rhymeScore = _rhymeChoice != null ? _choiceScore(_rhymeChoice, 0) : null;
    final double? animalScore = _animalChoice != null ? _choiceScore(_animalChoice, 0) : null;
    final double? picturePairScore = _picturePairChoice != null ? _choiceScore(_picturePairChoice, 0) : null;
    final double? missingLetterScore = _missingLetterChoice != null ? _choiceScore(_missingLetterChoice, 0) : null;

    final double? writingWizardScore = _writingWizardProgress > 0 ? _clamp(_writingWizardProgress * 100) : null;
    final double? busyShapesScore = _busyShapesPlaced.isNotEmpty ? _clamp((_busyShapesPlaced.length / motorTarget) * 100) : null;
    final double? gardenScore = _gardenColored.isNotEmpty ? _clamp((_gardenColored.length / motorTarget) * 100) : null;
    final double? arrowScore = _arrowTracingProgress != null ? _clamp((_arrowTracingProgress ?? 0) * 100) : null;
    final double? circleScore = _circleCompletionPercent > 0 ? _clamp(_circleCompletionPercent * 100) : null;

    final double? countScore = _countTapped.isNotEmpty ? _clamp((_countTapped.length / _countTarget) * 100) : null;
    final double? dotsScore = _dotsChoice != null ? _choiceScore(_dotsChoice, 1) : null;
    final double? sizeScore = _sizeChoice != null ? _choiceScore(_sizeChoice, 0) : null;

    final double? sequenceScore = _sequenceChoice != null ? _choiceScore(_sequenceChoice, 1) : null;
    final double? dinoScore = _dinoFedItems.isNotEmpty ? _clamp((_dinoFedItems.length / _dinoTarget) * 100) : null;

    double averageNonNull(List<double?> list, double fallback) {
      final List<double> valid = list.whereType<double>().toList();
      if (valid.isEmpty) return fallback;
      return _average(valid);
    }

    final double listeningScore = averageNonNull([soundScore, animalScore], 0);
    final double readingLanguageScore = averageNonNull([rhymeScore, picturePairScore, missingLetterScore], 0);
    final double writingScore = averageNonNull([writingWizardScore, busyShapesScore, gardenScore, arrowScore, circleScore], 0);
    final double mathScore = averageNonNull([countScore, dotsScore, sizeScore], 0);
    final double memoryScore = sequenceScore ?? 0;

    final double fallbackAttention = dinoScore ?? _clamp(((_attemptedCount / 15) * 100 * 0.5));
    final double attentionScore = (_finalAttentionSummary != null && _finalAttentionSummary!.totalSeconds > 0)
        ? _clamp(_finalAttentionSummary!.attentionPercentage)
        : fallbackAttention;

    return <String, double>{
      'reading_language': _clamp(readingLanguageScore),
      'writing_tracing': _clamp(writingScore),
      'math': _clamp(mathScore),
      'attention': _clamp(attentionScore),
      'memory': _clamp(memoryScore),
      'listening': _clamp(listeningScore),
    };
  }

  Map<String, dynamic> _buildRawMetrics() {
    final int completedActivities = <bool>[
      _soundMatchChoice != null,
      _rhymeChoice != null,
      _animalChoice != null,
      _picturePairChoice != null,
      _writingWizardProgress >= 0.6,
      _busyShapesPlaced.isNotEmpty,
      _gardenColored.isNotEmpty,
      _missingLetterChoice != null,
      (_arrowTracingProgress ?? 0) > 0,
      _circleCompletionPercent >= 0.6,
      _dinoFedItems.isNotEmpty,
      _countTapped.isNotEmpty,
      _dotsChoice != null,
      _sizeChoice != null,
      _sequenceChoice != null,
    ].where((bool done) => done).length;
    final int sessionDurationSeconds =
        DateTime.now().difference(_assessmentStartedAt).inSeconds;

    final double soundScore = _choiceScore(_soundMatchChoice, 0);
    final double rhymeScore = _choiceScore(_rhymeChoice, 0);
    final double animalScore = _choiceScore(_animalChoice, 0);
    final double picturePairScore = _choiceScore(_picturePairChoice, 0);
    final double missingLetterScore = _choiceScore(_missingLetterChoice, 0);

    final int motorTarget = _isAge45 ? 4 : 3;
    final double writingWizardScore = _clamp(_writingWizardProgress * 100);
    final double busyShapesScore = _clamp((_busyShapesPlaced.length / motorTarget) * 100);
    final double gardenScore = _clamp((_gardenColored.length / motorTarget) * 100);
    final double arrowScore = _clamp((_arrowTracingProgress ?? 0) * 100);
    final double circleScore = _clamp(_circleCompletionPercent * 100);

    final double countScore = _clamp((_countTapped.length / _countTarget) * 100);
    final double dotsScore = _choiceScore(_dotsChoice, 1);
    final double sizeScore = _choiceScore(_sizeChoice, 0);
    final double sequenceScore = _choiceScore(_sequenceChoice, 1);
    final double dinoScore = _clamp((_dinoFedItems.length / _dinoTarget) * 100);

    final double objectiveAccuracy = _average(<double>[
      soundScore,
      rhymeScore,
      animalScore,
      picturePairScore,
      dotsScore,
      sizeScore,
      sequenceScore,
      missingLetterScore,
    ]);

    return <String, dynamic>{
      'completedActivities': completedActivities,
      'totalActivities': 15,
      'measuredActivities': 8,
      'answeredMeasuredActivities': <bool>[
        _soundMatchChoice != null,
        _rhymeChoice != null,
        _animalChoice != null,
        _picturePairChoice != null,
        _dotsChoice != null,
        _sizeChoice != null,
        _sequenceChoice != null,
        _missingLetterChoice != null,
      ].where((bool v) => v).length,
      'consistencyScore': _clamp(60 + (_attemptedCount / 15) * 35),
      'objectiveAccuracy': objectiveAccuracy,
      'sessionDurationSeconds': sessionDurationSeconds,
      'attemptedActivities': _attemptedCount,
      'writingWizardProgress': (_writingWizardProgress * 100).round(),
      'circleCompletionPercent': (_circleCompletionPercent * 100).round(),
      'attentionPercentage': _finalAttentionSummary?.attentionPercentage ?? 100.0,
      'attentiveSeconds': _finalAttentionSummary?.attentiveSeconds ?? 0.0,
      'distractedSeconds': _finalAttentionSummary?.distractedSeconds ?? 0.0,
      'totalAttentionTrackedSeconds': _finalAttentionSummary?.totalSeconds ?? 0.0,
      'distractionCount': _finalAttentionSummary?.distractionCount ?? 0,
      'openCvAttentionTracked': (_finalAttentionSummary != null && _finalAttentionSummary!.totalSeconds > 0),
      'adaptiveLearning': <String, dynamic>{
        'selectedLevels': <String, int>{
          'sound_match': 1,
          'rhyme_match': 1,
          'animal_sound': 1,
          'picture_pair': 1,
          'writing_wizard': 1,
          'busy_shapes': 1,
          'garden': 1,
          'missing_letter': 1,
          'arrow_tracing': 1,
          'circle_creation': 1,
          'dino_feeding': 1,
          'count_objects': 1,
          'find_dots': 1,
          'size_choice': 1,
          'sequence_choice': 1,
        },
        'unlockedLevels': <String, int>{
          'sound_match': 1,
          'rhyme_match': 1,
          'animal_sound': 1,
          'picture_pair': 1,
          'writing_wizard': 1,
          'busy_shapes': 1,
          'garden': 1,
          'missing_letter': 1,
          'arrow_tracing': 1,
          'circle_creation': 1,
          'dino_feeding': 1,
          'count_objects': 1,
          'find_dots': 1,
          'size_choice': 1,
          'sequence_choice': 1,
        },
        'accuracy': <String, double>{
          'sound_match': soundScore,
          'rhyme_match': rhymeScore,
          'animal_sound': animalScore,
          'picture_pair': picturePairScore,
          'writing_wizard': writingWizardScore,
          'busy_shapes': busyShapesScore,
          'garden': gardenScore,
          'missing_letter': missingLetterScore,
          'arrow_tracing': arrowScore,
          'circle_creation': circleScore,
          'dino_feeding': dinoScore,
          'count_objects': countScore,
          'find_dots': dotsScore,
          'size_choice': sizeScore,
          'sequence_choice': sequenceScore,
        },
        'attempts': <String, int>{
          'sound_match': _activityAttempts['sound_match'] ?? (_soundMatchChoice != null ? 1 : 0),
          'rhyme_match': _activityAttempts['rhyme_match'] ?? (_rhymeChoice != null ? 1 : 0),
          'animal_sound': _activityAttempts['animal_sound'] ?? (_animalChoice != null ? 1 : 0),
          'picture_pair': _activityAttempts['picture_pair'] ?? (_picturePairChoice != null ? 1 : 0),
          'writing_wizard': _activityAttempts['writing_wizard'] ?? (_writingWizardProgress > 0 ? 1 : 0),
          'busy_shapes': _activityAttempts['busy_shapes'] ?? (_busyShapesPlaced.isNotEmpty ? 1 : 0),
          'garden': _activityAttempts['garden'] ?? (_gardenColored.isNotEmpty ? 1 : 0),
          'missing_letter': _activityAttempts['missing_letter'] ?? (_missingLetterChoice != null ? 1 : 0),
          'arrow_tracing': _activityAttempts['arrow_tracing'] ?? ((_arrowTracingProgress ?? 0) > 0 ? 1 : 0),
          'circle_creation': _activityAttempts['circle_creation'] ?? (_circleCompletionPercent > 0 ? 1 : 0),
          'dino_feeding': _activityAttempts['dino_feeding'] ?? (_dinoFedItems.isNotEmpty ? 1 : 0),
          'count_objects': _activityAttempts['count_objects'] ?? (_countTapped.isNotEmpty ? 1 : 0),
          'find_dots': _activityAttempts['find_dots'] ?? (_dotsChoice != null ? 1 : 0),
          'size_choice': _activityAttempts['size_choice'] ?? (_sizeChoice != null ? 1 : 0),
          'sequence_choice': _activityAttempts['sequence_choice'] ?? (_sequenceChoice != null ? 1 : 0),
        },
        'hintsUsed': <String, int>{
          'sound_match': 0,
          'rhyme_match': 0,
          'animal_sound': 0,
          'picture_pair': 0,
          'writing_wizard': 0,
          'busy_shapes': 0,
          'garden': 0,
          'missing_letter': 0,
          'arrow_tracing': 0,
          'circle_creation': 0,
          'dino_feeding': 0,
          'count_objects': 0,
          'find_dots': 0,
          'size_choice': 0,
          'sequence_choice': 0,
        },
      },
    };
  }

  double _choiceScore(int? selected, int correct) {
    if (selected == null) {
      return 0;
    }
    return selected == correct ? 100 : 25;
  }

  double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final double total = values.fold<double>(0, (double sum, double v) => sum + v);
    return _clamp(total / values.length);
  }

  double _clamp(double value) => value.clamp(0, 100).toDouble();

  Widget _soundMatchCard() {
    final List<String> labels =
        _isAge45 ? <String>['Moon', 'Sun', 'Fish'] : <String>['Ball', 'Sun', 'Cat'];
    final List<String> emojis =
        _isAge45 ? <String>['🌙', '☀️', '🐟'] : <String>['⚽', '☀️', '🐱'];
    final String soundToSpeak = _isAge45 ? 'Moon' : 'Ball';

    return _activityCard(
      title: '1) Sound Match',
      instruction: 'Tap speaker to hear the sound, then choose the right picture.',
      onSpeak: () => _speak(soundToSpeak),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2196F3), width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF1976D2), size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Listen carefully to the sound, then tap the matching picture below!',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1565C0)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: List<Widget>.generate(labels.length, (index) {
              return _emojiChoice(
                index,
                _soundMatchChoice,
                emojis[index],
                labels[index],
                (i) {
                  setState(() => _soundMatchChoice = i);
                  _recordAttempt('sound_match', i == 0);
                },
              );
            }),
          ),
          if (_soundMatchChoice != null && _soundMatchChoice == 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star, color: Color(0xFF2C8E4A), size: 18),
                    SizedBox(width: 6),
                    Text(
                      '⭐ Perfect! You found the right sound!',
                      style: TextStyle(color: Color(0xFF2C8E4A), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rhymeCard() {
    final List<String> options =
        _isAge45 ? <String>['Hat', 'Book', 'Fish'] : <String>['Hat', 'Dog', 'Cup'];

    return _activityCard(
      title: '2) Rhyme Match',
      instruction: 'Find the picture that rhymes.',
      onSpeak: () => _speak('Hat'),
      child: Wrap(
        spacing: 8,
        children: List<Widget>.generate(options.length, (index) {
          return _chipChoice(
            index,
            _rhymeChoice,
            options[index],
            (i) {
              setState(() => _rhymeChoice = i);
              _recordAttempt('rhyme_match', i == 0);
            },
          );
        }),
      ),
    );
  }

  Widget _animalSoundCard() {
    return _activityCard(
      title: '3) Animal Sound',
      instruction: 'Tap speaker and choose animal.',
      onSpeak: () => _speak('Meow'),
      child: Wrap(
        spacing: 10,
        children: [
          _emojiChoice(0, _animalChoice, '🐱', 'Cat', (i) {
            setState(() => _animalChoice = i);
            _recordAttempt('animal_sound', i == 0);
          }),
          _emojiChoice(1, _animalChoice, '🐶', 'Dog', (i) {
            setState(() => _animalChoice = i);
            _recordAttempt('animal_sound', i == 0);
          }),
          _emojiChoice(2, _animalChoice, '🐮', 'Cow', (i) {
            setState(() => _animalChoice = i);
            _recordAttempt('animal_sound', i == 0);
          }),
        ],
      ),
    );
  }

  Widget _picturePairCard() {
    final List<String> pairs =
        _isAge45 ? <String>['🍓🍓', '🍓🚗', '🐼⚽'] : <String>['🍎🍎', '🍎🚗', '🐶⚽'];

    return _activityCard(
      title: '4) Picture Pair',
      instruction: 'Tap same picture pair.',
      child: Wrap(
        spacing: 8,
        children: List<Widget>.generate(pairs.length, (index) {
          return _chipChoice(
            index,
            _picturePairChoice,
            pairs[index],
            (i) {
              setState(() => _picturePairChoice = i);
              _recordAttempt('picture_pair', i == 0);
            },
          );
        }),
      ),
    );
  }

  // ===== AGE 3: SIMPLE GAMES =====

  // Widget _strokePracticeCard() {
  //   return _activityCard(
  //     title: '1) Stroke Practice 🖊️',
  //     instruction: 'Tap to trace vertical and horizontal strokes.',
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Container(
  //           height: 60,
  //           decoration: BoxDecoration(
  //             color: const Color(0xFFFFF9F0),
  //             borderRadius: BorderRadius.circular(8),
  //             border: Border.all(color: const Color(0xFFFFA500), width: 2),
  //           ),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //             children: [
  //               Column(
  //                 mainAxisAlignment: MainAxisAlignment.center,
  //                 children: [
  //                   const Text('Vertical', style: TextStyle(fontSize: 10)),
  //                   const SizedBox(height: 4),
  //                   Container(
  //                     width: 2,
  //                     height: 30,
  //                     color: Colors.grey.withValues(alpha: 0.5),
  //                   ),
  //                 ],
  //               ),
  //               Column(
  //                 mainAxisAlignment: MainAxisAlignment.center,
  //                 children: [
  //                   const Text('Horizontal', style: TextStyle(fontSize: 10)),
  //                   const SizedBox(height: 4),
  //                   Container(
  //                     width: 30,
  //                     height: 2,
  //                     color: Colors.grey.withValues(alpha: 0.5),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _connectDotsCard() {
  //   return _activityCard(
  //     title: '2) Connect the Dots 🔵',
  //     instruction: 'Tap the dots in order.',
  //     child: Container(
  //       height: 70,
  //       decoration: BoxDecoration(
  //         color: const Color(0xFFF0F0F0),
  //         borderRadius: BorderRadius.circular(8),
  //       ),
  //       child: Stack(
  //         children: [
  //           Positioned(
  //             left: 20,
  //             top: 23,
  //             child: Container(
  //               width: 20,
  //               height: 20,
  //               decoration: const BoxDecoration(
  //                 color: Color(0xFF2196F3),
  //                 shape: BoxShape.circle,
  //               ),
  //               child: const Center(
  //                 child: Text('1', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
  //               ),
  //             ),
  //           ),
  //           Positioned(
  //             left: 50,
  //             top: 23,
  //             child: Container(
  //               width: 20,
  //               height: 20,
  //               decoration: const BoxDecoration(
  //                 color: Color(0xFF4CAF50),
  //                 shape: BoxShape.circle,
  //               ),
  //               child: const Center(
  //                 child: Text('2', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
  //               ),
  //             ),
  //           ),
  //           Positioned(
  //             right: 20,
  //             top: 23,
  //             child: Container(
  //               width: 20,
  //               height: 20,
  //               decoration: const BoxDecoration(
  //                 color: Color(0xFFFF9800),
  //                 shape: BoxShape.circle,
  //               ),
  //               child: const Center(
  //                 child: Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _traceLineCard() {
  //   return _activityCard(
  //     title: '3) Trace the Line ✏️',
  //     instruction: 'Follow the dotted line.',
  //     child: Container(
  //       height: 60,
  //       decoration: BoxDecoration(
  //         color: const Color(0xFFFFF9F0),
  //         borderRadius: BorderRadius.circular(8),
  //         border: Border.all(color: const Color(0xFFFFA500), width: 2),
  //       ),
  //       child: Center(
  //         child: Padding(
  //           padding: const EdgeInsets.symmetric(horizontal: 16),
  //           child: Row(
  //             children: [
  //               const Text('START', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
  //               const SizedBox(width: 8),
  //               Expanded(
  //                 child: Container(
  //                   height: 1.5,
  //                   decoration: BoxDecoration(
  //                     color: Colors.grey.withValues(alpha: 0.5),
  //                     borderRadius: BorderRadius.circular(1),
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox(width: 8),
  //               const Text('END', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _curvedShapeCard() {
  //   return _activityCard(
  //     title: '4) Curved Shape 🌊',
  //     instruction: 'Trace the wave pattern.',
  //     child: Container(
  //       height: 60,
  //       decoration: BoxDecoration(
  //         color: const Color(0xFFFFF9F0),
  //         borderRadius: BorderRadius.circular(8),
  //         border: Border.all(color: const Color(0xFFFFA500), width: 2),
  //       ),
  //       child: Center(
  //         child: CustomPaint(
  //           painter: CurvePatternPainter(),
  //           size: const Size(200, 40),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // ===== DYSGRAPHIA WRITING GAMES =====

  Widget _writingWizardCard() {
    final List<String> letters = _isAge45 ? <String>['A', 'B', 'C'] : <String>['A', 'B', 'C'];
    
    return _activityCard(
      title: '1) Writing Wizard - Learn Letters ✏️',
      instruction: 'Choose a letter, then SLOWLY drag your finger along the dotted line from START to END.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select a letter:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: List<Widget>.generate(letters.length, (index) {
              final bool isSelected = _writingWizardLetter == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _writingWizardLetter = index;
                    _writingWizardProgress = 0.0;
                    _tracingPathPoints = 0;
                  });
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFDDE8FF) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4A7BFF) : const Color(0xFFE3E3E3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      letters[index],
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_writingWizardLetter != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Drag slowly from START to END along the dotted line:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B6914)),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  // Only allow progress if actively tracing
                  if (details.delta.dx.abs() > 1 || details.delta.dy.abs() > 1) {
                    _tracingPathPoints++;
                    // Slow tracing - need at least 15 points to complete
                    _writingWizardProgress = (_tracingPathPoints / 15).clamp(0.0, 1.0);
                  }
                });
              },
              onPanEnd: (_) {
                // Don't reset if progress is high enough
                if (_writingWizardProgress < 0.85) {
                  setState(() {
                    _writingWizardProgress = 0.0;
                    _tracingPathPoints = 0;
                  });
                }
              },
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFA500), width: 2),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('START ➡️', style: TextStyle(fontSize: 10, color: Color(0xFF2C8E4A), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text(
                            _writingWizardLetter != null ? _letters[_writingWizardLetter!] : 'A',
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('⬅️ END', style: TextStyle(fontSize: 10, color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    // Show progress line
                    if (_writingWizardProgress > 0)
                      Positioned(
                        left: 0,
                        top: 60,
                        child: Container(
                          height: 20,
                          width: _writingWizardProgress * 280,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF7DA1FF), Color(0xFF7DA1FF).withValues(alpha: 0.5)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_writingWizardProgress > 0.1)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(Icons.edit, size: 14, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E3E3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _writingWizardProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF7DA1FF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Progress: ${(_writingWizardProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
            ),
            if (_writingWizardProgress >= 0.85)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Color(0xFF2C8E4A), size: 18),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '⭐ Excellent tracing! Letter mastered!',
                          style: TextStyle(color: Color(0xFF2C8E4A), fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_writingWizardProgress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Keep dragging slowly along the line...',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ],
      ),
    );
  }

  final List<String> _letters = <String>['A', 'B', 'C'];

  Widget _busyShapesCard() {
    return _activityCard(
      title: '2) Busy Shapes - Hand & Eye Coordination 🧩',
      instruction: 'Drag each shape to match its hole. Like a puzzle!',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shapes (drag these):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _shapeItem(0, '🔴', 'Circle', _busyShapesPlaced.contains(0)),
              _shapeItem(1, '🟥', 'Square', _busyShapesPlaced.contains(1)),
              _shapeItem(2, '🔺', 'Triangle', _busyShapesPlaced.contains(2)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Puzzle Holes (drop shapes here):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _puzzleHole(0, '⭕', _busyShapesPlaced.contains(0)),
              _puzzleHole(1, '⬜', _busyShapesPlaced.contains(1)),
              _puzzleHole(2, '🔺', _busyShapesPlaced.contains(2)),
            ],
          ),
          if (_busyShapesPlaced.length == 3)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star, color: Color(0xFF2C8E4A), size: 20),
                    SizedBox(width: 8),
                    Text(
                      '⭐ Perfect puzzle! All shapes matched!',
                      style: TextStyle(color: Color(0xFF2C8E4A), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shapeItem(int index, String emoji, String name, bool placed) {
    if (placed) {
      return Opacity(
        opacity: 0.3,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE3E3E3), width: 2),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
            ),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      );
    }
    return Draggable<int>(
      data: index,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF4A7BFF), width: 2),
            boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withValues(alpha: 0.2))],
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4A7BFF), width: 2),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _puzzleHole(int index, String holeEmoji, bool filled) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data == index && !_busyShapesPlaced.contains(index),
      onAcceptWithDetails: (details) {
        setState(() => _busyShapesPlaced.add(details.data));
      },
      builder: (context, candidateData, rejectedData) {
        final bool hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: filled
                ? const Color(0xFFE8F7E8)
                : (hovering ? const Color(0xFFFFE4B5) : const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: filled
                  ? const Color(0xFF2C8E4A)
                  : (hovering ? const Color(0xFFFFA500) : const Color(0xFFD8D8D8)),
              width: 2,
            ),
            boxShadow: hovering
                ? [BoxShadow(blurRadius: 10, color: const Color(0xFFFFA500).withValues(alpha: 0.3))]
                : null,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(holeEmoji, style: const TextStyle(fontSize: 28)),
                if (filled) const Text('✓', style: TextStyle(fontSize: 14, color: Color(0xFF2C8E4A), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _drawingForKidsCard() {
    return _activityCard(
      title: '3) Garden Coloring - Creative Art 🎨',
      instruction: 'Pick a color, then tap gardens items to color them!',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pick a color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _colorButton('Red', Color(0xFFEF5350)),
              _colorButton('Green', Color(0xFF66BB6A)),
              _colorButton('Blue', Color(0xFF42A5F5)),
              _colorButton('Yellow', Color(0xFFFFEA00)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Color(0xFFEBF5FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFF42A5F5), width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🌳 🌸 🌤️', style: TextStyle(fontSize: 50)),
                  SizedBox(height: 8),
                  Text('Tap to color the garden', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  if (_gardenColored.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFFE8F7E8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('✓ Coloring!', style: TextStyle(color: Color(0xFF2C8E4A), fontWeight: FontWeight.w600, fontSize: 11)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _colorButton(String colorName, Color color) {
    return GestureDetector(
      onTap: () {
        // Color selection logic
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              colorName,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countObjectsCard() {
    return _activityCard(
      title: '1) Count Objects',
      instruction: _isAge45 ? 'Tap all 5 stars.' : 'Tap all 3 stars.',
      child: Wrap(
        spacing: 10,
        children: List<Widget>.generate(_countTarget, (index) {
          final bool tapped = _countTapped.contains(index);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (tapped) {
                  _countTapped.remove(index);
                } else {
                  _countTapped.add(index);
                }
              });
            },
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: tapped ? const Color(0xFFCFF7D6) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD8D8D8)),
              ),
              child: Center(
                child: Text(_isAge45 ? '⭐' : '🍎', style: const TextStyle(fontSize: 27)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _findDotsCard() {
    final int targetDots = _isAge45 ? 4 : 2;
    final List<int> groups = _isAge45 ? <int>[3, 4, 5] : <int>[1, 2, 3];

    return _activityCard(
      title: '2) Find Dots',
      instruction: 'Tap group with $targetDots dots.',
      child: Row(
        children: List<Widget>.generate(groups.length, (index) {
          final Widget card =
              _dotsGroup(index, _dotsChoice, groups[index], (i) {
                setState(() => _dotsChoice = i);
                _recordAttempt('find_dots', i == 1);
              });
          return Padding(
            padding: EdgeInsets.only(right: index == groups.length - 1 ? 0 : 8),
            child: card,
          );
        }),
      ),
    );
  }

  Widget _sizeCard() {
    return _activityCard(
      title: '3) Big Circle',
      instruction: 'Tap the bigger circle.',
      child: Row(
        children: [
          _sizeCircle(0, _sizeChoice, _isAge45 ? 40 : 34, (i) {
            setState(() => _sizeChoice = i);
            _recordAttempt('size_choice', i == 0);
          }),
          const SizedBox(width: 12),
          _sizeCircle(1, _sizeChoice, _isAge45 ? 22 : 18, (i) {
            setState(() => _sizeChoice = i);
            _recordAttempt('size_choice', i == 0);
          }),
        ],
      ),
    );
  }

  Widget _sequenceCard() {
    final String sequence = _isAge45 ? '2 3 ? 5' : '1 2 ? 4';
    final List<String> options = _isAge45 ? <String>['1', '4', '6'] : <String>['1', '2', '3'];

    return _activityCard(
      title: '4) Number Sequence',
      instruction: 'Tap missing number.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sequence,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A2B47)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List<Widget>.generate(options.length, (index) {
              return _chipChoice(
                index,
                _sequenceChoice,
                options[index],
                (i) {
                  setState(() => _sequenceChoice = i);
                  _recordAttempt('sequence_choice', i == 1);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _dinoFeedingCard() {
    final List<String> foods =
        _isAge45 ? <String>['🍎', '🍌', '🥕', '🥦'] : <String>['🍎', '🍌', '🥕'];

    return _activityCard(
      title: 'Dino Is Hungry',
      instruction: _isDinoHappy
          ? 'Yay! Dino is happy.'
          : 'Drag ${_dinoTarget - _dinoFedItems.length} food item(s) to Dino mouth.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List<Widget>.generate(foods.length, (index) {
                    final bool used = _dinoFedItems.contains(index);
                    if (used) {
                      return Opacity(opacity: 0.35, child: _dinoFoodTile(foods[index]));
                    }

                    return Draggable<int>(
                      data: index,
                      feedback: Material(color: Colors.transparent, child: _dinoFoodTile(foods[index])),
                      childWhenDragging: Opacity(opacity: 0.25, child: _dinoFoodTile(foods[index])),
                      child: _dinoFoodTile(foods[index]),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              DragTarget<int>(
                onWillAcceptWithDetails: (details) => !_dinoFedItems.contains(details.data),
                onAcceptWithDetails: (details) {
                  setState(() {
                    _dinoFedItems.add(details.data);
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  final bool hovering = candidateData.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 132,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hovering ? const Color(0xFFE4F7E8) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hovering ? const Color(0xFF57C47A) : const Color(0xFFE3E3E3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildShakingDino(),
                        const SizedBox(height: 4),
                        Container(
                          height: 22,
                          width: 54,
                          decoration: BoxDecoration(
                            color: hovering ? const Color(0xFFFFD6D6) : const Color(0xFFFFE8E8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE7B5B5)),
                          ),
                          child: const Center(
                            child: Text(
                              'mouth',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8B3B3B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_dinoFedItems.length}/$_dinoTarget',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A2B47),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _isDinoHappy
                    ? 'Dino happy face unlocked!'
                    : 'Dino making sad face. Feed more food.',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDinoHappy
                      ? const Color(0xFF2C8E4A)
                      : const Color(0xFF9A5A5A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _dinoFedItems.clear()),
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _missingLetterCard() {
    final String sequence = 'A  B  ?  D';
    final List<String> options = <String>['C', 'E', 'F'];
    
    return _activityCard(
      title: '4) Missing Letter 🔤',
      instruction: 'Tap the correct letter in the sequence',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFF7E57C2), width: 2),
            ),
            child: Center(
              child: Text(
                sequence,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: List<Widget>.generate(options.length, (index) {
              final bool isSelected = _missingLetterChoice == index;
              return GestureDetector(
                onTap: () {
                  setState(() => _missingLetterChoice = index);
                  _recordAttempt('missing_letter', index == 0);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFFDDE8FF) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Color(0xFF4A7BFF) : Color(0xFFE3E3E3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(options[index], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }),
          ),
          if (_missingLetterChoice == 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFFE8F7E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.star, color: Color(0xFF2C8E4A), size: 18),
                    SizedBox(width: 6),
                    Text(
                      '⭐ Correct! C is the answer!',
                      style: TextStyle(color: Color(0xFF2C8E4A), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _arrowTracingCard() {
    return _activityCard(
      title: '5) Arrow Direction Tracing ➡️',
      instruction: 'Drag the ball from LEFT to RIGHT following the arrows!',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFA500), width: 2),
            ),
            child: Stack(
              children: [
                // Draw track with arrows
                Positioned.fill(
                  child: CustomPaint(
                    painter: ArrowTrackPainter(),
                  ),
                ),
                // Draggable ball
                Positioned(
                  left: (_arrowTracingProgress ?? 0) * 200,
                  top: 35,
                  child: Draggable<int>(
                    data: 1,
                    feedback: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFF42A5F5),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(blurRadius: 10, color: Color(0xFF42A5F5))],
                      ),
                      child: const Center(child: Text('⚽', style: TextStyle(fontSize: 18))),
                    ),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFF42A5F5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Text('⚽', style: TextStyle(fontSize: 18))),
                    ),
                  ),
                ),
                // Target zone
                DragTarget<int>(
                  onAcceptWithDetails: (details) {
                    setState(() => _arrowTracingProgress = 1.0);
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Positioned(
                      right: 10,
                      top: 30,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: candidateData.isNotEmpty ? const Color(0xFFE8F7E8) : Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: candidateData.isNotEmpty ? const Color(0xFF2C8E4A) : const Color(0xFFFFA500),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Text('🏁', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _arrowTracingProgress == 1.0 ? '✓ Ball reached the finish line!' : 'Drag the ball to the right →',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _arrowTracingProgress == 1.0 ? const Color(0xFF2C8E4A) : Colors.black54,
            ),
          ),
          if (_arrowTracingProgress == 1.0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.favorite, color: Color(0xFF2C8E4A), size: 18),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '❤️ Great directional control!',
                        style: TextStyle(color: Color(0xFF2C8E4A), fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleCreationCard() {
    return _activityCard(
      title: '6) Circle Creation 🎨',
      instruction: 'Tap and drag to create a circle in the canvas!',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onPanStart: (_) {
              setState(() => _circleCreationStarted = true);
            },
            onPanUpdate: (details) {
              setState(() {
                _circleCompletionPercent = (_circleCompletionPercent + 0.03).clamp(0.0, 1.0);
              });
            },
            onPanEnd: (_) {
              if (_circleCompletionPercent < 0.6) {
                setState(() => _circleCompletionPercent = 0.0);
              }
            },
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF9C27B0), width: 2),
              ),
              child: Stack(
                children: [
                  Center(
                    child: _circleCompletionPercent > 0
                        ? CustomPaint(
                            painter: CirclePainter(_circleCompletionPercent),
                            size: Size(120, 120),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('🎨', style: TextStyle(fontSize: 40)),
                              SizedBox(height: 8),
                              Text('Draw a circle', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_circleCreationStarted)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Circle Progress: ${(_circleCompletionPercent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (_circleCompletionPercent >= 0.6)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7E8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '✓ Perfect!',
                          style: TextStyle(fontSize: 11, color: Color(0xFF2C8E4A), fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E3E3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _circleCompletionPercent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_circleCompletionPercent >= 0.6)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star, color: Color(0xFF2C8E4A), size: 18),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '⭐ Excellent circle! Great motor skills!',
                        style: TextStyle(color: Color(0xFF2C8E4A), fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2B47),
            ),
          ),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _activityCard({
    required String title,
    required String instruction,
    Future<void> Function()? onSpeak,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  instruction,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
              if (onSpeak != null)
                IconButton(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF4A7BFF)),
                  tooltip: 'Read aloud',
                ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _emojiChoice(
    int index,
    int? selected,
    String emoji,
    String label,
    ValueChanged<int> onTap,
  ) {
    final bool isSelected = selected == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDDE8FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A7BFF) : const Color(0xFFE3E3E3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _chipChoice(int index, int? selected, String text, ValueChanged<int> onTap) {
    return ChoiceChip(
      label: Text(text),
      selected: selected == index,
      onSelected: (_) => onTap(index),
      selectedColor: const Color(0xFF7DA1FF).withValues(alpha: 0.28),
    );
  }

  Widget _dotsGroup(int index, int? selected, int dots, ValueChanged<int> onTap) {
    final bool isSelected = selected == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 84,
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDDE8FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A7BFF) : const Color(0xFFE3E3E3),
            width: 2,
          ),
        ),
        child: Center(
          child: Wrap(
            spacing: 4,
            children:
                List<Widget>.generate(dots, (_) => const Text('●', style: TextStyle(fontSize: 18))),
          ),
        ),
      ),
    );
  }

  Widget _sizeCircle(int index, int? selected, double size, ValueChanged<int> onTap) {
    final bool isSelected = selected == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 90,
        height: 64,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDDE8FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A7BFF) : const Color(0xFFE3E3E3),
            width: 2,
          ),
        ),
        child: Center(
          child: Container(
            height: size,
            width: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4B4B4B), width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dinoFoodTile(String emoji) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
    );
  }
}
class CurvePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw simple wave curve
    final Path path = Path();
    path.moveTo(10, size.height / 2);
    path.quadraticBezierTo(
      size.width / 2,
      size.height * 0.2,
      size.width - 10,
      size.height / 2,
    );
    canvas.drawPath(path, paint);

    // Draw second dashed curve
    final Paint dashedPaint = Paint()
      ..color = Color(0xFF2C8E4A).withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Simple dots instead of dashed line
    for (double x = 10; x < size.width - 10; x += 6) {
      canvas.drawCircle(Offset(x, size.height / 2 + 15), 1.5, dashedPaint);
    }
  }

  @override
  bool shouldRepaint(CurvePatternPainter oldDelegate) => false;
}

class ArrowTrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Color(0xFFFFA500)
      ..strokeWidth = 2;

    final Paint arrowPaint = Paint()
      ..color = Color(0xFFFFA500)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw track line
    canvas.drawLine(
      Offset(10, size.height / 2),
      Offset(size.width - 10, size.height / 2),
      paint,
    );

    // Draw arrows pointing right
    for (double x = 40; x < size.width - 30; x += 50) {
      // Arrow head
      final Path arrowPath = Path();
      arrowPath.moveTo(x, size.height / 2);
      arrowPath.lineTo(x - 6, size.height / 2 - 4);
      arrowPath.moveTo(x, size.height / 2);
      arrowPath.lineTo(x - 6, size.height / 2 + 4);

      canvas.drawPath(arrowPath, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(ArrowTrackPainter oldDelegate) => false;
}

class CirclePainter extends CustomPainter {
  final double progress;

  CirclePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Color(0xFF9C27B0)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint fillPaint = Paint()
      ..color = Color(0xFF9C27B0).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 10;

    // Draw filled circle background
    canvas.drawCircle(center, radius, fillPaint);

    // Draw animated circle outline
    final Path path = Path();
    const double startAngle = -math.pi / 2;
    final double sweepAngle = 2 * math.pi * progress;

    path.addArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
    );

    canvas.drawPath(path, paint);

    // Draw progress indicator dot
    if (progress > 0) {
      final double angle = startAngle + sweepAngle;
      final double dotX = center.dx + radius * math.cos(angle);
      final double dotY = center.dy + radius * math.sin(angle);

      final Paint dotPaint = Paint()
        ..color = Color(0xFF9C27B0)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(CirclePainter oldDelegate) => oldDelegate.progress != progress;
}


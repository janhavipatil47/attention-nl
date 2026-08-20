import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:math' as math;
import '../services/assessment_report_service.dart';
import 'report.dart';

class SixYearAssessmentScreen extends StatefulWidget {
  const SixYearAssessmentScreen({super.key});

  @override
  State<SixYearAssessmentScreen> createState() => _SixYearAssessmentScreenState();
}

class _SixYearAssessmentScreenState extends State<SixYearAssessmentScreen>
    with TickerProviderStateMixin {
  late FlutterTts _tts;
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _bubbleController;

  int _currentActivity = 0;
  int _completedActivities = 0;
  bool _isFinalizing = false;
  final DateTime _assessmentStartedAt = DateTime.now();

  // Adaptive learning state.  A level is selected by the child/adult; earning
  // 80% unlocks the next one but never changes the selected level for them.
  static const List<String> _activityIds = <String>[
    'rhyme', 'builder', 'image', 'tracing', 'numbers', 'animals',
    'dice', 'shapes', 'sorter', 'audio', 'matching', 'reading',
  ];
  final Map<String, int> _activityLevels = <String, int>{
    for (final String id in _activityIds) id: 1,
  };
  final Map<String, int> _unlockedLevels = <String, int>{
    for (final String id in _activityIds) id: 1,
  };
  final Map<String, int> _activityAttempts = <String, int>{
    for (final String id in _activityIds) id: 0,
  };
  final Map<String, int> _correctAnswers = <String, int>{
    for (final String id in _activityIds) id: 0,
  };
  final Map<String, int> _hintsUsed = <String, int>{
    for (final String id in _activityIds) id: 0,
  };
  final Map<String, double> _activityAccuracy = <String, double>{
    for (final String id in _activityIds) id: 0,
  };
  String _adaptiveMessage = '';

  String get _currentActivityId => _activityIds[_currentActivity];
  int _levelFor(String id) => _activityLevels[id] ?? 1;
  int get _animalMaximum => _levelFor('animals') == 1 ? 5 : _levelFor('animals') == 2 ? 10 : 15;
  int get _matchPairTarget => _levelFor('matching') == 1 ? 3 : _levelFor('matching') == 2 ? 6 : 8;
  List<int> get _activeNumberRowIndexes {
    switch (_levelFor('numbers')) {
      case 1: return <int>[0, 1]; // 1 and 2
      case 2: return <int>[2, 3]; // 3 and 4
      default: return <int>[4]; // 5
    }
  }

  void _recordAttempt(String activityId, bool correct) {
    setState(() {
      _activityAttempts[activityId] = (_activityAttempts[activityId] ?? 0) + 1;
      if (correct) _correctAnswers[activityId] = (_correctAnswers[activityId] ?? 0) + 1;
      _activityAccuracy[activityId] =
          ((_correctAnswers[activityId] ?? 0) / (_activityAttempts[activityId] ?? 1)) * 100;
    });
  }

  double _performanceFor(String id) {
    if ((_activityAttempts[id] ?? 0) > 0) return _activityAccuracy[id] ?? 0;
    switch (id) {
      case 'numbers':
        return _activeNumberRowIndexes
                .where((int index) => _numberTable[index]['completed'] == true)
                .length /
            _activeNumberRowIndexes.length * 100;
      case 'animals': return _animalGroups.where((Map<String, dynamic> group) => _animalNumberConnections[group['animal']] == group['count']).length / _animalGroups.length * 100;
      case 'shapes': return _collectedShapes.values.where((bool value) => value).length / _collectedShapes.length * 100;
      case 'sorter': return _correctPlacements.where((bool value) => value).length / _correctPlacements.length * 100;
      case 'audio': return _audioExplorerComplete ? 100 : 0;
      case 'matching': return _matchedPairs.length / (_matchPairTarget * 2) * 100;
      case 'reading':
        return _readingWords.where(_readWords.contains).length /
            _readingWords.length * 100;
      default: return 0;
    }
  }

  void _evaluateLevel(String activityId) {
    final double accuracy = _clamp(_performanceFor(activityId));
    final int level = _levelFor(activityId);
    setState(() {
      if (accuracy >= 80 && level < 3) {
        _unlockedLevels[activityId] = math.max(_unlockedLevels[activityId] ?? 1, level + 1);
        _adaptiveMessage = 'Great job! Level ${level + 1} is ready when you are.';
      } else if (accuracy < 50) {
        _hintsUsed[activityId] = (_hintsUsed[activityId] ?? 0) + 1;
        _adaptiveMessage = "Here's a little hint. Let's try this one again!";
      } else {
        _adaptiveMessage = "Nice work! You can try this level again.";
      }
      _activityAccuracy[activityId] = accuracy;
    });
    _tts.speak(_adaptiveMessage);
  }

  void _advanceToNextLevel(String activityId) {
    final int level = _levelFor(activityId);
    if (level >= 3 || _performanceFor(activityId) < 80) return;
    setState(() {
      _unlockedLevels[activityId] = math.max(_unlockedLevels[activityId] ?? 1, level + 1);
      _activityLevels[activityId] = level + 1;
      _activityAccuracy[activityId] = _clamp(_performanceFor(activityId));
      _adaptiveMessage = 'Great job! Welcome to Level ${level + 1}!';
    });
    _tts.speak(_adaptiveMessage);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted && _currentActivityId == activityId) _resetCurrentActivityForLevel();
    });
  }

  List<String> get _activeLowercaseLetters => _lowercaseLetters.take(_matchPairTarget).toList();
  List<String> get _activeUppercaseLetters =>
      _activeLowercaseLetters.map((String letter) => _letterPairs[letter]!).toList()..shuffle();

  Widget _buildAdaptiveLearningPanel() {
    final String id = _currentActivityId;
    final int selected = _levelFor(id);
    final int unlocked = _unlockedLevels[id] ?? 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.purple.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🌈 My Learning Journey  •  Level $selected', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: List<Widget>.generate(3, (int index) {
          final int level = index + 1;
          final bool available = level <= unlocked;
          return ChoiceChip(
            label: Text('Level $level${available ? '' : ' 🔒'}'), selected: selected == level,
            onSelected: available ? (_) => setState(() { _activityLevels[id] = level; _adaptiveMessage = ''; _resetCurrentActivityForLevel(); }) : null,
          );
        })),
        if (_adaptiveMessage.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 5), child: Text(_adaptiveMessage, style: const TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }

  void _resetCurrentActivityForLevel() {
    switch (_currentActivity) {
      case 0: _rhymeComplete = false; _selectNewRhymeCenter(); break;
      case 1: _letterBuilderComplete = false; _resetLetterBuilder(); break;
      case 2: _currentImageIndex = 0; _imageSnapComplete = false; break;
      case 3:
        _currentPracticeLetter = _practiceLetters.first;
        _tracingComplete = false;
        _startTracing();
        break;
      case 4: _numberTableComplete = false; break;
      case 5: _animalCountingComplete = false; _initializeAnimalCounting(); break;
      case 6: _dicePathComplete = false; _initializeDicePath(); break;
      case 9:
        _audioExplorerComplete = false;
        _selectedAudioLetter = null;
        _targetLetter = _audioTargetForLevel;
        break;
      case 10: _matchedPairs.clear(); _matchUpComplete = false; break;
      case 11:
        _readingRainbowComplete = false;
        _selectedWordForSpeech = null;
        break;
    }
  }

  // Rhyme-Time Pop state (NEW)
  final List<String> _rhymeCenters = ['hand', 'cat', 'ball', 'tree'];
  String _currentRhymeCenter = '';
  final Map<String, List<String>> _rhymingWords = {
    'hand': ['band', 'sand', 'land', 'stand'],
    'cat': ['bat', 'hat', 'rat', 'mat'],
    'ball': ['tall', 'wall', 'fall', 'call', 'small'],
    'tree': ['bee', 'see', 'free', 'knee', 'three']
  };
  final Map<String, List<String>> _distractorWords = {
    'hand': ['blue', 'jump'],
    'cat': ['dog', 'fish'],
    'ball': ['jump'],
    'tree': ['dog']
  };
  List<String> _currentBubbles = [];
  Set<String> _poppedBubbles = {};
  bool _rhymeComplete = false;

  // Letter Builder state (NEW)
  String _currentBuildLetter = 'd';
  String? _selectedPart;
  String? _circlePosition;
  bool _letterBuilt = false;
  bool _letterBuilderComplete = false;

  // Image-to-Word Snap state (NEW)
  final List<Map<String, dynamic>> _legacyImageWords = [
    {'image': '🐕', 'word': 'dog', 'letters': ['D', 'G', 'P', 'B'], 'correct': 'D'},
    {'image': '🐱', 'word': 'cat', 'letters': ['C', 'T', 'K', 'S'], 'correct': 'C'},
    {'image': '🦇', 'word': 'bat', 'letters': ['B', 'T', 'P', 'D'], 'correct': 'B'},
    {'image': '📖', 'word': 'book', 'letters': ['B', 'K', 'P', 'T'], 'correct': 'B'}
  ];
  // Each level deliberately uses a different group of pictures and words.
  // The choices are stored with the item, so the correct answer is always shown.
  final Map<int, List<Map<String, dynamic>>> _imageWordsByLevel = <int, List<Map<String, dynamic>>>{
    1: <Map<String, dynamic>>[
      {'image': '\u{1F436}', 'word': 'dog', 'letters': ['D', 'B'], 'correct': 'D'},
      {'image': '\u{1F431}', 'word': 'cat', 'letters': ['C', 'M'], 'correct': 'C'},
      {'image': '\u{2600}', 'word': 'sun', 'letters': ['S', 'T'], 'correct': 'S'},
      {'image': '\u{1F41F}', 'word': 'fish', 'letters': ['F', 'P'], 'correct': 'F'},
    ],
    2: <Map<String, dynamic>>[
      {'image': '\u{1FA81}', 'word': 'kite', 'letters': ['K', 'C', 'T', 'L'], 'correct': 'K'},
      {'image': '\u{1F319}', 'word': 'moon', 'letters': ['M', 'N', 'W', 'B'], 'correct': 'M'},
      {'image': '\u{1F981}', 'word': 'lion', 'letters': ['L', 'R', 'D', 'P'], 'correct': 'L'},
      {'image': '\u{1F333}', 'word': 'tree', 'letters': ['T', 'F', 'S', 'G'], 'correct': 'T'},
    ],
    3: <Map<String, dynamic>>[
      {'image': '\u{1F418}', 'word': 'elephant', 'letters': ['E', 'A', 'I', 'L', 'F', 'P'], 'correct': 'E'},
      {'image': '\u{2602}', 'word': 'umbrella', 'letters': ['U', 'O', 'V', 'M', 'B', 'H'], 'correct': 'U'},
      {'image': '\u{1F3B7}', 'word': 'xylophone', 'letters': ['X', 'Z', 'Y', 'K', 'Q', 'S'], 'correct': 'X'},
      {'image': '\u{1F353}', 'word': 'strawberry', 'letters': ['S', 'T', 'R', 'B', 'C', 'P'], 'correct': 'S'},
    ],
  };
  List<Map<String, dynamic>> get _imageWords =>
      _imageWordsByLevel[_levelFor('image')] ?? _imageWordsByLevel[1]!;
  int _currentImageIndex = 0;
  String? _selectedLetter;
  bool _imageSnapComplete = false;

  // Tracing Practice state (NEW)
  final Map<int, List<String>> _practiceLettersByLevel = <int, List<String>>{
    1: <String>['L', 'B'],
    2: <String>['O', 'Q'],
    3: <String>['F', 'P'],
  };
  List<String> get _practiceLetters =>
      _practiceLettersByLevel[_levelFor('tracing')] ?? _practiceLettersByLevel[1]!;
  String _currentPracticeLetter = 'L';
  List<Offset> _tracedPoints = [];
  bool _isTracing = false;
  bool _tracingComplete = false;
  double _tracingAccuracy = 0.0;
  bool _hasSpokenFeedback = false;
  final Map<String, List<Offset>> _letterPaths = {
    'L': [
      const Offset(40, 40),   // Top of L
      const Offset(40, 160),  // Bottom of L
      const Offset(160, 160), // End of bottom line
    ],
    'B': [
      const Offset(40, 40), const Offset(40, 160), // vertical stem
      const Offset(40, 100), const Offset(115, 55), const Offset(115, 100),
      const Offset(40, 100), const Offset(115, 115), const Offset(115, 160),
      const Offset(40, 160),
    ],
    'O': [
      const Offset(70, 40), const Offset(130, 40), const Offset(160, 70),
      const Offset(160, 130), const Offset(130, 160), const Offset(70, 160),
      const Offset(40, 130), const Offset(40, 70), const Offset(70, 40),
    ],
    'Q': [
      const Offset(70, 40), const Offset(130, 40), const Offset(160, 70),
      const Offset(160, 130), const Offset(130, 160), const Offset(70, 160),
      const Offset(40, 130), const Offset(40, 70), const Offset(70, 40),
      const Offset(115, 115), const Offset(165, 170),
    ],
    'P': [
      const Offset(40, 40),   // Top of P
      const Offset(40, 160),  // Bottom of P
      const Offset(40, 100),  // Middle of P
      const Offset(120, 40),  // Top right of curve
      const Offset(120, 100), // Middle right of curve
    ],
    'T': [
      const Offset(40, 40),   // Top left
      const Offset(160, 40),  // Top right
      const Offset(100, 40),  // Center
      const Offset(100, 160), // Bottom
    ],
    'F': [
      const Offset(40, 40),   // Top of F
      const Offset(40, 160),  // Bottom of F
      const Offset(40, 80),   // Middle
      const Offset(120, 80),  // End of middle line
      const Offset(40, 40),   // Top
      const Offset(120, 40),  // End of top line
    ],
  };

  // Original Letter Sorter state
  final List<String> _letters = ['a', 'd', 'k', 'w'];
  final List<String> _sortedLetters = ['a', 'd', 'k', 'w'];
  List<String> _jumbledLetters = [];
  List<String> _placedLetters = [];
  List<bool> _correctPlacements = [];
  bool _letterSorterComplete = false;

  // Original Audio Explorer state
  final Map<int, List<String>> _audioLettersByLevel = <int, List<String>>{
    1: <String>['b', 'c', 'a'],
    2: <String>['d', 'e', 'f'],
    3: <String>['g', 'h', 'j'],
  };
  final Map<int, String> _audioTargetsByLevel = <int, String>{
    1: 'b',
    2: 'e',
    3: 'j',
  };
  List<String> get _audioLetters =>
      _audioLettersByLevel[_levelFor('audio')] ?? _audioLettersByLevel[1]!;
  String get _audioTargetForLevel =>
      _audioTargetsByLevel[_levelFor('audio')] ?? 'b';
  String _targetLetter = '';
  String? _selectedAudioLetter;
  bool _audioExplorerComplete = false;

  // Original Match-Up Forest state
  final Map<String, String> _letterPairs = {
    'h': 'H', 'i': 'I', 'e': 'E', 'm': 'M', 'f': 'F',
    'd': 'D', 'w': 'W', 'p': 'P', 's': 'S', 'n': 'N'
  };
  final List<String> _lowercaseLetters = ['h', 'i', 'e', 'm', 'f', 'd', 'w', 'p', 's', 'n'];
  final List<String> _uppercaseLetters = ['N', 'I', 'D', 'M', 'F', 'H', 'W', 'P', 'S', 'E'];
  String? _selectedLowercase;
  String? _selectedUppercase;
  final Set<String> _matchedPairs = {};
  bool _matchUpComplete = false;

  // Original Reading Rainbow state
  final Map<int, List<String>> _readingWordsByLevel = <int, List<String>>{
    1: <String>['blue', 'green'],
    2: <String>['smart', 'nature', 'strong'],
    3: <String>['beauty', 'might', 'free'],
  };
  List<String> get _readingWords =>
      _readingWordsByLevel[_levelFor('reading')] ?? _readingWordsByLevel[1]!;
  final Set<String> _readWords = {};
  bool _readingRainbowComplete = false;

  // Speech Recognition for Reading Rainbow
  late SpeechToText _speechToText;
  bool _speechEnabled = false;
  bool _isListening = false;
  String? _currentSpokenWord;
  String? _selectedWordForSpeech;
  final Map<String, String> _speechResults = {}; // word -> spoken result
  final Map<String, double> _speechConfidence = {}; // word -> confidence score

  // NEW: Visual-to-Symbol Table state
  final List<Map<String, dynamic>> _numberTable = [
    {'picture': 1, 'digits': '1', 'words': 'One', 'completed': true},
    {'picture': 2, 'digits': '', 'words': '', 'completed': false},
    {'picture': 3, 'digits': '', 'words': '', 'completed': false},
    {'picture': 4, 'digits': '', 'words': '', 'completed': false},
    {'picture': 5, 'digits': '', 'words': '', 'completed': false},
  ];
  bool _numberTableComplete = false;

  // NEW: Animal Counting Corral state
  final List<Map<String, dynamic>> _animalGroups = [
    {'animal': 'mouse', 'count': 9, 'emoji': '🐭', 'selected': false},
    {'animal': 'penguin', 'count': 7, 'emoji': '🐧', 'selected': false},
    {'animal': 'elephant', 'count': 2, 'emoji': '🐘', 'selected': false},
  ];
  final List<int> _availableNumbers = [1, 2, 3, 4, 5, 6, 7, 8, 9];
  Map<String, int> _animalNumberConnections = {};
  bool _animalCountingComplete = false;
  bool _showCrossOutMode = false;

  // NEW: Dice Path Sequencing state
  final List<int> _diceSequence = [1, 2, 3, 4, 5, 6, 7, 8, 9];
  List<int> _scrambledDice = [];
  List<int> _tappedDice = [];
  int _currentDiceIndex = 0;
  bool _dicePathComplete = false;
  int _ramaPosition = 0;

  // NEW: Geometric Shape Detective state
  final Map<String, String> _duckShapes = {
    'head': 'Circle',
    'body': 'Oval',
    'beak': 'Triangle',
    'eye': 'Circle',
    'wing': 'Oval',
    'tail': 'Triangle',
    'feet': 'Square',
    'water': 'Square',
  };
  final Map<String, bool> _collectedShapes = {
    'Triangle': false,
    'Circle': false,
    'Square': false,
  };
  bool _shapeDetectiveComplete = false;

  @override
  void initState() {
    super.initState();
    
    _tts = FlutterTts();
    _speechToText = SpeechToText();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 600), 
      vsync: this
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800), 
      vsync: this
    );
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000), 
      vsync: this
    );
    _bubbleController = AnimationController(
      duration: const Duration(milliseconds: 1200), 
      vsync: this
    );
    
    _correctPlacements = List.filled(4, false);
    // For final Sets, clear them instead of reassigning
    _matchedPairs.clear();
    _readWords.clear();
    
    _setupTts();
    _initializeActivities();
    
    // Start the bubble animation
    _bubbleController.repeat();
  }

  void _setupTts() async {
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  void _initializeSpeechRecognition() async {
    try {
      // Check if speech recognition is available
      bool available = await _speechToText.initialize(
        onError: (error) => print('Speech recognition error: $error'),
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'done' && mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
        debugLogging: true,
      );
      
      setState(() {
        _speechEnabled = available;
      });
      
      if (available) {
        print('Speech recognition initialized successfully');
      } else {
        print('Speech recognition not available - trying to enable...');
        // Try to enable speech recognition
        available = await _speechToText.initialize(
          onError: (error) => print('Retry error: $error'),
          onStatus: (status) => print('Retry status: $status'),
          debugLogging: true,
        );
        setState(() {
          _speechEnabled = available;
        });
      }
    } catch (e) {
      print('Failed to initialize speech recognition: $e');
      setState(() {
        _speechEnabled = false;
      });
    }
  }

  void _startListening(String word) async {
    if (!_speechEnabled) {
      // Try to initialize speech recognition again
      _initializeSpeechRecognition();
      if (!_speechEnabled) {
        _tts.speak('Please allow microphone access and use Chrome browser');
        return;
      }
    }

    setState(() {
      _isListening = true;
      _selectedWordForSpeech = word;
      _currentSpokenWord = null;
    });

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (!mounted) return;
          
          setState(() {
            _currentSpokenWord = result.recognizedWords.toLowerCase();
            print('Speech result: "$_currentSpokenWord", confidence: ${result.confidence}');
            print('Target word: "$word"');
            
            if (result.finalResult && _currentSpokenWord != null) {
              _speechResults[word] = _currentSpokenWord!;
              _speechConfidence[word] = result.confidence;
              
              // Special handling for short words like "free"
              bool isCorrect = _analyzeSpeechResult(word, _currentSpokenWord!, result.confidence);
              print('Analysis result: $isCorrect');
            }
          });
        },
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: false,
      );
    } catch (e) {
      print('Error during speech recognition: $e');
      setState(() {
        _isListening = false;
      });
      _tts.speak('Microphone access denied. Please allow microphone and try again.');
    }
  }

  void _showSpeechNotAvailableDialog(String word) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Speech Recognition Not Available"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Speech recognition is not available in your browser. This feature requires:"),
            const SizedBox(height: 8),
            const Text("· Chrome browser (recommended)\n· HTTPS connection\n· Microphone permission"),
            const SizedBox(height: 12),
            Text("Would you like to mark '$word' as practiced manually?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _markWordAsPracticed(word);
            },
            child: const Text("Mark as Practiced"),
          ),
        ],
      ),
    );
  }

  void _markWordAsPracticed(String word) {
    bool levelComplete = false;
    setState(() {
      _readWords.add(word);
      _speechResults[word] = "Manual practice";
      _speechConfidence[word] = 0.5; // Neutral confidence for manual practice
      if (_readingWords.every(_readWords.contains)) {
        _readingRainbowComplete = true;
        levelComplete = true;
      }
    });
    _tts.speak('Great job practicing $word!');
    if (levelComplete) _advanceToNextLevel('reading');
  }

  bool _analyzeSpeechResult(String targetWord, String spokenWord, double confidence) {
    bool isCorrect = spokenWord.toLowerCase() == targetWord.toLowerCase();
    
    // Special handling for short words and pronunciation variations
    if (!isCorrect && targetWord == "free") {
      // Check for common pronunciation variations of "free"
      List<String> freeVariations = ['free', 'fwee', 'frea', 'frie', 'fry'];
      for (String variation in freeVariations) {
        if (spokenWord.toLowerCase().contains(variation)) {
          isCorrect = true;
          print('Matched "free" variation: "$spokenWord" -> "$variation"');
          break;
        }
      }
    }
    
    // Also check if the spoken word contains the target word (for partial matches)
    if (!isCorrect && spokenWord.toLowerCase().contains(targetWord.toLowerCase())) {
      isCorrect = true;
      print('Partial match: "$spokenWord" contains "$targetWord"');
    }
    
    // For very short words, be more lenient with confidence
    if (targetWord.length <= 4 && confidence >= 0.5 && !isCorrect) {
      // Check if the sounds are similar (basic phonetic matching)
      if (_soundsSimilar(targetWord, spokenWord)) {
        isCorrect = true;
        print('Phonetic match: "$targetWord" sounds like "$spokenWord"');
      }
    }
    
    if (isCorrect) {
      _tts.speak('Great pronunciation! You said $spokenWord correctly!');
      bool levelComplete = false;
      setState(() {
        _readWords.add(targetWord);
        if (_readingWords.every(_readWords.contains)) {
          _readingRainbowComplete = true;
          levelComplete = true;
        }
      });
      if (levelComplete) _advanceToNextLevel('reading');
    } else {
      _tts.speak('Nice try! You said $spokenWord, but the word is $targetWord. Try again!');
    }
    
    return isCorrect;
  }

  bool _soundsSimilar(String word1, String word2) {
    // Basic phonetic similarity for short words
    word1 = word1.toLowerCase();
    word2 = word2.toLowerCase();
    
    // Check if they share most letters
    if (word1.length <= 3 && word2.length <= 3) {
      int matchingChars = 0;
      for (int i = 0; i < math.min(word1.length, word2.length); i++) {
        if (word1[i] == word2[i]) matchingChars++;
      }
      return matchingChars >= 2; // At least 2 matching characters for 3-letter words
    }
    
    return false;
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _initializeActivities() {
    // Initialize Rhyme-Time Pop
    _selectNewRhymeCenter();
    
    // Initialize Letter Builder
    _resetLetterBuilder();
    
    // Initialize Original activities
    _jumbledLetters = List.from(_letters)..shuffle();
    _placedLetters = List.filled(4, '');
    _correctPlacements = List.filled(4, false);
    _targetLetter = _audioTargetForLevel;
    
    // Initialize NEW activities
    _initializeNumberTable();
    _initializeAnimalCounting();
    _initializeDicePath();
    _initializeShapeDetective();
  }

  void _selectNewRhymeCenter() {
    setState(() {
      _currentRhymeCenter = _rhymeCenters[math.Random().nextInt(_rhymeCenters.length)];
      // Combine rhyming words and distractors
      final int level = _levelFor('rhyme');
      final int rhymeCount = level == 1 ? 2 : level == 2 ? 3 : _rhymingWords[_currentRhymeCenter]!.length;
      final int distractorCount = level == 1 ? 1 : _distractorWords[_currentRhymeCenter]!.length;
      List<String> allWords = [
        ..._rhymingWords[_currentRhymeCenter]!.take(rhymeCount),
        ..._distractorWords[_currentRhymeCenter]!.take(distractorCount),
      ];
      allWords.shuffle();
      _currentBubbles = allWords;
      _poppedBubbles.clear();
    });
  }

  void _resetLetterBuilder() {
    setState(() {
      _currentBuildLetter = ['d', 'b', 'p', 'l'][math.Random().nextInt(4)];
      _selectedPart = null;
      _circlePosition = null;
      _letterBuilt = false;
      _letterParts.clear();
    });
  }
  
  List<String> _letterParts = [];

  void _initializeNumberTable() {
    setState(() {
      // Already initialized in state variables
    });
  }

  void _initializeAnimalCounting() {
    setState(() {
      _animalNumberConnections.clear();
      final math.Random random = math.Random();
      for (final Map<String, dynamic> group in _animalGroups) {
        group['count'] = 1 + random.nextInt(_animalMaximum);
        group['selected'] = false;
      }
      _showCrossOutMode = _levelFor('animals') == 3;
    });
  }

  void _initializeDicePath() {
    setState(() {
      final int count = _levelFor('dice') == 1 ? 3 : _levelFor('dice') == 2 ? 5 : 7;
      _scrambledDice = _diceSequence.take(count).toList()..shuffle();
      // Keep the existing 3x3 layout; zero represents an empty path tile.
      while (_scrambledDice.length < 9) {
        _scrambledDice.add(0);
      }
      _tappedDice.clear();
      _currentDiceIndex = 0;
      _ramaPosition = 0;
    });
  }

  void _initializeShapeDetective() {
    setState(() {
      _collectedShapes.updateAll((key, value) => false);
    });
  }

  void _popBubble(String bubble) {
    if (!_poppedBubbles.contains(bubble)) {
      bool isRhyme = _rhymingWords[_currentRhymeCenter]!.contains(bubble);
      if (isRhyme) {
        _recordAttempt('rhyme', true);
        setState(() {
          _poppedBubbles.add(bubble);
        });
        _tts.speak('Good job! $bubble rhymes with ${_currentRhymeCenter}!');
        
        // Check if all rhyming bubbles are popped
        int totalRhymes = _currentBubbles.where(_rhymingWords[_currentRhymeCenter]!.contains).length;
        if (_poppedBubbles.length == totalRhymes) {
          setState(() {
            _rhymeComplete = true;
          });
          _advanceToNextLevel('rhyme');
        }
      } else {
        _recordAttempt('rhyme', false);
        _shakeController.forward().then((_) => _shakeController.reverse());
        _tts.speak('Try again! $bubble doesn\'t rhyme with ${_currentRhymeCenter}');
      }
    }
  }

  void _buildLetter(String part) {
    setState(() {
      if (!_letterParts.contains(part)) {
        _letterParts.add(part);
      }
      
      // Check if letter is properly built
      bool isCorrect = _checkLetterBuilt();
      if (isCorrect) {
        _recordAttempt('builder', true);
        _letterBuilt = true;
        _tts.speak('Great job building the letter $_currentBuildLetter!');
        _letterBuilderComplete = true;
        _advanceToNextLevel('builder');
      } else {
        // Give guidance based on current letter
        _giveLetterGuidance();
      }
    });
  }
  
  bool _checkLetterBuilt() {
    if (_letterParts == null) return false;
    switch (_currentBuildLetter) {
      case 'p':
        return _letterParts.contains('vertical_line') && _letterParts.contains('semi_circle');
      case 'l':
        return _letterParts.contains('vertical_line') && _letterParts.contains('horizontal_line');
      case 'd':
        return _letterParts.contains('vertical_line') && _letterParts.contains('circle');
      case 'b':
        return _letterParts.contains('vertical_line') && _letterParts.contains('circle');
      default:
        return false;
    }
  }
  
  void _giveLetterGuidance() {
    if (_letterParts == null) return;
    switch (_currentBuildLetter) {
      case 'p':
        if (!_letterParts.contains('vertical_line')) {
          _tts.speak('Start with the straight line for letter P!');
        } else if (!_letterParts.contains('semi_circle')) {
          _tts.speak('Now add the round part at the top!');
        }
        break;
      case 'l':
        if (!_letterParts.contains('vertical_line')) {
          _tts.speak('Start with the tall straight line for letter L!');
        } else if (!_letterParts.contains('horizontal_line')) {
          _tts.speak('Now add the short line at the bottom!');
        }
        break;
      case 'd':
        if (!_letterParts.contains('vertical_line')) {
          _tts.speak('Start with the straight line for letter D!');
        } else if (!_letterParts.contains('circle')) {
          _tts.speak('Now add the round part!');
        }
        break;
      case 'b':
        if (!_letterParts.contains('vertical_line')) {
          _tts.speak('Start with the straight line for letter B!');
        } else if (!_letterParts.contains('circle')) {
          _tts.speak('Now add the round parts!');
        }
        break;
    }
  }

  void _selectImageLetter(String letter) {
    setState(() {
      _selectedLetter = letter;
      if (letter == _imageWords[_currentImageIndex]['correct']) {
        _recordAttempt('image', true);
        _tts.speak('Correct! ${_imageWords[_currentImageIndex]['word']} starts with $letter');
        if (_currentImageIndex < _imageWords.length - 1) {
          _currentImageIndex++;
          _selectedLetter = null;
        } else {
          _imageSnapComplete = true;
          _advanceToNextLevel('image');
        }
      } else {
        _recordAttempt('image', false);
        _shakeController.forward().then((_) => _shakeController.reverse());
        _tts.speak('Not quite! Try again');
        _selectedLetter = null;
      }
    });
  }

  List<String> _imageChoices(Map<String, dynamic> item) {
    final List<String> choices = List<String>.from(item['letters'] as List);
    final int level = _levelFor('image');
    if (level == 1) return choices.take(2).toList();
    if (level == 2) return choices;
    for (final String extra in <String>['A', 'E', 'L', 'R', 'M', 'N']) {
      if (!choices.contains(extra)) choices.add(extra);
      if (choices.length == 6) break;
    }
    choices.shuffle();
    return choices;
  }

  void _startTracing() {
    setState(() {
      _isTracing = true;
      _tracedPoints.clear();
      _tracingAccuracy = 0.0;
      _hasSpokenFeedback = false;
    });
    _tts.speak('Trace the letter $_currentPracticeLetter!');
  }

  void _addTracingPoint(Offset point) {
    if (!_isTracing) return;
    
    setState(() {
      // Add point only if it's not too close to the last point (to reduce duplicates)
      if (_tracedPoints.isEmpty || (point - _tracedPoints.last).distance > 2) {
        _tracedPoints.add(point);
      }
      
      // Calculate accuracy during tracing for live feedback
      if (_tracedPoints.length >= 5) {
        _calculateTracingAccuracy();
      }
      
      // Check if tracing is complete
      if (_tracedPoints.length >= 15 && !_tracingComplete) {
        _calculateTracingAccuracy();
        final double threshold = _levelFor('tracing') == 1 ? .50 : _levelFor('tracing') == 2 ? .60 : .75;
        if (_tracingAccuracy > threshold && _hasCoveredEntireLetter()) {
          _recordAttempt('tracing', true);
          _tracingComplete = true;
          _isTracing = false;
          _tts.speak('Excellent! You traced $_currentPracticeLetter with ${(_tracingAccuracy * 100).round()}% accuracy!');
        } else if (!_hasSpokenFeedback) {
          _hasSpokenFeedback = true;
          _tts.speak('Keep going! Trace all the way over every red guide dot before you finish.');
        }
      }
    });
  }

  void _calculateTracingAccuracy() {
    final targetPath = _letterPaths[_currentPracticeLetter] ?? [];
    if (targetPath.isEmpty || _tracedPoints.isEmpty) {
      _tracingAccuracy = 0.0;
      return;
    }
    
    double totalDistance = 0;
    double matchedDistance = 0;
    
    for (int i = 0; i < _tracedPoints.length; i++) {
      final tracedPoint = _tracedPoints[i];
      double minDistance = double.infinity;

      // Find the closest point along each dotted guide segment.  Comparing
      // against only the end points made correct strokes between red dots look
      // inaccurate.
      for (int segment = 0; segment < targetPath.length - 1; segment++) {
        final double distance = _distanceToSegment(
          tracedPoint,
          targetPath[segment],
          targetPath[segment + 1],
        );
        if (distance < minDistance) {
          minDistance = distance;
        }
      }

      totalDistance += 1.0;
      if (minDistance <= 30) {
        matchedDistance += 1.0;
      }
    }
    
    _tracingAccuracy = totalDistance > 0 ? matchedDistance / totalDistance : 0.0;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final Offset segment = end - start;
    final double segmentLengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (segmentLengthSquared == 0) return (point - start).distance;
    final Offset relativePoint = point - start;
    final double progress = ((relativePoint.dx * segment.dx) +
            (relativePoint.dy * segment.dy)) /
        segmentLengthSquared;
    final double clampedProgress = progress.clamp(0.0, 1.0);
    final Offset closest = start + segment * clampedProgress;
    return (point - closest).distance;
  }

  bool _hasCoveredEntireLetter() {
    final List<Offset> guidePoints = _letterPaths[_currentPracticeLetter] ?? <Offset>[];
    // A short accurate stroke no longer counts: every turn/end guide point
    // must be reached before the letter can be completed.
    return guidePoints.every((Offset guide) => _tracedPoints.any(
          (Offset traced) => (traced - guide).distance <= 28,
        ));
  }

  void _nextPracticeLetter() {
    final currentIndex = _practiceLetters.indexOf(_currentPracticeLetter);
    if (currentIndex < _practiceLetters.length - 1) {
      setState(() {
        _currentPracticeLetter = _practiceLetters[currentIndex + 1];
        _tracedPoints.clear();
        _tracingComplete = false;
        _isTracing = false;
        _tracingAccuracy = 0.0;
        _hasSpokenFeedback = false;
      });
    } else {
      _tts.speak('Excellent! You completed this tracing level!');
      // A level is only finished after every letter in its sequence has been
      // completed. At that point award the successful level attempt so the
      // adaptive progression can move on instead of remaining on the same UI.
      setState(() {
        _activityAttempts['tracing'] = 1;
        _correctAnswers['tracing'] = 1;
        _activityAccuracy['tracing'] = 100;
      });
      _advanceToNextLevel('tracing');
    }
  }

  @override
  void dispose() {
    // Stop speech recognition and clean up
    if (_speechEnabled) {
      _speechToText.stop();
      _speechToText.cancel();
    }
    
    _shakeController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _bubbleController.dispose();
    _tts.stop();
    super.dispose();
  }

  Widget _buildActivityIndicator() {
    int totalActivities = 12;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(totalActivities, (index) {
          bool isCompleted = index < _completedActivities;
          bool isCurrent = index == _currentActivity;
          
          return Container(
            width: 30,
            height: 8,
            decoration: BoxDecoration(
              color: isCompleted 
                  ? Colors.green 
                  : isCurrent 
                      ? Colors.purple 
                      : Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // NEW: Rhyme-Time Pop Activity
  Widget _buildRhymeTimePop() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "🎈 Rhyme-Time Pop! 🎈",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 12),
            Text(
              "Pop the bubbles that rhyme with '$_currentRhymeCenter'",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Center word
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                _currentRhymeCenter,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Floating bubbles
            SizedBox(
              height: 300,
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                children: (_currentBubbles.isNotEmpty ? _currentBubbles : ['band', 'sand', 'blue', 'jump']).map((bubble) => 
                  AnimatedBuilder(
                    animation: _bubbleController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, math.sin(_bubbleController.value * math.pi * 2) * 10),
                        child: GestureDetector(
                          onTap: () => _popBubble(bubble),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _poppedBubbles.contains(bubble) 
                                  ? Colors.grey.withOpacity(0.5)
                                  : Colors.blue.withOpacity(0.8),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                bubble,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ).toList(),
              ),
            ),
            
            if (_rhymeComplete)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "🎉 Amazing! You found all the rhymes! 🎉",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // NEW: Letter Builder Activity
  Widget _buildLetterBuilder() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "🧩 Letter Builder 🧩",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 12),
            Text(
              "Build the letter '$_currentBuildLetter'",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Building area
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey, width: 2),
              ),
              child: Center(
                child: _buildLetterVisual(),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Letter parts to choose from
            Text(
              _getLetterInstructions(),
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _buildLetterPartButtons(),
            ),
            
            if (_letterBuilderComplete)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "🎉 You built the letter! 🎉",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLetterVisual() {
    switch (_currentBuildLetter) {
      case 'p':
        return Stack(
          children: [
            // Vertical line
            if (_letterParts != null && _letterParts.contains('vertical_line'))
              Positioned(
                left: 40,
                top: 20,
                child: Container(
                  width: 8,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.brown,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            // Semi-circle at top
            if (_letterParts != null && _letterParts.contains('semi_circle'))
              Positioned(
                left: 48,
                top: 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                ),
              ),
          ],
        );
      case 'l':
        return Stack(
          children: [
            // Vertical line
            if (_letterParts != null && _letterParts.contains('vertical_line'))
              Positioned(
                left: 40,
                top: 20,
                child: Container(
                  width: 8,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.brown,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            // Horizontal line at bottom
            if (_letterParts != null && _letterParts.contains('horizontal_line'))
              Positioned(
                left: 40,
                top: 120,
                child: Container(
                  width: 60,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.brown,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        );
      case 'd':
        return Stack(
          children: [
            // Vertical line
            if (_letterParts != null && _letterParts.contains('vertical_line'))
              Positioned(
                left: 40,
                top: 20,
                child: Container(
                  width: 8,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.brown,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            // Circle on the right
            if (_letterParts != null && _letterParts.contains('circle'))
              Positioned(
                left: 48,
                top: 40,
                child: Container(
                  width: 50,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
          ],
        );
      case 'b':
        return Stack(
          children: [
            // Vertical line
            if (_letterParts != null && _letterParts.contains('vertical_line'))
              Positioned(
                left: 40,
                top: 20,
                child: Container(
                  width: 8,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.brown,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            // Circle on the right
            if (_letterParts != null && _letterParts.contains('circle'))
              Positioned(
                left: 48,
                top: 20,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            if (_letterParts != null && _letterParts.contains('circle'))
              Positioned(
                left: 48,
                top: 80,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getLetterInstructions() {
    switch (_currentBuildLetter) {
      case 'p':
        return 'Build letter P: Start with the straight line, then add the round part at the top';
      case 'l':
        return 'Build letter L: Start with the tall line, then add the short line at the bottom';
      case 'd':
        return 'Build letter D: Start with the straight line, then add the round part';
      case 'b':
        return 'Build letter B: Start with the straight line, then add the round parts';
      default:
        return 'Build the letter!';
    }
  }

  List<Widget> _buildLetterPartButtons() {
    List<Widget> buttons = [];
    
    // Always add vertical line
    buttons.add(
      GestureDetector(
        onTap: () => _buildLetter('vertical_line'),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: (_letterParts != null && _letterParts.contains('vertical_line')) ? Colors.green : Colors.brown,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('|', style: TextStyle(fontSize: 40, color: Colors.white)),
          ),
        ),
      ),
    );
    
    // Add specific parts based on letter
    switch (_currentBuildLetter) {
      case 'p':
        buttons.add(
          GestureDetector(
            onTap: () => _buildLetter('semi_circle'),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (_letterParts != null && _letterParts.contains('semi_circle')) ? Colors.green : Colors.orange,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: const Center(
                child: Text('D', style: TextStyle(fontSize: 40, color: Colors.white)),
              ),
            ),
          ),
        );
        break;
      case 'l':
        buttons.add(
          GestureDetector(
            onTap: () => _buildLetter('horizontal_line'),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (_letterParts != null && _letterParts.contains('horizontal_line')) ? Colors.green : Colors.brown,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('¯', style: TextStyle(fontSize: 40, color: Colors.white)),
              ),
            ),
          ),
        );
        break;
      case 'd':
      case 'b':
        buttons.add(
          GestureDetector(
            onTap: () => _buildLetter('circle'),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (_letterParts != null && _letterParts.contains('circle')) ? Colors.green : Colors.orange,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('O', style: TextStyle(fontSize: 40, color: Colors.white)),
              ),
            ),
          ),
        );
        break;
    }
    
    return buttons;
  }

  // NEW: Image-to-Word Snap Activity
  Widget _buildImageToWordSnap() {
    final currentItem = _imageWords[_currentImageIndex];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "📸 Image-to-Word Snap! 📸",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 12),
            const Text(
              "Tap the letter that starts this word",
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            // Image display
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  currentItem['image'],
                  style: const TextStyle(fontSize: 80),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Voice hint button
            ElevatedButton.icon(
              onPressed: () async {
                await _tts.speak(currentItem['word']);
              },
              icon: const Icon(Icons.volume_up),
              label: const Text("Listen to the word"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Letter choices (large, bold font)
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: _imageChoices(currentItem).map((letter) => 
                GestureDetector(
                  onTap: () => _selectImageLetter(letter),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _selectedLetter == letter 
                          ? Colors.green 
                          : Colors.white,
                      border: Border.all(color: Colors.blue, width: 3),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ).toList(),
            ),
            
            if (_imageSnapComplete)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "🎉 Great job! You know your letter sounds! 🎉",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // NEW: Tracing Practice Activity
  Widget _buildTracingPractice() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "✏️ Tracing Practice ✏️",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 12),
            Text(
              "Trace the letter $_currentPracticeLetter! Follow the dotted lines.",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Tracing canvas
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Builder(
                builder: (context) {
                  return GestureDetector(
                    onPanStart: (_) => _startTracing(),
                    onPanUpdate: (details) {
                      final RenderBox renderBox = context.findRenderObject() as RenderBox;
                      final localPosition = renderBox.globalToLocal(details.globalPosition);
                      _addTracingPoint(localPosition);
                    },
                    onPanEnd: (_) {
                      if (_isTracing && _tracedPoints.isNotEmpty && !_hasSpokenFeedback) {
                        _calculateTracingAccuracy();
                        _hasSpokenFeedback = true;
                        _tts.speak('Your accuracy is ${(_tracingAccuracy * 100).round()}%. ${_tracingAccuracy > 0.6 ? "Great job!" : "Try again for better accuracy!"}');
                      }
                    },
                    child: CustomPaint(
                      painter: TracingPainter(
                        targetLetter: _currentPracticeLetter,
                        tracedPoints: _tracedPoints,
                        letterPaths: _letterPaths,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    "How to trace:",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "1. Touch and drag to trace\n2. Follow the dotted path\n3. Stay as close as possible",
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Accuracy indicator
            if (_isTracing || _tracingAccuracy > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _tracingAccuracy > 0.6 
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _tracingAccuracy > 0.6 ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      "Accuracy: ${(_tracingAccuracy * 100).round()}%",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _tracingAccuracy > 0.6 ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tracingAccuracy > 0.6 ? "Great tracing!" : "Try again for better accuracy",
                      style: TextStyle(
                        fontSize: 14,
                        color: _tracingAccuracy > 0.6 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            
            if (_tracingComplete)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 3),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 30,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Excellent Tracing!",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "You traced $_currentPracticeLetter with ${(_tracingAccuracy * 100).round()}% accuracy",
                      style: const TextStyle(fontSize: 16, color: Colors.green),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _nextPracticeLetter,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("Next Letter"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // NEW: Visual-to-Symbol Table Module
  Widget _buildNumberTable() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Number Representation Table",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 20),
            
            // Table header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: const Row(
                children: [
                  Expanded(child: Text('Picture', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('In Digits', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('In Words', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Show only the number rows assigned to the selected level.
            ..._activeNumberRowIndexes.map((int index) {
              final row = _numberTable[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: row['completed'] ? Colors.green.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    // Picture column - dots
                    Expanded(
                      child: Center(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: List.generate(row['picture'], (dotIndex) => 
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Digits column
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!row['completed'] && row['digits'].isEmpty) {
                            _showDigitPopup(index);
                          }
                        },
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: row['digits'].isNotEmpty ? Colors.blue.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Center(
                            child: Text(
                              row['digits'].isNotEmpty ? row['digits'] : 'Tap',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: row['digits'].isNotEmpty ? Colors.blue : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Words column
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!row['completed'] && row['words'].isEmpty) {
                            _showWordPopup(index);
                          }
                        },
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: row['words'].isNotEmpty ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Center(
                            child: Text(
                              row['words'].isNotEmpty ? row['words'] : 'Tap',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: row['words'].isNotEmpty ? Colors.green : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            
            if (_numberTableComplete)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Excellent! You completed the number table!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDigitPopup(int rowIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose the number'),
        content: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [2, 3, 4, 5].map((number) => 
            GestureDetector(
              onTap: () {
                setState(() {
                  _numberTable[rowIndex]['digits'] = number.toString();
                  _checkRowCompletion(rowIndex);
                });
                Navigator.of(context).pop();
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    number.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ).toList(),
        ),
      ),
    );
  }

  void _showWordPopup(int rowIndex) {
    final correctWords = ['Two', 'Three', 'Four', 'Five'];
    final wordOptions = [
      correctWords[rowIndex - 1], // Correct word
      'Seven', // Wrong option 1
      'Ten',   // Wrong option 2
    ]..shuffle();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select word for ${rowIndex + 1}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: wordOptions.map((word) => 
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _numberTable[rowIndex]['words'] = word;
                    _checkRowCompletion(rowIndex);
                  });
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    word,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
          ).toList(),
        ),
      ),
    );
  }

  void _checkRowCompletion(int rowIndex) {
    final row = _numberTable[rowIndex];
    if (row['digits'].isNotEmpty && row['words'].isNotEmpty) {
      setState(() {
        row['completed'] = true;
      });
      _tts.speak('Great job! ${rowIndex + 1} is ${row['words']}');
      
      // Check only the rows assigned to this level.
      if (_activeNumberRowIndexes.every(
          (int index) => _numberTable[index]['completed'] == true)) {
        setState(() {
          _numberTableComplete = true;
        });
        _advanceToNextLevel('numbers');
        _tts.speak('Amazing! You completed this number level!');
      }
    }
  }

  // NEW: Animal Counting Corral
  Widget _buildAnimalCounting() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Animal Counting Corral",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 20),
            
            // Cross-out mode toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: Row(
                children: [
                  const Text("Cross-out mode:", style: TextStyle(fontSize: 16)),
                  const Spacer(),
                  Switch(
                    value: _showCrossOutMode,
                    onChanged: (value) {
                      setState(() {
                        _showCrossOutMode = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Main content area
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animal groups on the left
                Expanded(
                  flex: 2,
                  child: Column(
                    children: _animalGroups.asMap().entries.map((entry) {
                      final index = entry.key;
                      final animal = entry.value;
                      final isSelected = animal['selected'];
                      final isConnected = _animalNumberConnections.containsKey(animal['animal']);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isConnected ? Colors.green : Colors.grey,
                            width: isConnected ? 3 : 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Animal display with cross-out functionality
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  // Toggle selection
                                  for (var a in _animalGroups) {
                                    a['selected'] = false;
                                  }
                                  animal['selected'] = true;
                                });
                                _tts.speak('${animal['animal']}');
                              },
                              child: Row(
                                children: [
                                  // Animal emojis
                                  Expanded(
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: List.generate(animal['count'], (dotIndex) => 
                                        Container(
                                          width: 24,
                                          height: 24,
                                          child: Stack(
                                            children: [
                                              Text(
                                                animal['emoji'],
                                                style: const TextStyle(fontSize: 20),
                                              ),
                                              if (_showCrossOutMode && dotIndex < animal['count'] ~/ 2)
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.withOpacity(0.3),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: Colors.red, width: 2),
                                                    ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      size: 12,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Animal name only (count hidden for challenge)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      animal['animal'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            if (isConnected)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Connected to ${_animalNumberConnections[animal['animal']]}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // Number buttons in center
                SizedBox(
                  width: 80,
                  child: Column(
                    children: List<int>.generate(_animalMaximum, (int index) => index + 1).map((number) => 
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        width: 60,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () {
                            _connectAnimalToNumber(number);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                          ),
                          child: Text(
                            number.toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ).toList(),
                  ),
                ),
              ],
            ),
            
            if (_animalCountingComplete)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Perfect! You matched all animals with their counts!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getAnimalColor(String animal) {
    switch (animal) {
      case 'mouse': return Colors.grey;
      case 'penguin': return Colors.black;
      case 'elephant': return Colors.brown;
      default: return Colors.blue;
    }
  }

  void _connectAnimalToNumber(int number) {
    // Find selected animal
    final selectedAnimal = _animalGroups.firstWhere(
      (animal) => animal['selected'],
      orElse: () => {'animal': '', 'count': 0, 'selected': false},
    );
    
    if (selectedAnimal['animal'].isNotEmpty) {
      setState(() {
        _animalNumberConnections[selectedAnimal['animal']] = number;
        selectedAnimal['selected'] = false;
        
        // Check if all animals are connected
        if (_animalNumberConnections.length == _animalGroups.length) {
          bool allCorrect = true;
          for (var animal in _animalGroups) {
            if (_animalNumberConnections[animal['animal']] != animal['count']) {
              allCorrect = false;
              break;
            }
          }
          
          if (allCorrect) {
            _animalCountingComplete = true;
            _tts.speak('Excellent! All animals are correctly counted!');
            _advanceToNextLevel('animals');
          } else {
            _tts.speak('Some connections are incorrect. Try again!');
          }
        }
      });
    } else {
      _tts.speak('Please select an animal first!');
    }
  }

  // NEW: Dice Path Sequencing
  Widget _buildDicePath() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Dice Path Sequencing",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 20),
            
            const Text(
              "Tap the dice in order from 1 to 9",
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            
            // 3x3 grid of dice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: Column(
                children: [
                  // Dice grid
                  ...List.generate(3, (row) => 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(3, (col) {
                        final index = row * 3 + col;
                        final diceValue = _scrambledDice[index];
                        final isTapped = _tappedDice.contains(diceValue);
                        final isRamaPosition = _ramaPosition == index;
                        
                        return GestureDetector(
                          onTap: () => _tapDice(diceValue, index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isTapped 
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isTapped 
                                    ? Colors.green
                                    : Colors.grey,
                                width: isTapped ? 3 : 2,
                              ),
                              boxShadow: isRamaPosition ? [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ] : null,
                            ),
                            child: Stack(
                              children: [
                                // Dice dots
                                Center(
                                  child: _buildDiceDots(diceValue),
                                ),
                                
                                // Rama character indicator
                                if (isRamaPosition)
                                  Positioned(
                                    top: -10,
                                    right: -10,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.purple,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                
                                // Tapped indicator
                                if (isTapped)
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Progress indicator
                  Text(
                    "Next: ${_currentDiceIndex + 1}",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _currentDiceIndex < 9 ? Colors.blue : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            
            if (_dicePathComplete)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Amazing! You completed the dice sequence!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiceDots(int value) {
    switch (value) {
      case 1:
        return const Center(
          child: CircleAvatar(radius: 6, backgroundColor: Colors.black),
        );
      case 2:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CircleAvatar(radius: 6, backgroundColor: Colors.black),
            CircleAvatar(radius: 6, backgroundColor: Colors.black),
          ],
        );
      case 3:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CircleAvatar(radius: 6, backgroundColor: Colors.black),
            CircleAvatar(radius: 6, backgroundColor: Colors.black),
            CircleAvatar(radius: 6, backgroundColor: Colors.black),
          ],
        );
      case 4:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
              ],
            ),
          ],
        );
      case 5:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
              ],
            ),
            Center(
              child: CircleAvatar(radius: 6, backgroundColor: Colors.black),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
              ],
            ),
          ],
        );
      case 6:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
                CircleAvatar(radius: 6, backgroundColor: Colors.black),
              ],
            ),
          ],
        );
      case 7:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
              ],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
              ],
            ),
            const Center(
              child: CircleAvatar(radius: 5, backgroundColor: Colors.black),
            ),
          ],
        );
      case 8:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
              ],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
                CircleAvatar(radius: 5, backgroundColor: Colors.black),
              ],
            ),
          ],
        );
      case 9:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 4, backgroundColor: Colors.black),
                CircleAvatar(radius: 4, backgroundColor: Colors.black),
                CircleAvatar(radius: 4, backgroundColor: Colors.black),
              ],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 4, backgroundColor: Colors.black),
                CircleAvatar(radius: 4, backgroundColor: Colors.black),
                CircleAvatar(radius: 4, backgroundColor: Colors.black),
              ],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(radius: 4, backgroundColor: Colors.black),
                CircleAvatar(radius: 4, backgroundColor: Colors.black),
                CircleAvatar(radius: 4, backgroundColor: Colors.black),
              ],
            ),
          ],
        );
      default:
        return Container();
    }
  }

  void _tapDice(int diceValue, int position) {
    if (_tappedDice.contains(diceValue)) {
      return; // Already tapped
    }
    
    setState(() {
      if (diceValue == _currentDiceIndex + 1) {
        _recordAttempt('dice', true);
        // Correct sequence
        _tappedDice.add(diceValue);
        _currentDiceIndex++;
        _ramaPosition = position;
        _tts.speak('Good! ${diceValue}');
        
        if (_currentDiceIndex == _scrambledDice.where((int value) => value > 0).length) {
          _dicePathComplete = true;
          _tts.speak('Perfect! You completed the sequence!');
          _advanceToNextLevel('dice');
        }
      } else {
        _recordAttempt('dice', false);
        // Wrong sequence - gentle pulse
        _shakeController.forward().then((_) => _shakeController.reverse());
        _tts.speak('Not quite! Look for ${_currentDiceIndex + 1}');
      }
    });
  }

  // NEW: Geometric Shape Detective
  Widget _buildShapeDetective() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Geometric Shape Detective",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 20),
            
            const Text(
              "Tap parts of the duck to identify shapes!",
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 30),
            
            // Duck illustration with tap zones
            Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.lightBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Stack(
                children: [
                  // Duck body (oval)
                  Positioned(
                    left: 100,
                    top: 80,
                    child: GestureDetector(
                      onTap: () => _collectShape('body', 'Oval'),
                      child: Container(
                        width: 80,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.yellow.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: const Center(
                          child: Text('Body', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                  
                  // Duck head (circle)
                  Positioned(
                    left: 60,
                    top: 60,
                    child: GestureDetector(
                      onTap: () => _collectShape('head', 'Circle'),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.yellow.withOpacity(0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: const Center(
                          child: Text('Head', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                  
                  // Duck beak (triangle)
                  Positioned(
                    left: 30,
                    top: 75,
                    child: GestureDetector(
                      onTap: () => _collectShape('beak', 'Triangle'),
                      child: Container(
                        width: 30,
                        height: 30,
                        child: CustomPaint(
                          painter: TrianglePainter(Colors.orange),
                        ),
                      ),
                    ),
                  ),
                  
                  // Duck eye (circle)
                  Positioned(
                    left: 70,
                    top: 70,
                    child: GestureDetector(
                      onTap: () => _collectShape('eye', 'Circle'),
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey, width: 1),
                        ),
                      ),
                    ),
                  ),
                  
                  // Duck wing (oval)
                  Positioned(
                    left: 120,
                    top: 90,
                    child: GestureDetector(
                      onTap: () => _collectShape('wing', 'Oval'),
                      child: Container(
                        width: 40,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.yellow.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange, width: 1),
                        ),
                      ),
                    ),
                  ),
                  
                  // Duck tail (triangle)
                  Positioned(
                    left: 170,
                    top: 90,
                    child: GestureDetector(
                      onTap: () => _collectShape('tail', 'Triangle'),
                      child: Container(
                        width: 40,
                        height: 40,
                        child: CustomPaint(
                          painter: TrianglePainter(Colors.orange),
                        ),
                      ),
                    ),
                  ),
                  
                  // Duck feet (squares)
                  Positioned(
                    left: 100,
                    top: 160,
                    child: GestureDetector(
                      onTap: () => _collectShape('feet', 'Square'),
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                      ),
                    ),
                  ),
                  
                  Positioned(
                    left: 130,
                    top: 160,
                    child: GestureDetector(
                      onTap: () => _collectShape('feet', 'Square'),
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                      ),
                    ),
                  ),
                  
                  // Water ripples (squares)
                  Positioned(
                    left: 40,
                    top: 140,
                    child: GestureDetector(
                      onTap: () => _collectShape('water', 'Square'),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                      ),
                    ),
                  ),
                  
                  Positioned(
                    left: 180,
                    top: 140,
                    child: GestureDetector(
                      onTap: () => _collectShape('water', 'Square'),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Collection bins
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCollectionBin('Triangle', Colors.red),
                _buildCollectionBin('Circle', Colors.blue),
                _buildCollectionBin('Square', Colors.green),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Progress text
            Text(
              "Shapes found: ${_collectedShapes.values.where((collected) => collected).length}/3",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            
            if (_shapeDetectiveComplete)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Excellent! You found all the shapes in the duck!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionBin(String shape, Color color) {
    final isCollected = _collectedShapes[shape] ?? false;
    
    return Container(
      width: 100,
      height: 120,
      decoration: BoxDecoration(
        color: isCollected ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCollected ? color : Colors.grey,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shape icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: _buildShapeIcon(shape, color),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Shape name
          Text(
            shape,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isCollected ? color : Colors.grey,
            ),
          ),
          
          if (isCollected)
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildShapeIcon(String shape, Color color) {
    switch (shape) {
      case 'Triangle':
        return Container(
          width: 0,
          height: 0,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(width: 20, color: color),
              bottom: BorderSide(width: 20, color: Colors.transparent),
              left: BorderSide(width: 20, color: Colors.transparent),
              right: BorderSide(width: 20, color: Colors.transparent),
            ),
          ),
        );
      case 'Circle':
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        );
      case 'Square':
        return Container(
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      default:
        return Container();
    }
  }

  void _collectShape(String part, String shape) {
    setState(() {
      // Only collect if the shape exists in our collection bins
      if (_collectedShapes.containsKey(shape)) {
        _collectedShapes[shape] = true;
        _tts.speak('Great! You found a $shape in the ${part}');
        
        // Check if all shapes are collected
        if (_collectedShapes.values.every((collected) => collected)) {
          _shapeDetectiveComplete = true;
          _tts.speak('Amazing! You found all the shapes!');
          _advanceToNextLevel('shapes');
        }
      } else {
        _tts.speak('That\'s a $shape, but we\'re looking for Triangle, Circle, or Square!');
      }
    });
  }

  // Original activity widgets
  Widget _buildLetterSorter() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "The Letter Sorter",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 12),
            const Text(
              "Drag and drop letters in alphabetical order: a, d, k, w",
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Wooden slots at top
            Wrap(
              spacing: 12,
              children: List.generate(4, (index) => 
                DragTarget<String>(
                  onAcceptWithDetails: (details) {
                    setState(() {
                      String droppedLetter = details.data;
                      _placedLetters[index] = droppedLetter;
                      _correctPlacements[index] = _sortedLetters[index] == droppedLetter;
                      
                      // Remove the dropped letter from jumbled letters
                      _jumbledLetters.remove(droppedLetter);
                      
                      // Check if all letters are placed correctly
                      if (_correctPlacements.every((correct) => correct)) {
                        _letterSorterComplete = true;
                        _tts.speak("Great job! You sorted all letters correctly!");
                      }
                    });
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      width: 70,
                      height: 90,
                      decoration: BoxDecoration(
                        color: candidateData.isNotEmpty 
                            ? Colors.brown.withOpacity(0.5)
                            : Colors.brown.withOpacity(0.3),
                        border: Border.all(
                          color: candidateData.isNotEmpty ? Colors.orange : Colors.brown, 
                          width: 2
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          _placedLetters[index],
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _correctPlacements[index] ? Colors.green : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Jumbled letters at bottom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _jumbledLetters.map((letter) => 
                  Draggable<String>(
                    data: letter,
                    feedback: Container(
                      width: 60,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.yellow,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          letter,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Container(
                      width: 60,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.yellow.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                    ),
                    child: Container(
                      width: 60,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.yellow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          letter,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioExplorer() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "The Audio Explorer",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 16),
            const Text(
              "Listen and find the correct letter!",
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Friendly robot with speaker
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.smart_toy,
                size: 50,
                color: Colors.blue,
              ),
            ),
            
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await _tts.speak("Can you find the letter $_targetLetter?");
              },
              icon: const Icon(Icons.volume_up),
              label: const Text("Listen"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Letter buttons in a responsive grid
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _audioLetters.map((letter) => 
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAudioLetter = letter;
                    });
                    
                    if (letter == _targetLetter) {
                      _tts.speak("Great job!");
                      setState(() {
                        _audioExplorerComplete = true;
                      });
                      _advanceToNextLevel('audio');
                    } else {
                      _shakeController.forward().then((_) => _shakeController.reverse());
                      _tts.speak("Try again!");
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          math.sin(_shakeController.value * 2 * math.pi) * 5,
                          0,
                        ),
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: _selectedAudioLetter == letter 
                                ? (letter == _targetLetter ? Colors.green : Colors.red)
                                : Colors.white,
                            border: Border.all(
                              color: _selectedAudioLetter == letter 
                                  ? (letter == _targetLetter ? Colors.green : Colors.red)
                                  : Colors.grey, 
                              width: 2
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedAudioLetter == letter ? [
                              BoxShadow(
                                color: (letter == _targetLetter ? Colors.green : Colors.red).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _selectedAudioLetter == letter ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchUpForest() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "The Match-Up Forest",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 12),
            const Text(
              "Connect lowercase letters with their uppercase friends",
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            Row(
              children: [
                // Lowercase column
                Expanded(
                  child: Column(
                    children: _activeLowercaseLetters.map((letter) => 
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedLowercase = letter;
                            if (_selectedUppercase != null && 
                                _letterPairs[letter] == _selectedUppercase) {
                              _matchedPairs.add(letter);
                              _matchedPairs.add(_selectedUppercase!);
                              _tts.speak("Perfect match!");
                              _selectedLowercase = null;
                              _selectedUppercase = null;
                              
                              if (_matchedPairs.length == _matchPairTarget * 2) {
                                _matchUpComplete = true;
                                _advanceToNextLevel('matching');
                              }
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _matchedPairs.contains(letter) 
                                  ? Colors.green 
                                  : _selectedLowercase == letter 
                                      ? Colors.blue 
                                      : Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _matchedPairs.contains(letter) || _selectedLowercase == letter ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ).toList(),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Uppercase column
                Expanded(
                  child: Column(
                    children: _activeUppercaseLetters.map((letter) => 
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedUppercase = letter;
                            if (_selectedLowercase != null && 
                                _letterPairs[_selectedLowercase!] == letter) {
                              _matchedPairs.add(_selectedLowercase!);
                              _matchedPairs.add(letter);
                              _tts.speak("Perfect match!");
                              _selectedLowercase = null;
                              _selectedUppercase = null;
                              
                              if (_matchedPairs.length == _matchPairTarget * 2) {
                                _matchUpComplete = true;
                                _advanceToNextLevel('matching');
                              }
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _matchedPairs.contains(letter) 
                                ? Colors.green 
                                : _selectedUppercase == letter 
                                    ? Colors.orange 
                                    : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _matchedPairs.contains(letter) || _selectedUppercase == letter 
                                    ? Colors.white 
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingRainbow() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "The Reading Rainbow",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
            ),
            const SizedBox(height: 12),
            const Text(
              "Tap words to hear them, then read them aloud for analysis!",
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2196F3), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.mic, color: Color(0xFF1976D2), size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Speech Analysis: Tap a word, then press the microphone to read it aloud!',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1565C0)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Word grid with speech analysis
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _readingWords.map((word) => 
                Container(
                  child: Column(
                    children: [
                      // Word container
                      GestureDetector(
                        onTap: () async {
                          await _tts.speak(word);
                          setState(() {
                            _selectedWordForSpeech = word;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _readWords.contains(word) 
                                ? Colors.green.withOpacity(0.3)
                                : _selectedWordForSpeech == word
                                    ? Colors.blue.withOpacity(0.2)
                                    : Colors.white,
                            border: Border.all(
                              color: _readWords.contains(word) 
                                  ? Colors.green 
                                  : _selectedWordForSpeech == word
                                      ? Colors.blue
                                      : Colors.grey,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _readWords.contains(word) ? [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Text(
                            word,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _readWords.contains(word) 
                                  ? Colors.green.shade700 
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      
                      // Speech controls and results
                      if (_selectedWordForSpeech == word) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Microphone button
                            GestureDetector(
                              onTap: () => _isListening ? _stopListening() : _startListening(word),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isListening ? Colors.red : Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isListening ? Icons.stop : Icons.mic,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            
                            // Speech result
                            if (_speechResults.containsKey(word)) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _speechResults[word]!.toLowerCase() == word.toLowerCase()
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _speechResults[word]!.toLowerCase() == word.toLowerCase()
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'You said: ${_speechResults[word]}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _speechResults[word]!.toLowerCase() == word.toLowerCase()
                                            ? Colors.green.shade700
                                            : Colors.orange.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Confidence: ${(_speechConfidence[word]! * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ).toList(),
            ),
            
            // Speech status indicator
            if (_isListening) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Listening... Speak clearly!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentActivity() {
    switch (_currentActivity) {
      case 0:
        return _buildRhymeTimePop();
      case 1:
        return _buildLetterBuilder();
      case 2:
        return _buildImageToWordSnap();
      case 3:
        return _buildTracingPractice();
      case 4:
        return _buildNumberTable();
      case 5:
        return _buildAnimalCounting();
      case 6:
        return _buildDicePath();
      case 7:
        return _buildShapeDetective();
      case 8:
        return _buildLetterSorter();
      case 9:
        return _buildAudioExplorer();
      case 10:
        return _buildMatchUpForest();
      case 11:
        return _buildReadingRainbow();
      default:
        return const SizedBox.shrink();
    }
  }

  void _nextActivity() {
    _evaluateLevel(_currentActivityId);
    // Allow progression regardless of completion status
    if (_currentActivity < 11) {
      setState(() {
        _currentActivity++;
        _completedActivities++;
      });
      _tts.speak("Moving to next activity!");
    } else if (_currentActivity == 11) {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Assessment Complete!"),
        content: const Text("Great job! You've completed all 12 activities!"),
        actions: [
          TextButton(
            onPressed: _isFinalizing
                ? null
                : () async {
                    await _finalizeAssessmentAndOpenReport();
                  },
            child: Text(_isFinalizing ? "Please wait..." : "Finish"),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizeAssessmentAndOpenReport() async {
    setState(() => _isFinalizing = true);
    try {
      final Map<String, double> skillScores = _calculateDomainScores();
      final Map<String, String> skillLabels = <String, String>{
        'reading_language': 'Reading & Language',
        'listening': 'Listening',
        'writing_tracing': 'Writing & Tracing',
        'math': 'Math & Number Sense',
        'attention': 'Attention & Focus',
        'memory': 'Memory & Matching',
      };
      final List<String> assessedActivities = <String>[
        'Rhyme-Time Pop',
        'Letter Builder',
        'Image-to-Word Snap',
        'Tracing Practice',
        'Visual-to-Symbol Table',
        'Animal Counting Corral',
        'Dice Path Sequencing',
        'Geometric Shape Detective',
        'Letter Sorter',
        'Audio Explorer',
        'Match-Up Forest',
        'Reading Rainbow',
      ];
      final String reportId = await AssessmentReportService.createAssessmentReport(
        assessmentType: 'age_6_to_7',
        childAge: 6,
        skillScores: skillScores,
        skillLabels: skillLabels,
        assessedActivities: assessedActivities,
        rawMetrics: _buildRawMetrics(),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => ReportScreen(reportId: reportId),
        ),
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
    final int totalRhymes = _rhymingWords[_currentRhymeCenter]?.length ?? 0;
    final double rhymeScore = totalRhymes == 0
        ? (_rhymeComplete ? 100 : 0)
        : _clamp((_poppedBubbles.length / totalRhymes) * 100);
    final double imageWordScore = _imageSnapComplete
        ? 100
        : _clamp((_currentImageIndex / _imageWords.length) * 100);
    final double readingFluencyScore =
        _clamp((_readWords.length / _readingWords.length) * 100);
    final double reading = _weightedAverage(<double>[
      rhymeScore,
      imageWordScore,
      readingFluencyScore
    ], <double>[0.30, 0.30, 0.40]);

    final int builtParts = _letterParts.length;
    final double letterBuilderScore = _letterBuilderComplete
        ? 100
        : _clamp((builtParts / 2) * 100);
    final double tracingScore = _tracingComplete
        ? _clamp((_tracingAccuracy * 100) + 8)
        : _clamp(_tracingAccuracy * 100);
    final double letterSorterScore = _correctPlacements.isEmpty
        ? 0
        : _clamp((_correctPlacements.where((bool v) => v).length /
                _correctPlacements.length) *
            100);
    final double writing = _weightedAverage(
      <double>[letterBuilderScore, tracingScore, letterSorterScore],
      <double>[0.35, 0.40, 0.25],
    );

    final double diceScore = _clamp((_tappedDice.length / _diceSequence.length) * 100);
    final int collectedShapes = _collectedShapes.values.where((bool v) => v).length;
    final double shapeScore = _clamp((collectedShapes / _collectedShapes.length) * 100);
    final double progressScore = _clamp(((_currentActivity + 1) / 12) * 100);
    final double attention = _weightedAverage(
      <double>[diceScore, shapeScore, progressScore],
      <double>[0.35, 0.35, 0.30],
    );

    final double matchScore = _clamp((_matchedPairs.length / 20) * 100);
    final double audioScore = _audioExplorerComplete ? 100 : (_selectedAudioLetter != null ? 40 : 0);
    final int numberDone = _numberTable
        .where((Map<String, dynamic> row) => row['completed'] == true)
        .length;
    final double numberTableScore =
        _clamp((numberDone / _numberTable.length) * 100);
    int animalCorrect = 0;
    for (final Map<String, dynamic> group in _animalGroups) {
      final String animal = group['animal'] as String;
      final int target = group['count'] as int;
      if (_animalNumberConnections[animal] == target) {
        animalCorrect++;
      }
    }
    final double animalScore =
        _clamp((animalCorrect / _animalGroups.length) * 100);
    final double memory = _weightedAverage(
      <double>[matchScore, audioScore, numberTableScore, animalScore],
      <double>[0.35, 0.15, 0.25, 0.25],
    );
    final double listening = _weightedAverage(
      <double>[audioScore, rhymeScore],
      <double>[0.55, 0.45],
    );
    final double math = _weightedAverage(
      <double>[numberTableScore, animalScore, diceScore],
      <double>[0.35, 0.35, 0.30],
    );

    return <String, double>{
      'reading_language': reading,
      'listening': listening,
      'writing_tracing': writing,
      'math': math,
      'attention': attention,
      'memory': memory,
    };
  }

  Map<String, dynamic> _buildRawMetrics() {
    final int sessionDurationSeconds =
        DateTime.now().difference(_assessmentStartedAt).inSeconds;
    final double objectiveAccuracy = _average(<double>[
      _clamp((_poppedBubbles.length /
              ((_rhymingWords[_currentRhymeCenter]?.length ?? 1))) *
          100),
      _clamp((_readWords.length / _readingWords.length) * 100),
      _clamp((_correctPlacements.where((bool v) => v).length /
              (_correctPlacements.isEmpty ? 1 : _correctPlacements.length)) *
          100),
      _clamp((_matchedPairs.length / 20) * 100),
      _clamp((_tappedDice.length / _diceSequence.length) * 100),
    ]);

    return <String, dynamic>{
      'completedActivities': _completedActivities + 1,
      'totalActivities': 12,
      'measuredActivities': 12,
      'answeredMeasuredActivities': _completedActivities + 1,
      'consistencyScore': _clamp(((_tracingAccuracy * 100) * 0.6) + (((_completedActivities + 1) / 12) * 100 * 0.4)),
      'objectiveAccuracy': objectiveAccuracy,
      'sessionDurationSeconds': sessionDurationSeconds,
      'currentActivityIndex': _currentActivity,
      'tracingAccuracy': (_tracingAccuracy * 100).round(),
      'readWordsCompleted': _readWords.length,
      'adaptiveLearning': <String, dynamic>{
        'selectedLevels': _activityLevels,
        'unlockedLevels': _unlockedLevels,
        'accuracy': _activityAccuracy.map((String key, double value) => MapEntry<String, double>(key, _clamp(value))),
        'attempts': _activityAttempts,
        'hintsUsed': _hintsUsed,
      },
    };
  }

  double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final double sum = values.fold<double>(0, (double a, double b) => a + b);
    return _clamp(sum / values.length);
  }

  double _weightedAverage(List<double> values, List<double> weights) {
    if (values.isEmpty || values.length != weights.length) {
      return 0;
    }
    double numerator = 0;
    double denominator = 0;
    for (int i = 0; i < values.length; i++) {
      numerator += values[i] * weights[i];
      denominator += weights[i];
    }
    if (denominator == 0) {
      return 0;
    }
    return _clamp(numerator / denominator);
  }

  double _clamp(double value) => value.clamp(0, 100).toDouble();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black54),
        title: Column(
          children: const [
            Text("6 Years Assessment", style: TextStyle(color: Color(0xFF1A2B47), fontSize: 18, fontWeight: FontWeight.bold)),
            //Text("Dysgraphia-Friendly Activities", style: TextStyle(color: Colors.purple, fontSize: 12)),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildActivityIndicator(),
          _buildAdaptiveLearningPanel(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentActivity(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _nextActivity,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text("Next Activity"),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for triangle shapes
class TrianglePainter extends CustomPainter {
  final Color color;
  
  TrianglePainter(this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for tracing practice
class TracingPainter extends CustomPainter {
  final String targetLetter;
  final List<Offset> tracedPoints;
  final Map<String, List<Offset>> letterPaths;
  
  TracingPainter({
    required this.targetLetter,
    required this.tracedPoints,
    required this.letterPaths,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final targetPath = letterPaths[targetLetter] ?? [];
    
    // Draw dotted guide lines
    final dottedPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < targetPath.length - 1; i++) {
      final start = targetPath[i];
      final end = targetPath[i + 1];
      _drawDottedLine(canvas, start, end, dottedPaint);
    }
    
    // Draw traced path
    if (tracedPoints.isNotEmpty) {
      final tracePaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      
      // Draw continuous path
      final path = Path();
      path.moveTo(tracedPoints.first.dx, tracedPoints.first.dy);
      
      for (int i = 1; i < tracedPoints.length; i++) {
        path.lineTo(tracedPoints[i].dx, tracedPoints[i].dy);
      }
      
      canvas.drawPath(path, tracePaint);
    }
    
    // Draw dots at key points
    final dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    for (final point in targetPath) {
      canvas.drawCircle(point, 3, dotPaint);
    }
  }
  
  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashWidth = 5.0;
    const double dashSpace = 5.0;
    
    final distance = (end - start).distance;
    final direction = (end - start) / distance;
    
    double currentDistance = 0.0;
    while (currentDistance < distance) {
      final startDash = start + direction * currentDistance;
      final endDash = start + direction * (currentDistance + dashWidth);
      
      canvas.drawLine(
        startDash,
        endDash.distance < distance ? endDash : end,
        paint,
      );
      
      currentDistance += dashWidth + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

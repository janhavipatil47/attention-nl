import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'childAssessment.dart';
import 'sixYearAssessment.dart';

class HandwritingScreeningScreen extends StatefulWidget {
  const HandwritingScreeningScreen({super.key, required this.childAge});

  final int childAge;

  @override
  State<HandwritingScreeningScreen> createState() => _HandwritingScreeningScreenState();
}

class _HandwritingScreeningScreenState extends State<HandwritingScreeningScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _sample;
  Map<String, dynamic>? _result;
  String? _error;
  bool _isChecking = false;

  String get _apiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  Future<void> _chooseSample(ImageSource source) async {
    final XFile? selected = await _picker.pickImage(source: source, imageQuality: 90);
    if (!mounted || selected == null) return;
    setState(() {
      _sample = selected;
      _result = null;
      _error = null;
    });
  }

  Future<void> _analyzeSample() async {
    if (_sample == null) return;
    setState(() {
      _isChecking = true;
      _error = null;
    });
    try {
      final http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiBaseUrl/predict'),
      )..files.add(
          http.MultipartFile.fromBytes(
            'image',
            await _sample!.readAsBytes(),
            filename: _sample!.name,
          ),
        );
      final http.StreamedResponse response = await request.send();
      final Map<String, dynamic> body = jsonDecode(await response.stream.bytesToString());
      if (response.statusCode >= 400) throw Exception(body['error'] ?? 'Analysis failed.');
      if (mounted) setState(() => _result = body);
    } catch (error) {
      if (mounted) setState(() => _error = 'Start the handwriting service, then try again. ($error)');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _continueToActivities() {
    final Widget nextScreen = widget.childAge >= 6
        ? const SixYearAssessmentScreen()
        : const ChildAssessmentScreen();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => nextScreen));
  }

  @override
  Widget build(BuildContext context) {
    final double? probability = (_result?['dyslexiaProbability'] as num?)?.toDouble();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1A2B47)),
        title: const Text('Handwriting Screening', style: TextStyle(color: Color(0xFF1A2B47), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.draw_outlined, size: 64, color: Color(0xFF6E56CF)),
            const SizedBox(height: 12),
            const Text('Handwriting dyslexia screening', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47))),
            const SizedBox(height: 8),
            const Text('Choose a clear handwriting sample. The trained model will analyze it inside NeuroLearn.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.4)),
            const SizedBox(height: 20),
            if (_sample != null)
              FutureBuilder<Uint8List>(
                future: _sample!.readAsBytes(),
                builder: (_, snapshot) => snapshot.hasData
                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(snapshot.data!, height: 210, fit: BoxFit.contain))
                    : const SizedBox(height: 210),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _chooseSample(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: () => _chooseSample(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery'))),
            ]),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: _sample == null || _isChecking ? null : _analyzeSample, icon: const Icon(Icons.analytics_outlined), label: Text(_isChecking ? 'Analyzing...' : 'Analyze Handwriting'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6E56CF), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52))),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            if (probability != null) ...[
              const SizedBox(height: 18),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Text(_result!['verdict'] as String, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), const SizedBox(height: 10), LinearProgressIndicator(value: probability / 100, minHeight: 10), const SizedBox(height: 8), Text('Dyslexia marker probability: ${probability.toStringAsFixed(1)}%'), const SizedBox(height: 8), const Text('Educational screening only, not a medical diagnosis.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54))]))),
            ],
            const SizedBox(height: 18),
            OutlinedButton(onPressed: _continueToActivities, child: const Text('Continue to Activities')),
          ],
        ),
      ),
    );
  }
}
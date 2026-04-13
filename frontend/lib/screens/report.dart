import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, this.reportId});

  final String? reportId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final Future<String?> _reportIdFuture = _resolveReportId();

  Future<String?> _resolveReportId() async {
    if (widget.reportId != null && widget.reportId!.trim().isNotEmpty) {
      return widget.reportId;
    }

    final AuthUser? user = await AuthService.currentUser();
    if (user == null) {
      return null;
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
        .instance
        .collection('assessment_reports')
        .where('userId', isEqualTo: user.id)
        .limit(20)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }
    final List<DocumentSnapshot<Map<String, dynamic>>> docs =
        List<DocumentSnapshot<Map<String, dynamic>>>.from(snapshot.docs);
    docs.sort((DocumentSnapshot<Map<String, dynamic>> a,
        DocumentSnapshot<Map<String, dynamic>> b) {
      final Timestamp? aTs = a.data()?['createdAt'] as Timestamp?;
      final Timestamp? bTs = b.data()?['createdAt'] as Timestamp?;
      final int aMs = aTs?.millisecondsSinceEpoch ?? 0;
      final int bMs = bTs?.millisecondsSinceEpoch ?? 0;
      return bMs.compareTo(aMs);
    });
    return docs.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Assessment Report',
          style: TextStyle(color: Color(0xFF1A2B47), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A2B47)),
      ),
      body: FutureBuilder<String?>(
        future: _reportIdFuture,
        builder: (BuildContext context, AsyncSnapshot<String?> idSnap) {
          if (idSnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final String? reportId = idSnap.data;
          if (reportId == null) {
            return _emptyState('No report found yet. Complete an assessment first.');
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('assessment_reports')
                .doc(reportId)
                .snapshots(),
            builder: (BuildContext context,
                AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final Map<String, dynamic>? data = snap.data?.data();
              if (data == null) {
                return _emptyState('Report data is unavailable.');
              }

              return _buildReportContent(data);
            },
          );
        },
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildReportContent(Map<String, dynamic> data) {
    final Map<String, dynamic> scores =
        (data['scores'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final Map<String, dynamic> skillLabelsRaw =
        (data['skillLabels'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final Map<String, String> skillLabels = skillLabelsRaw.map(
      (String key, dynamic value) => MapEntry<String, String>(key, value.toString()),
    );
    final List<String> scoredSkillKeys =
        (data['scoredSkillKeys'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic item) => item.toString())
            .toList();
    final List<String> assessedActivities =
        (data['assessedActivities'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic item) => item.toString())
            .toList();
    final List<String> insights = (data['insights'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic item) => item.toString())
        .toList();
    final List<String> recommendations =
        (data['recommendations'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic item) => item.toString())
            .toList();
    final Map<String, dynamic> parentQuestionnaire =
        (data['parentQuestionnaire'] as Map<String, dynamic>? ??
            <String, dynamic>{});
    final Map<String, dynamic> email =
        (data['email'] as Map<String, dynamic>? ?? <String, dynamic>{});

    final String childName = (data['childName'] ?? 'Child').toString();
    final String parentName = (data['parentName'] ?? 'Parent').toString();
    final String parentEmail = (data['parentEmail'] ?? '').toString();
    final String childAge = (data['childAge'] ?? '-').toString();
    final String childGrade = (data['childGrade'] ?? '-').toString();
    final String assessmentType = (data['assessmentType'] ?? '').toString();
    final String statusLabel =
        (data['statusLabel'] ?? 'Assessment Complete').toString();
    final double confidence = _readScore(scores, 'confidence');
    final double overall = _readScore(scores, 'overall');
    final String emailStatus = (email['status'] ?? 'queued').toString();
    final bool parentIncluded = parentQuestionnaire['available'] == true;
    final double parentRisk = _asDouble(parentQuestionnaire['overallRisk']);
    final int answeredByParent = _asInt(parentQuestionnaire['answeredQuestions']);
    final List<MapEntry<String, double>> skillEntries =
        _extractSkillEntries(scores, scoredSkillKeys);
    final String generatedAt = _formatCreatedAt(data['createdAt']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _headerCard(
            childName: childName,
            parentName: parentName,
            parentEmail: parentEmail,
            childAge: childAge,
            childGrade: childGrade,
            assessmentType: assessmentType,
            statusLabel: statusLabel,
            overall: overall,
            confidence: confidence,
            emailStatus: emailStatus,
            generatedAt: generatedAt,
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Skill Overview',
            child: Column(
              children: skillEntries.isEmpty
                  ? <Widget>[
                      const Text(
                        'No assessed skills found.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ]
                  : skillEntries.map((MapEntry<String, double> item) {
                      final String label = skillLabels[item.key] ?? item.key;
                      final Color color = _colorForSkill(item.key);
                      return _scoreBar(label, item.value, color);
                    }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Parent Input',
            child: parentIncluded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Included from latest questionnaire responses.',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Parent Responses Used: $answeredByParent questions',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      Text(
                        'Parent Reported Risk: ${parentRisk.toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  )
                : const Text(
                    'Parent questionnaire not found for this report. Score is based on child activity only.',
                    style: TextStyle(color: Colors.black54),
                  ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Assessed Activities',
            child: assessedActivities.isEmpty
                ? const Text('No activity list available.', style: TextStyle(color: Colors.black54))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: assessedActivities
                        .map((String activity) => _activityChip(activity))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Key Insights',
            child: insights.isEmpty
                ? const Text('No insights generated.', style: TextStyle(color: Colors.black54))
                : Column(
                    children: insights
                        .map((String line) => _bullet(line, Colors.blueGrey))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Recommended Actions',
            child: recommendations.isEmpty
                ? const Text('No actions available.', style: TextStyle(color: Colors.black54))
                : Column(
                    children: recommendations
                        .map((String line) => _bullet(line, Colors.teal))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard({
    required String childName,
    required String parentName,
    required String parentEmail,
    required String childAge,
    required String childGrade,
    required String assessmentType,
    required String statusLabel,
    required double overall,
    required double confidence,
    required String emailStatus,
    required String generatedAt,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$childName - Assessment Complete',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Parent: $parentName', style: const TextStyle(color: Colors.black87)),
          if (parentEmail.isNotEmpty)
            Text('Parent Email: $parentEmail', style: const TextStyle(color: Colors.black87)),
          Text('Child Age: $childAge', style: const TextStyle(color: Colors.black87)),
          Text('Child Grade: $childGrade', style: const TextStyle(color: Colors.black87)),
          if (assessmentType.isNotEmpty)
            Text('Assessment Type: $assessmentType', style: const TextStyle(color: Colors.black87)),
          Text('Generated: $generatedAt', style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 8),
          Text(statusLabel, style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _chip('Overall: ${overall.toStringAsFixed(0)}%'),
              _chip('Confidence: ${confidence.toStringAsFixed(0)}%'),
              _chip('Email: $emailStatus'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF275DAD),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _scoreBar(String label, double value, Color color) {
    final double progress = (value / 100).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${value.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: color,
            backgroundColor: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: CircleAvatar(radius: 4, backgroundColor: dotColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _activityChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDEE6FF)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF31477A)),
      ),
    );
  }

  List<MapEntry<String, double>> _extractSkillEntries(
    Map<String, dynamic> scores,
    List<String> scoredSkillKeys,
  ) {
    final Set<String> blocked = <String>{'overall', 'confidence', 'dataCoverage'};
    final List<String> keys = scoredSkillKeys
        .where((String key) => !blocked.contains(key) && scores.containsKey(key))
        .toList();

    if (keys.isEmpty) {
      for (final String key in scores.keys) {
        if (!blocked.contains(key)) {
          keys.add(key);
        }
      }
    }

    return keys
        .map((String key) => MapEntry<String, double>(key, _readScore(scores, key)))
        .toList();
  }

  String _formatCreatedAt(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final DateTime dt = createdAt.toDate();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return 'Just now';
  }

  Color _colorForSkill(String key) {
    final String k = key.toLowerCase();
    if (k.contains('math')) {
      return Colors.teal;
    }
    if (k.contains('listen')) {
      return Colors.indigo;
    }
    if (k.contains('writing')) {
      return Colors.green;
    }
    if (k.contains('memory')) {
      return Colors.purple;
    }
    if (k.contains('attention')) {
      return Colors.orange;
    }
    if (k.contains('reading')) {
      return Colors.blue;
    }
    return Colors.blueGrey;
  }

  double _readScore(Map<String, dynamic> scores, String key) {
    final dynamic value = scores[key];
    if (value is num) {
      return value.toDouble().clamp(0, 100).toDouble();
    }
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  int _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }
}

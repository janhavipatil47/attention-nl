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
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF1A2B47)),
            onPressed: () => _showExportDialog(context),
            tooltip: 'Export Report',
          ),
        ],
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

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: const Text('PDF export feature coming soon. You can screenshot or print this page for now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
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

    final List<String> recommendations =
        (data['recommendations'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic item) => item.toString())
            .toList();
    final List<String> strengths = (data['strengths'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic item) => item.toString())
        .toList();
    final List<String> areasNeedingSupport = (data['areasNeedingSupport'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic item) => item.toString())
        .toList();
    final Map<String, dynamic> email =
        (data['email'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final Map<String, dynamic> activityLevelDetails =
        (data['activityLevelDetails'] as Map<String, dynamic>? ?? <String, dynamic>{});

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
    final String generatedAt = _formatCreatedAt(data['createdAt']);

    // Extract Attention Tracking metrics
    final Map<String, dynamic> rawMetrics =
        (data['rawMetrics'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final Map<String, dynamic> attentionMetrics =
        (data['attentionMetrics'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final double attentionPercentage = (attentionMetrics['attentionPercentage'] as num?)?.toDouble() ??
        (scores['attentionPercentage'] as num?)?.toDouble() ??
        (scores['attention'] as num?)?.toDouble() ??
        (rawMetrics['attentionPercentage'] as num?)?.toDouble() ??
        overall;
    final double attentiveSec = (attentionMetrics['attentiveSeconds'] as num?)?.toDouble() ??
        (rawMetrics['attentiveSeconds'] as num?)?.toDouble() ??
        0.0;
    final double totalSec = (attentionMetrics['totalAttentionTrackedSeconds'] as num?)?.toDouble() ??
        (rawMetrics['totalAttentionTrackedSeconds'] as num?)?.toDouble() ??
        (rawMetrics['sessionDurationSeconds'] as num?)?.toDouble() ??
        0.0;
    final int distractionCount = (attentionMetrics['distractionCount'] as num?)?.toInt() ??
        (rawMetrics['distractionCount'] as num?)?.toInt() ??
        0;
    final bool openCvTracked = attentionMetrics['openCvAttentionTracked'] == true ||
        rawMetrics['openCvAttentionTracked'] == true;
    final Map<String, dynamic> howMeasured =
        (data['howMeasured'] as Map<String, dynamic>? ?? <String, dynamic>{});

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Section 1: Child Information & Header Card
          _headerCard(
            childName: childName,
            parentName: parentName,
            parentEmail: parentEmail,
            childAge: childAge,
            childGrade: childGrade,
            assessmentType: assessmentType,
            statusLabel: statusLabel,
            overall: overall,
            attentionPercentage: attentionPercentage,
            attentionMeasured: openCvTracked && totalSec > 0,
            confidence: confidence,
            emailStatus: emailStatus,
            generatedAt: generatedAt,
          ),
          const SizedBox(height: 16),

          // Section 2: Overall Learning Profile Summary Card
          _overallLearningProfileCard(
            overall: overall,
            statusLabel: statusLabel,
            confidence: confidence,
            scores: scores,
          ),
          const SizedBox(height: 16),

          // Section 3: Visual Attention & Gaze Tracking Card
          _attentionTrackingCard(
            attentionPercentage: attentionPercentage,
            attentiveSec: attentiveSec,
            totalSec: totalSec,
            distractionCount: distractionCount,
            openCvTracked: openCvTracked,
          ),
          const SizedBox(height: 16),

          // Section 4 & 5: Four Domain Performance Cards & Level 1 / Level 2 / Level 3 Activity Performance
          _sectionCard(
            title: 'Domain & Activity Performance',
            child: _buildConsolidatedDomainActivityPerformance(
              scores: scores,
              skillLabels: skillLabels,
              activityLevelDetails: activityLevelDetails,
            ),
          ),
          const SizedBox(height: 16),

          // Section 6: Strengths (Text only, NO percentages)
          if (strengths.isNotEmpty) ...[
            _sectionCard(
              title: 'Strengths',
              child: Column(
                children: strengths
                    .take(4)
                    .map((String line) => _bullet(line, Colors.green))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Section 7: Areas for Additional Practice (Text only, NO percentages)
          if (areasNeedingSupport.isNotEmpty) ...[
            _sectionCard(
              title: 'Areas for Additional Practice',
              child: Column(
                children: areasNeedingSupport
                    .take(5)
                    .map((String line) => _bullet(line, Colors.orange))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Section 8: Recommended Home/Classroom Practice
          _sectionCard(
            title: 'Recommended Home/Classroom Practice',
            child: recommendations.isEmpty
                ? const Text('No recommendations available.', style: TextStyle(color: Colors.black54))
                : Column(
                    children: recommendations
                        .map((String line) => _recommendationCard(line))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),

          // Section 10: How This Assessment Was Measured Card
          _howMeasuredCard(howMeasured),
          const SizedBox(height: 16),

          // Section 11: Educational Screening Disclaimer
          _disclaimerCard(),
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
    required double attentionPercentage,
    required bool attentionMeasured,
    required double confidence,
    required String emailStatus,
    required String generatedAt,
  }) {
    Color statusColor;
    if (overall >= 75) {
      statusColor = Colors.green;
    } else if (overall >= 50) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }

    String statusText;
    if (overall >= 75) {
      statusText = 'On Track';
    } else if (overall >= 50) {
      statusText = 'Moderate Support Needed';
    } else {
      statusText = 'High Support Needed';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.purple.shade100,
                child: Text(
                  childName.isNotEmpty ? childName[0].toUpperCase() : 'C',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$childName — Assessment Summary',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
                    ),
                    const SizedBox(height: 4),
                    Text('Parent: $parentName', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                    if (parentEmail.isNotEmpty)
                      Text('Email: $parentEmail', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _infoChip('Age: $childAge', Icons.cake),
              const SizedBox(width: 8),
              _infoChip('Grade: $childGrade', Icons.school),
              const SizedBox(width: 8),
              _infoChip(
                assessmentType == 'age_3_to_5' ? 'Age 3–5 Assessment' : 'Age 6–7 Assessment',
                Icons.assessment,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metricCircle('Overall Score', '${overall.toStringAsFixed(0)}%', statusColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricCircle(
                  'Attention',
                  attentionMeasured
                      ? '${attentionPercentage.toStringAsFixed(0)}%'
                      : 'Offline',
                  attentionMeasured ? const Color(0xFF6E56CF) : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricCircle('Confidence', '${confidence.toStringAsFixed(0)}%', Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusBadge(statusText, statusColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Overall score is derived directly from performance across all assessed activity domains.',
            style: const TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip('Generated: $generatedAt'),
              const SizedBox(width: 8),
              _chip('Email: ${emailStatus == "sent" ? "Sent to Parent" : (emailStatus == "sending" ? "Sending..." : "Queued")}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attentionTrackingCard({
    required double attentionPercentage,
    required double attentiveSec,
    required double totalSec,
    required int distractionCount,
    required bool openCvTracked,
  }) {
    final bool isMeasured = openCvTracked && totalSec > 0;

    if (!isMeasured) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off_outlined, color: Colors.grey, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visual Attention: Not Measured',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2B47),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Camera visual focus tracking was not enabled during this assessment session. To measure the child\'s visual focus and enable focus reminders, ensure camera tracking is active before starting.',
                    style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Color barColor;
    String statusTitle;
    String statusDesc;
    if (attentionPercentage >= 80) {
      barColor = const Color(0xFF2E7D32);
      statusTitle = 'High Sustained Attention';
      statusDesc = 'The child maintained strong focus on the screen with minimal look-away distractions.';
    } else if (attentionPercentage >= 60) {
      barColor = const Color(0xFFF57C00);
      statusTitle = 'Moderate Attention';
      statusDesc = 'The child was generally attentive, with occasional gaze wandering away from the assessment.';
    } else {
      barColor = const Color(0xFFD32F2F);
      statusTitle = 'Needs Focus Support';
      statusDesc = 'The child frequently looked away from the assessment window. Shorter activity intervals and visual refocusing cues are recommended.';
    }

    final int attentiveMin = (attentiveSec / 60).floor();
    final int attentiveRemainderSec = (attentiveSec % 60).round();
    final String attentiveFormatted = '${attentiveMin}m ${attentiveRemainderSec}s';

    final int totalMin = (totalSec / 60).floor();
    final int totalRemainderSec = (totalSec % 60).round();
    final String totalFormatted = '${totalMin}m ${totalRemainderSec}s';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6E56CF).withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6E56CF).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6E56CF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF6E56CF), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visual Attention & Focus Tracking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2B47),
                      ),
                    ),
                    Text(
                      'Monitored live via screen visual focus tracking',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: barColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${attentionPercentage.toStringAsFixed(0)}% Attention',
                  style: TextStyle(
                    color: barColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (attentionPercentage / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _attentionStatTile(
                  label: 'Screen Attention',
                  value: '${attentionPercentage.toStringAsFixed(0)}%',
                  icon: Icons.track_changes,
                  color: const Color(0xFF6E56CF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _attentionStatTile(
                  label: 'Focused Time',
                  value: totalSec > 0 ? '$attentiveFormatted / $totalFormatted' : '${attentionPercentage.toStringAsFixed(0)}%',
                  icon: Icons.timer_outlined,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _attentionStatTile(
                  label: 'Look-Away Alerts',
                  value: '$distractionCount',
                  icon: Icons.notifications_active_outlined,
                  color: distractionCount > 3 ? Colors.red.shade600 : Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  attentionPercentage >= 80 ? Icons.check_circle : Icons.info_outline,
                  color: barColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$statusTitle: $statusDesc',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overallLearningProfileCard({
    required double overall,
    required String statusLabel,
    required double confidence,
    required Map<String, dynamic> scores,
  }) {
    Color statusColor;
    if (overall >= 75) {
      statusColor = Colors.green;
    } else if (overall >= 50) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Learning Profile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Overall Score',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${overall.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Data Reliability',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${confidence.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Measured',
                        style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _howMeasuredCard(Map<String, dynamic> howMeasured) {
    final String title = (howMeasured['title'] as String?) ?? 'How This Assessment Was Measured';
    final String desc = (howMeasured['description'] as String?) ?? '';
    final List<String> points = (howMeasured['points'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => e.toString())
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.indigo, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
                ),
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3)),
          ],
          const SizedBox(height: 12),
          Column(
            children: points
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 14, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(p, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.35)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _attentionStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF275DAD)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF275DAD),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCircle(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Status',
            style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConsolidatedDomainActivityPerformance({
    required Map<String, dynamic> scores,
    required Map<String, String> skillLabels,
    required Map<String, dynamic> activityLevelDetails,
  }) {
    final List<Map<String, dynamic>> activityDetails =
        (activityLevelDetails['activityDetails'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    // Group activities by domain
    final Map<String, List<Map<String, dynamic>>> domainActivities = {};
    for (final activity in activityDetails) {
      final String domain = (activity['domain'] as String?) ?? 'other';
      domainActivities.putIfAbsent(domain, () => []).add(activity);
    }

    final List<String> domainOrder = [
      'reading_language',
      'writing_tracing',
      'math',
      'attention',
      'memory',
      'listening',
    ];

    final List<Widget> domainCards = <Widget>[];

    for (final domainKey in domainOrder) {
      final double domainScore = _readScore(scores, domainKey);
      final List<Map<String, dynamic>> activities = domainActivities[domainKey] ?? [];

      if (!scores.containsKey(domainKey) && activities.isEmpty) {
        continue;
      }

      final String domainLabel = skillLabels[domainKey] ?? _defaultLabelForDomain(domainKey);
      final Color color = _colorForSkill(domainKey);

      domainCards.add(
        _DomainActivityConsolidatedCard(
          domainKey: domainKey,
          domainLabel: domainLabel,
          domainScore: domainScore,
          activities: activities,
          color: color,
        ),
      );
      domainCards.add(const SizedBox(height: 12));
    }

    if (domainCards.isEmpty) {
      return const Text('No assessed domain data available.', style: TextStyle(color: Colors.black54));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: domainCards,
    );
  }

  String _defaultLabelForDomain(String key) {
    switch (key) {
      case 'reading_language':
        return 'Reading & Language';
      case 'writing_tracing':
        return 'Writing & Tracing';
      case 'math':
        return 'Math & Number Sense';
      case 'attention':
        return 'Attention & Focus';
      case 'memory':
        return 'Memory & Matching';
      case 'listening':
        return 'Listening';
      default:
        return key.replaceAll('_', ' ').toUpperCase();
    }
  }

  Widget _recommendationCard(String text) {
    final lines = text.split('\n');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return const SizedBox.shrink();
          if (trimmed.startsWith('•') || trimmed.startsWith('-')) {
            return Padding(
              padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 13, color: Colors.teal)),
                  Expanded(child: Text(trimmed.substring(1).trim(), style: const TextStyle(fontSize: 13, height: 1.4))),
                ],
              ),
            );
          } else if (trimmed.contains(':') && !trimmed.contains('•')) {
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                trimmed,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47)),
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(trimmed, style: const TextStyle(fontSize: 13, height: 1.4)),
            );
          }
        }).toList(),
      ),
    );
  }

  Widget _disclaimerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel, color: Colors.grey, size: 20),
              SizedBox(width: 8),
              Text(
                'Important',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'This report is based on gamified assessment activities from a single session. Results may vary based on engagement, fatigue, and environment. This report is for educational support only, not a medical diagnosis.',
            style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.5),
          ),
        ],
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
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2B47))),
          const SizedBox(height: 12),
          child,
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
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF275DAD),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
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
    if (k.contains('writing') || k.contains('tracing')) {
      return Colors.green;
    }
    if (k.contains('memory')) {
      return Colors.purple;
    }
    if (k.contains('attention')) {
      return Colors.orange;
    }
    if (k.contains('reading') || k.contains('language')) {
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
}

class _DomainActivityConsolidatedCard extends StatefulWidget {
  final String domainKey;
  final String domainLabel;
  final double domainScore;
  final List<Map<String, dynamic>> activities;
  final Color color;

  const _DomainActivityConsolidatedCard({
    required this.domainKey,
    required this.domainLabel,
    required this.domainScore,
    required this.activities,
    required this.color,
  });

  @override
  State<_DomainActivityConsolidatedCard> createState() =>
      __DomainActivityConsolidatedCardState();
}

class __DomainActivityConsolidatedCardState
    extends State<_DomainActivityConsolidatedCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    String status;
    Color statusColor;
    if (widget.domainScore >= 75) {
      status = 'On Track';
      statusColor = Colors.green;
    } else if (widget.domainScore >= 50) {
      status = 'Developing';
      statusColor = Colors.orange;
    } else {
      status = 'Needs Practice';
      statusColor = Colors.red;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.activities.isNotEmpty
                ? () => setState(() => _expanded = !_expanded)
                : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconForDomain(widget.domainLabel), color: widget.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.domainLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2B47),
                              ),
                            ),
                            Text(
                              '${widget.activities.length} ${widget.activities.length == 1 ? "activity" : "activities"} assessed',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${widget.domainScore.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: widget.color,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      if (widget.activities.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.black54,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (widget.domainScore / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: widget.color,
                    backgroundColor: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && widget.activities.isNotEmpty) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: widget.activities
                    .map((activity) => _activityRow(activity, widget.color))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _activityRow(Map<String, dynamic> activity, Color domainColor) {
    final String name = (activity['activityName'] as String?) ?? 'Activity';
    final String skill = (activity['targetSkill'] as String?) ?? 'General Skill';
    final int highestLevel = (activity['highestLevelReached'] as num?)?.toInt() ??
        (activity['selectedLevel'] as num?)?.toInt() ?? 1;
    final double accuracy = (activity['accuracy'] as num?)?.toDouble() ?? 0.0;
    final int attempts = (activity['attempts'] as num?)?.toInt() ?? 0;
    final int hints = (activity['hintsUsed'] as num?)?.toInt() ?? 0;
    final String performance = (activity['performanceLevel'] as String?) ?? 'Developing';
    final List<dynamic> levels = (activity['levels'] as List<dynamic>? ?? []);
    final bool isMultiLevel = levels.length > 1;

    final bool notAssessed = attempts == 0 && performance == 'Not Assessed';

    Color perfColor;
    String perfText;
    if (notAssessed) {
      perfColor = Colors.grey;
      perfText = 'Not Assessed';
    } else {
      switch (performance) {
        case 'Proficient':
          perfColor = Colors.green;
          perfText = 'Strong';
          break;
        case 'Developing':
          perfColor = Colors.orange;
          perfText = 'Developing';
          break;
        default:
          perfColor = Colors.red;
          perfText = 'Needs Practice';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A2B47))),
                    Text(skill, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: perfColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isMultiLevel ? 'Max L$highestLevel • $perfText' : perfText,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: perfColor),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notAssessed ? 'Not assessed' : '${accuracy.toStringAsFixed(0)}% overall',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: notAssessed ? Colors.grey : perfColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (isMultiLevel) ...[
                _chipBadge('Highest: Level $highestLevel', Icons.layers, domainColor),
                const SizedBox(width: 6),
              ],
              _chipBadge('$attempts ${attempts == 1 ? "attempt" : "attempts"}', Icons.replay, Colors.blueGrey),
              const SizedBox(width: 6),
              _chipBadge('$hints ${hints == 1 ? "hint" : "hints"}', Icons.lightbulb_outline, Colors.amber.shade700),
            ],
          ),
          if (isMultiLevel) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '3-Level Assessment Progression:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  ...levels.map((lvlItem) {
                    final lvlMap = Map<String, dynamic>.from(lvlItem as Map);
                    final int lvlNum = (lvlMap['level'] as num).toInt();
                    final bool attempted = lvlMap['attempted'] == true;
                    final double lvlAcc = (lvlMap['accuracy'] as num?)?.toDouble() ?? 0.0;
                    final String lvlPerf = (lvlMap['performanceLevel'] as String?) ?? 'Not Assessed';

                    Color lvlColor;
                    String lvlStatusText;
                    if (!attempted) {
                      lvlColor = Colors.grey;
                      lvlStatusText = 'Not Assessed';
                    } else if (lvlPerf == 'Proficient') {
                      lvlColor = Colors.green;
                      lvlStatusText = '${lvlAcc.toStringAsFixed(0)}% • Proficient ✓';
                    } else if (lvlPerf == 'Developing') {
                      lvlColor = Colors.orange;
                      lvlStatusText = '${lvlAcc.toStringAsFixed(0)}% • Developing';
                    } else {
                      lvlColor = Colors.red;
                      lvlStatusText = '${lvlAcc.toStringAsFixed(0)}% • Needs Support';
                    }

                    String levelName;
                    switch (lvlNum) {
                      case 1:
                        levelName = 'Level 1 — Foundation';
                        break;
                      case 2:
                        levelName = 'Level 2 — Developing';
                        break;
                      case 3:
                        levelName = 'Level 3 — Challenge';
                        break;
                      default:
                        levelName = 'Level $lvlNum';
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            levelName,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
                          ),
                          Text(
                            lvlStatusText,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: lvlColor),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          if (!notAssessed) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (accuracy / 100).clamp(0.0, 1.0),
              minHeight: 4,
              color: perfColor,
              backgroundColor: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  IconData _iconForDomain(String label) {
    final String lower = label.toLowerCase();
    if (lower.contains('reading') || lower.contains('language')) return Icons.menu_book;
    if (lower.contains('writing') || lower.contains('tracing')) return Icons.edit;
    if (lower.contains('math') || lower.contains('number')) return Icons.calculate;
    if (lower.contains('attention') || lower.contains('focus')) return Icons.center_focus_strong;
    if (lower.contains('memory') || lower.contains('match')) return Icons.psychology;
    if (lower.contains('listen')) return Icons.hearing;
    return Icons.category;
  }
}
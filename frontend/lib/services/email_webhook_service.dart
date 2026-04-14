import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmailWebhookResult {
  const EmailWebhookResult({
    required this.success,
    required this.statusCode,
    required this.message,
  });

  final bool success;
  final int statusCode;
  final String message;
}

class EmailWebhookService {
  static const String _webhookKey = 'appsScriptWebhookUrl';
  static const String _relayWebhookKey = 'relayWebhookUrl';
  static const String _defaultWebhookUrl =
      'https://script.google.com/macros/s/AKfycby9_Ywff18rHNDk4FfaV5Ew6WFRYiDN-uzM-cVfpphIbnvhd8yRXaaRoSqyNtdKQF8Wfg/exec';
  static const String _defaultRelayWebhookUrl =
      'https://long-wave-5c16.2023-vaishnavi-kumbhar.workers.dev/';
  static const String _webhookFromEnv = String.fromEnvironment(
    'APPS_SCRIPT_WEBHOOK_URL',
  );
  static const String _relayFromEnv = String.fromEnvironment(
    'CLOUDFLARE_RELAY_URL',
  );

  static Future<void> setWebhookUrl(String url) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webhookKey, url.trim());
  }

  static Future<void> setRelayUrl(String url) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_relayWebhookKey, url.trim());
  }

  static Future<String> getWebhookUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      if (_relayFromEnv.trim().isNotEmpty) {
        return _relayFromEnv.trim();
      }
      final String savedRelay = (prefs.getString(_relayWebhookKey) ?? '')
          .trim();
      if (savedRelay.isNotEmpty) {
        return savedRelay;
      }
      if (_defaultRelayWebhookUrl.trim().isNotEmpty) {
        return _defaultRelayWebhookUrl.trim();
      }
    }

    if (_webhookFromEnv.trim().isNotEmpty) {
      return _webhookFromEnv.trim();
    }

    final String saved = (prefs.getString(_webhookKey) ?? '').trim();
    if (saved.isNotEmpty) {
      return saved;
    }
    return _defaultWebhookUrl;
  }

  static Future<EmailWebhookResult> sendAssessmentReport({
    required Map<String, dynamic> reportPayload,
  }) async {
    final String webhookUrl = await getWebhookUrl();
    if (webhookUrl.isEmpty) {
      return const EmailWebhookResult(
        success: false,
        statusCode: 0,
        message: 'Webhook URL is not configured.',
      );
    }

    try {
      final http.Response response = await http
          .post(
            Uri.parse(webhookUrl),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(reportPayload),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final String body = response.body.isEmpty ? '{}' : response.body;
        try {
          final dynamic parsed = jsonDecode(body);
          if (parsed is Map<String, dynamic>) {
            final dynamic okFlag = parsed['ok'];
            if (okFlag == false) {
              return EmailWebhookResult(
                success: false,
                statusCode: response.statusCode,
                message:
                    (parsed['error'] ??
                            parsed['message'] ??
                            'Webhook reported failure')
                        .toString(),
              );
            }
          }
        } catch (_) {
          // Non-JSON 2xx body is treated as success.
        }

        return EmailWebhookResult(
          success: true,
          statusCode: response.statusCode,
          message: response.body.isEmpty ? 'ok' : response.body,
        );
      }

      return EmailWebhookResult(
        success: false,
        statusCode: response.statusCode,
        message: response.body.isEmpty
            ? 'Webhook call failed with status ${response.statusCode}'
            : response.body,
      );
    } catch (error) {
      return EmailWebhookResult(
        success: false,
        statusCode: 0,
        message: error.toString(),
      );
    }
  }
}

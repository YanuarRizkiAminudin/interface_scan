import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/ai_config.dart';
import '../models/finding.dart';
import '../models/ocr_result.dart';
import '../models/visual_metrics.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Typed error class
// ─────────────────────────────────────────────────────────────────────────────

/// Describes why an AI request failed so the UI can show a clear message.
enum AiErrorKind {
  /// API key is missing or was never set.
  noKey,

  /// API key is present but rejected by Google (401/403).
  invalidKey,

  /// The requested model ID was not found (404).
  modelNotFound,

  /// Request exceeded quota / rate limit (429).
  rateLimited,

  /// Network unreachable or request timed out.
  networkError,

  /// Any other non-200 HTTP status.
  serverError,

  /// The response arrived but could not be parsed as valid JSON.
  parseError,
}

class AiException implements Exception {
  final AiErrorKind kind;
  final String message;
  final int? httpStatus;

  const AiException({
    required this.kind,
    required this.message,
    this.httpStatus,
  });

  /// Returns a short, user-friendly string suitable for display in the app.
  String get userMessage {
    switch (kind) {
      case AiErrorKind.noKey:
        return 'AI API key is not configured. '
            'Go to Settings to add your Gemini key.';
      case AiErrorKind.invalidKey:
        return 'API key rejected by Google. '
            'Check the key in Settings (it may have expired or be incorrect).';
      case AiErrorKind.modelNotFound:
        return 'Model "$kGeminiModel" was not found. '
            'The app may need an update.';
      case AiErrorKind.rateLimited:
        return 'Gemini API rate limit reached. '
            'Wait a moment and try again.';
      case AiErrorKind.networkError:
        return 'Network error – check your internet connection and try again.';
      case AiErrorKind.serverError:
        return 'Gemini API returned an error (HTTP $httpStatus). '
            'Try again later.';
      case AiErrorKind.parseError:
        return 'Could not parse the AI response. Try again.';
    }
  }

  @override
  String toString() => 'AiException(${kind.name}): $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

/// Calls the Google Gemini API to generate Nielsen heuristic suggestions.
///
/// All failures are surfaced as [AiException] with a [userMessage] suitable
/// for display — the caller does not need to parse raw HTTP errors.
class AiService {
  final String apiKey;
  final _uuid = const Uuid();

  AiService({required this.apiKey});

  bool get isConfigured => apiKey.trim().isNotEmpty;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns heuristic [Finding] suggestions for the given screenshot data.
  ///
  /// [screenshotIndex] — 1-based index of the screenshot being analysed.
  /// Pass null when calling with aggregated multi-screenshot data.
  ///
  /// Throws [AiException] on any failure (key, network, model, parse).
  Future<List<Finding>> getSuggestions({
    required VisualMetrics metrics,
    required OcrResult ocrResult,
    int? screenshotIndex,
  }) async {
    if (!isConfigured) {
      throw const AiException(
        kind: AiErrorKind.noKey,
        message: 'apiKey is empty',
      );
    }

    final endpoint =
        '$kGeminiBaseUrl$kGeminiModel:generateContent?key=$apiKey';
    final uri = Uri.parse(endpoint);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _buildPrompt(metrics: metrics, ocrResult: ocrResult, screenshotIndex: screenshotIndex)},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 2048,
        'responseMimeType': 'application/json',
      },
    });

    http.Response response;
    try {
      response = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));
    } on SocketException catch (e) {
      throw AiException(
          kind: AiErrorKind.networkError, message: e.message);
    } on TimeoutException {
      throw const AiException(
          kind: AiErrorKind.networkError,
          message: 'Request timed out after 30 s');
    }

    _checkStatus(response);
    return _parseResponse(response.body, screenshotIndex: screenshotIndex);
  }

  // ── HTTP status → AiException ──────────────────────────────────────────────

  void _checkStatus(http.Response response) {
    final status = response.statusCode;
    if (status == 200) return;

    // Try to extract a useful message from the Google error body
    String detail = '';
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final err = decoded['error'] as Map<String, dynamic>?;
      detail = err?['message'] as String? ?? '';
    } catch (_) {
      detail = response.body.length > 200
          ? response.body.substring(0, 200)
          : response.body;
    }

    switch (status) {
      case 400:
        // Usually "API key not valid" or malformed request
        final lower = detail.toLowerCase();
        if (lower.contains('api key') || lower.contains('key not valid')) {
          throw AiException(
              kind: AiErrorKind.invalidKey,
              message: detail,
              httpStatus: status);
        }
        throw AiException(
            kind: AiErrorKind.serverError,
            message: detail,
            httpStatus: status);
      case 401:
      case 403:
        throw AiException(
            kind: AiErrorKind.invalidKey,
            message: detail,
            httpStatus: status);
      case 404:
        throw AiException(
            kind: AiErrorKind.modelNotFound,
            message: detail,
            httpStatus: status);
      case 429:
        throw AiException(
            kind: AiErrorKind.rateLimited,
            message: detail,
            httpStatus: status);
      default:
        throw AiException(
            kind: AiErrorKind.serverError,
            message: detail,
            httpStatus: status);
    }
  }

  // ── Prompt builder ─────────────────────────────────────────────────────────

  String _buildPrompt({
    required VisualMetrics metrics,
    required OcrResult ocrResult,
    int? screenshotIndex,
  }) {
    final screenContext = screenshotIndex != null
        ? '\n### Screenshot\nThis analysis covers screenshot #$screenshotIndex.'
        : '';
    return '''
You are a UI/UX usability expert evaluating a screenshot using Nielsen's 10 Usability Heuristics.$screenContext

### Image Metrics (automated analysis)
- Image size: ${metrics.imageWidth} × ${metrics.imageHeight} px
- Edge density: ${metrics.edgeDensity.toStringAsFixed(4)} (${metrics.edgeDensityInterpretation})
- Low-detail area: ${metrics.lowDetailAreaRatio.toStringAsFixed(4)} (${metrics.lowDetailInterpretation})
- Contrast score: ${metrics.contrastScore.toStringAsFixed(4)} (${metrics.contrastInterpretation})
- Contour density: ${metrics.contourDensity.toStringAsFixed(2)} regions per 10 000 px
- Mean luminance: ${metrics.meanLuminance.toStringAsFixed(1)} / 255

### OCR Text
${ocrResult.aiSummary}

### Task
Identify 3–6 usability issues using Nielsen's 10 Heuristics.
For each issue provide: heuristicId (1–10), title, reason, recommendation, confidence (0.0–1.0).

### Response Format
Return ONLY a valid JSON array:
[{"heuristicId":<int>,"title":"<str>","reason":"<str>","recommendation":"<str>","confidence":<float>}]
''';
  }

  // ── Response parser ────────────────────────────────────────────────────────

  List<Finding> _parseResponse(String body, {int? screenshotIndex}) {
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException(
          kind: AiErrorKind.parseError,
          message: 'Top-level JSON decode failed');
    }

    final candidates = decoded['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) return [];

    final parts = ((candidates[0] as Map<String, dynamic>)['content']
            as Map<String, dynamic>?)?['parts'] as List<dynamic>? ??
        [];
    if (parts.isEmpty) return [];

    final rawText = (parts[0] as Map<String, dynamic>)['text'] as String? ?? '';

    List<dynamic> items;
    try {
      final cleaned = rawText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      items = jsonDecode(cleaned) as List<dynamic>;
    } catch (_) {
      throw const AiException(
          kind: AiErrorKind.parseError,
          message: 'Inner JSON array decode failed');
    }

    final findings = <Finding>[];
    for (final item in items) {
      try {
        final map = item as Map<String, dynamic>;
        findings.add(Finding(
          id: _uuid.v4(),
          heuristicId: (map['heuristicId'] as num).toInt().clamp(1, 10),
          title: map['title'] as String? ?? 'Untitled Finding',
          reason: map['reason'] as String? ?? '',
          recommendation: map['recommendation'] as String? ?? '',
          confidence:
              ((map['confidence'] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0),
          screenshotIndex: screenshotIndex,
          severity: 2,
          status: FindingStatus.pending,
        ));
      } catch (_) {
        continue; // skip malformed items
      }
    }
    return findings;
  }
}

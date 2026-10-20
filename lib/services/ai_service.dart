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
// Error types
// ─────────────────────────────────────────────────────────────────────────────

enum AiErrorKind {
  noKey, invalidKey, modelNotFound, rateLimited, networkError, serverError, parseError,
}

class AiException implements Exception {
  final AiErrorKind kind;
  final String message;
  final int? httpStatus;

  const AiException({required this.kind, required this.message, this.httpStatus});

  String get userMessage {
    switch (kind) {
      case AiErrorKind.noKey:
        return 'AI API key not configured. Go to Settings to add your Gemini key.';
      case AiErrorKind.invalidKey:
        return 'API key rejected by Google. Check the key in Settings.';
      case AiErrorKind.modelNotFound:
        return 'Model "$kGeminiModel" not found. The app may need an update.';
      case AiErrorKind.rateLimited:
        return 'Gemini API rate limit reached. Wait and try again.';
      case AiErrorKind.networkError:
        return 'Network error – check your internet connection.';
      case AiErrorKind.serverError:
        return 'Gemini API error (HTTP $httpStatus). Try again later.';
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

class AiService {
  final String apiKey;
  final _uuid = const Uuid();

  AiService({required this.apiKey});

  bool get isConfigured => apiKey.trim().isNotEmpty;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<List<Finding>> getSuggestions({
    required VisualMetrics metrics,
    required OcrResult ocrResult,
    int? screenshotIndex,
    String appName = '',
    String mainTask = '',
  }) async {
    if (!isConfigured) {
      throw const AiException(kind: AiErrorKind.noKey, message: 'apiKey is empty');
    }

    final uri = Uri.parse('$kGeminiBaseUrl$kGeminiModel:generateContent?key=$apiKey');

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': _buildPrompt(
                metrics: metrics,
                ocrResult: ocrResult,
                screenshotIndex: screenshotIndex,
                appName: appName,
                mainTask: mainTask,
              ),
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 4096,
        'responseMimeType': 'application/json',
      },
    });

    http.Response response;
    try {
      response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 45));
    } on SocketException catch (e) {
      throw AiException(kind: AiErrorKind.networkError, message: e.message);
    } on TimeoutException {
      throw const AiException(
          kind: AiErrorKind.networkError, message: 'Request timed out after 45 s');
    }

    _checkStatus(response);
    return _parseResponse(response.body, screenshotIndex: screenshotIndex);
  }

  // ── HTTP status check ──────────────────────────────────────────────────────

  void _checkStatus(http.Response response) {
    final status = response.statusCode;
    if (status == 200) return;

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
        final lower = detail.toLowerCase();
        if (lower.contains('api key') || lower.contains('key not valid')) {
          throw AiException(kind: AiErrorKind.invalidKey, message: detail, httpStatus: status);
        }
        throw AiException(kind: AiErrorKind.serverError, message: detail, httpStatus: status);
      case 401:
      case 403:
        throw AiException(kind: AiErrorKind.invalidKey, message: detail, httpStatus: status);
      case 404:
        throw AiException(kind: AiErrorKind.modelNotFound, message: detail, httpStatus: status);
      case 429:
        throw AiException(kind: AiErrorKind.rateLimited, message: detail, httpStatus: status);
      default:
        throw AiException(kind: AiErrorKind.serverError, message: detail, httpStatus: status);
    }
  }

  // ── Prompt ────────────────────────────────────────────────────────────────
  //
  // The prompt is structured to:
  // 1. Give the AI full context: app name, user task, screenshot number,
  //    concrete visual metrics, and all extracted OCR text.
  // 2. List all 10 Nielsen heuristics explicitly so the AI evaluates each one
  //    systematically rather than guessing the most obvious issues.
  // 3. Require severity (0–4) and affectedElement in the JSON response
  //    so those fields are populated from real AI analysis, not defaults.

  String _buildPrompt({
    required VisualMetrics metrics,
    required OcrResult ocrResult,
    int? screenshotIndex,
    String appName = '',
    String mainTask = '',
  }) {
    final screenLabel = screenshotIndex != null
        ? 'Screenshot #$screenshotIndex'
        : 'Aggregated screenshots';
    final appCtx = appName.isNotEmpty ? 'App/Website: $appName' : '';
    final taskCtx = mainTask.isNotEmpty ? 'User task: $mainTask' : '';
    final context = [appCtx, taskCtx].where((s) => s.isNotEmpty).join('\n');
    final ocrText = ocrResult.fullText.isEmpty
        ? '[No text detected]'
        : ocrResult.fullText.length > 1000
            ? '${ocrResult.fullText.substring(0, 1000)}…'
            : ocrResult.fullText;

    return '''
You are a senior UX evaluator. Analyse a UI screenshot using Jakob Nielsen's 10 Usability Heuristics.

## Evaluation Context
$context
Analysing: $screenLabel

## Automated Image Analysis
- Image: ${metrics.imageWidth} × ${metrics.imageHeight} px
- Edge density: ${metrics.edgeDensity.toStringAsFixed(4)} → ${metrics.edgeDensityInterpretation}
- Low-detail area: ${(metrics.lowDetailAreaRatio * 100).toStringAsFixed(1)}% → ${metrics.lowDetailInterpretation}
- Contrast (Michelson): ${metrics.contrastScore.toStringAsFixed(4)} → ${metrics.contrastInterpretation}
- Contour density: ${metrics.contourDensity.toStringAsFixed(2)} regions / 10,000 px
- Mean luminance: ${metrics.meanLuminance.toStringAsFixed(1)} / 255

## OCR Text Extracted (${ocrResult.blockCount} blocks)
$ocrText

## Nielsen's 10 Heuristics — check EACH one:
H1 Visibility of System Status — loading indicators, progress bars, status messages
H2 Match System to Real World — familiar language, real-world conventions
H3 User Control & Freedom — undo/redo, clear exits, cancel buttons
H4 Consistency & Standards — same visual pattern for same function
H5 Error Prevention — constraints, confirmations, safe defaults
H6 Recognition Not Recall — visible options, no need to memorise paths
H7 Flexibility & Efficiency — shortcuts, accelerators for expert users
H8 Aesthetic & Minimalist Design — no clutter, every element earns its place
H9 Error Recovery — clear error messages, constructive suggestions
H10 Help & Documentation — help text, tooltips, documentation when needed

## Instructions
1. Evaluate EACH heuristic against the evidence above.
2. For every problem you find, cite SPECIFIC evidence:
   - Contrast < 0.4 → mention exact value for H1 or H8
   - Edge density > 0.15 → visual clutter, cite for H8
   - OCR shows vague labels ("Click here", "Submit") → cite for H2 or H6
   - No status-related text in OCR → possible H1 issue
   - Long OCR without structure → possible H6 or H8 issue
3. Assign severity honestly:
   0 = Cosmetic (no real impact)
   1 = Minor (slight friction)
   2 = Medium (noticeable friction)
   3 = Major (significant usability barrier)
   4 = Catastrophic (blocks task completion)
4. Only report issues with concrete evidence. Skip heuristics that look fine.
5. Return 3–8 findings maximum.

## Response: ONLY a valid JSON array, nothing else
[
  {
    "heuristicId": <int 1-10>,
    "title": "<short title, max 60 chars>",
    "affectedElement": "<specific UI element, e.g. Login button, Search bar, Error message>",
    "reason": "<detailed explanation citing specific metric values or OCR text>",
    "recommendation": "<concrete actionable fix>",
    "severity": <int 0-4>,
    "confidence": <float 0.0-1.0>
  }
]
''';
  }

  // ── Response parser ────────────────────────────────────────────────────────

  List<Finding> _parseResponse(String body, {int? screenshotIndex}) {
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException(
          kind: AiErrorKind.parseError, message: 'Top-level JSON decode failed');
    }

    final candidates = decoded['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) return [];

    final parts = ((candidates[0] as Map<String, dynamic>)['content']
            as Map<String, dynamic>?)?['parts'] as List<dynamic>? ?? [];
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
          kind: AiErrorKind.parseError, message: 'Inner JSON array decode failed');
    }

    final findings = <Finding>[];
    for (final item in items) {
      try {
        final map = item as Map<String, dynamic>;
        // Use AI-provided severity; fallback to 2 if invalid
        final aiSeverity = ((map['severity'] as num?)?.toInt() ?? 2).clamp(0, 4);

        findings.add(Finding(
          id: _uuid.v4(),
          heuristicId: (map['heuristicId'] as num).toInt().clamp(1, 10),
          title: map['title'] as String? ?? 'Untitled Finding',
          affectedElement: map['affectedElement'] as String? ?? '',
          reason: map['reason'] as String? ?? '',
          recommendation: map['recommendation'] as String? ?? '',
          confidence: ((map['confidence'] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0),
          screenshotIndex: screenshotIndex,
          severity: aiSeverity,          // ← from AI, not hardcoded default 2
          status: FindingStatus.pending,
        ));
      } catch (_) {
        continue;
      }
    }
    return findings;
  }
}

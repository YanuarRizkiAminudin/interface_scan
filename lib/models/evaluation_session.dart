import 'dart:convert';

import 'finding.dart';
import 'ocr_result.dart';
import 'screenshot_analysis.dart';
import 'visual_metrics.dart';

/// The full state of one UI evaluation, persisted to local storage.
class EvaluationSession {
  final String id;

  // ── Discover phase context ─────────────────────────────────────────────────

  /// Name of the evaluated application or website.
  /// e.g. "Tokopedia", "BCA Mobile", "Gmail"
  String appName;

  /// The main user task being evaluated.
  /// e.g. "Melakukan transfer bank", "Mencari dan membeli produk"
  String mainTask;

  /// User-supplied label for the whole evaluation session.
  String name;

  // ── Screenshots (1–5) ─────────────────────────────────────────────────────

  /// Ordered list of per-screenshot analysis results.
  /// A session must have at least 1 and at most 5 screenshots.
  List<ScreenshotAnalysis> screenshots;

  // ── Legacy single-image path (kept for backwards-compat with storage) ──────
  // Points to the first screenshot's path; used by comparison screen.
  String get originalImagePath =>
      screenshots.isNotEmpty ? screenshots.first.imagePath : '';

  /// Optional absolute path to the redesigned screenshot.
  String? redesignImagePath;

  // ── Timestamps ────────────────────────────────────────────────────────────

  final DateTime createdAt;
  DateTime updatedAt;

  // ── Aggregate results ──────────────────────────────────────────────────────

  /// Aggregated visual metrics across all screenshots.
  /// These are computed as averages / sums after all screenshots are analysed.
  VisualMetrics? visualMetrics;

  /// Aggregated OCR result (concatenation of all screenshots' text).
  OcrResult? ocrResult;

  /// AI-suggested + human-reviewed findings (shared across all screenshots).
  List<Finding> findings;

  /// Optional free-form notes from the evaluator.
  String? notes;

  EvaluationSession({
    required this.id,
    this.appName = '',
    this.mainTask = '',
    required this.name,
    List<ScreenshotAnalysis>? screenshots,
    this.redesignImagePath,
    required this.createdAt,
    required this.updatedAt,
    this.visualMetrics,
    this.ocrResult,
    List<Finding>? findings,
    this.notes,

    // Legacy: accept a bare path and convert it to a ScreenshotAnalysis
    String? originalImagePath,
  })  : screenshots = screenshots ??
            (originalImagePath != null && originalImagePath.isNotEmpty
                ? [ScreenshotAnalysis(imagePath: originalImagePath, index: 1)]
                : []),
        findings = findings ?? [];

  // ── Derived helpers ────────────────────────────────────────────────────────

  int get screenshotCount => screenshots.length;
  bool get hasScreenshots => screenshots.isNotEmpty;
  bool get allAnalyzed =>
      screenshots.isNotEmpty && screenshots.every((s) => s.isAnalyzed);

  int get totalFindings => findings.length;
  int get acceptedCount =>
      findings.where((f) => f.status == FindingStatus.accepted).length;
  int get rejectedCount =>
      findings.where((f) => f.status == FindingStatus.rejected).length;
  int get pendingCount =>
      findings.where((f) => f.status == FindingStatus.pending).length;

  List<Finding> get acceptedFindings =>
      findings.where((f) => f.status == FindingStatus.accepted).toList()
        ..sort((a, b) => b.severity.compareTo(a.severity));

  bool get hasRedesign => redesignImagePath != null;

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'appName': appName,
        'mainTask': mainTask,
        'name': name,
        'screenshots': screenshots.map((s) => s.toJson()).toList(),
        if (redesignImagePath != null) 'redesignImagePath': redesignImagePath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (visualMetrics != null) 'visualMetrics': visualMetrics!.toJson(),
        if (ocrResult != null) 'ocrResult': ocrResult!.toJson(),
        'findings': findings.map((f) => f.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };

  factory EvaluationSession.fromJson(Map<String, dynamic> json) {
    // Legacy sessions may not have 'screenshots' — fall back to originalImagePath
    List<ScreenshotAnalysis> screenshots;
    if (json['screenshots'] != null) {
      screenshots = (json['screenshots'] as List<dynamic>)
          .map((s) =>
              ScreenshotAnalysis.fromJson(s as Map<String, dynamic>))
          .toList();
    } else {
      final path = json['originalImagePath'] as String? ?? '';
      screenshots = path.isNotEmpty
          ? [ScreenshotAnalysis(imagePath: path, index: 1)]
          : [];
    }

    return EvaluationSession(
      id: json['id'] as String,
      appName: json['appName'] as String? ?? '',
      mainTask: json['mainTask'] as String? ?? '',
      name: json['name'] as String,
      screenshots: screenshots,
      redesignImagePath: json['redesignImagePath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      visualMetrics: json['visualMetrics'] != null
          ? VisualMetrics.fromJson(
              json['visualMetrics'] as Map<String, dynamic>)
          : null,
      ocrResult: json['ocrResult'] != null
          ? OcrResult.fromJson(json['ocrResult'] as Map<String, dynamic>)
          : null,
      findings: (json['findings'] as List<dynamic>? ?? [])
          .map((f) => Finding.fromJson(f as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory EvaluationSession.fromJsonString(String s) =>
      EvaluationSession.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

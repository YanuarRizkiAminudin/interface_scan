import 'dart:convert';

/// The human verdict on a single AI-suggested finding.
enum FindingStatus { pending, accepted, rejected }

extension FindingStatusX on FindingStatus {
  String get label {
    switch (this) {
      case FindingStatus.pending:
        return 'Pending';
      case FindingStatus.accepted:
        return 'Accepted';
      case FindingStatus.rejected:
        return 'Rejected';
    }
  }
}

/// One heuristic finding, as suggested by AI and reviewed by the evaluator.
class Finding {
  final String id;

  /// Nielsen heuristic number (1–10).
  final int heuristicId;

  /// Short title of the issue.
  final String title;

  /// AI-generated explanation of the issue.
  final String reason;

  /// AI-generated recommendation / suggestion.
  final String recommendation;

  /// AI confidence score (0.0 – 1.0).
  final double confidence;

  /// Human-assigned severity (0 = cosmetic … 4 = catastrophic).
  int severity;

  /// Human verdict: pending / accepted / rejected.
  FindingStatus status;

  /// Optional note added by the evaluator when editing.
  String? evaluatorNote;

  Finding({
    required this.id,
    required this.heuristicId,
    required this.title,
    required this.reason,
    required this.recommendation,
    required this.confidence,
    this.severity = 2,
    this.status = FindingStatus.pending,
    this.evaluatorNote,
  });

  Finding copyWith({
    String? id,
    int? heuristicId,
    String? title,
    String? reason,
    String? recommendation,
    double? confidence,
    int? severity,
    FindingStatus? status,
    String? evaluatorNote,
  }) =>
      Finding(
        id: id ?? this.id,
        heuristicId: heuristicId ?? this.heuristicId,
        title: title ?? this.title,
        reason: reason ?? this.reason,
        recommendation: recommendation ?? this.recommendation,
        confidence: confidence ?? this.confidence,
        severity: severity ?? this.severity,
        status: status ?? this.status,
        evaluatorNote: evaluatorNote ?? this.evaluatorNote,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'heuristicId': heuristicId,
        'title': title,
        'reason': reason,
        'recommendation': recommendation,
        'confidence': confidence,
        'severity': severity,
        'status': status.name,
        if (evaluatorNote != null) 'evaluatorNote': evaluatorNote,
      };

  factory Finding.fromJson(Map<String, dynamic> json) => Finding(
        id: json['id'] as String,
        heuristicId: json['heuristicId'] as int,
        title: json['title'] as String,
        reason: json['reason'] as String,
        recommendation: json['recommendation'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        severity: json['severity'] as int,
        status: FindingStatus.values.byName(json['status'] as String),
        evaluatorNote: json['evaluatorNote'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());
  factory Finding.fromJsonString(String s) =>
      Finding.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

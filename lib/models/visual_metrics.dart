import 'dart:convert';

/// Results from the OpenCV-equivalent image processing analysis.
class VisualMetrics {
  /// Ratio of detected edge pixels to total pixels (0.0 – 1.0).
  final double edgeDensity;

  /// Estimated ratio of low-detail / empty-space area (0.0 – 1.0).
  final double lowDetailAreaRatio;

  /// Michelson contrast score (0.0 – 1.0). Higher = more contrast.
  final double contrastScore;

  /// Ratio of detected contour/region count relative to image area.
  final double contourDensity;

  /// Mean luminance of the image (0.0 – 255.0).
  final double meanLuminance;

  /// Image width in pixels.
  final int imageWidth;

  /// Image height in pixels.
  final int imageHeight;

  const VisualMetrics({
    required this.edgeDensity,
    required this.lowDetailAreaRatio,
    required this.contrastScore,
    required this.contourDensity,
    required this.meanLuminance,
    required this.imageWidth,
    required this.imageHeight,
  });

  /// A human-readable interpretation of the contrast score.
  String get contrastInterpretation {
    if (contrastScore >= 0.7) return 'High contrast';
    if (contrastScore >= 0.4) return 'Medium contrast';
    return 'Low contrast – may fail WCAG G18';
  }

  /// A human-readable interpretation of the edge density.
  String get edgeDensityInterpretation {
    if (edgeDensity >= 0.15) return 'High visual complexity';
    if (edgeDensity >= 0.06) return 'Moderate visual complexity';
    return 'Low visual complexity';
  }

  /// A human-readable interpretation of the low-detail area ratio.
  String get lowDetailInterpretation {
    if (lowDetailAreaRatio >= 0.5) return 'Large empty/padding areas';
    if (lowDetailAreaRatio >= 0.25) return 'Some empty areas';
    return 'Dense content layout';
  }

  Map<String, dynamic> toJson() => {
        'edgeDensity': edgeDensity,
        'lowDetailAreaRatio': lowDetailAreaRatio,
        'contrastScore': contrastScore,
        'contourDensity': contourDensity,
        'meanLuminance': meanLuminance,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
      };

  factory VisualMetrics.fromJson(Map<String, dynamic> json) => VisualMetrics(
        edgeDensity: (json['edgeDensity'] as num).toDouble(),
        lowDetailAreaRatio: (json['lowDetailAreaRatio'] as num).toDouble(),
        contrastScore: (json['contrastScore'] as num).toDouble(),
        contourDensity: (json['contourDensity'] as num).toDouble(),
        meanLuminance: (json['meanLuminance'] as num).toDouble(),
        imageWidth: json['imageWidth'] as int,
        imageHeight: json['imageHeight'] as int,
      );

  String toJsonString() => jsonEncode(toJson());
  factory VisualMetrics.fromJsonString(String s) =>
      VisualMetrics.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

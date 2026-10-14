import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/visual_metrics.dart';

// ── Isolate entry point (must be top-level) ───────────────────────────────────
// compute() requires a top-level or static function.
VisualMetrics _analyzeInIsolate(String imagePath) {
  final bytes = File(imagePath).readAsBytesSync();
  final original = img.decodeImage(bytes);
  if (original == null) {
    throw Exception('Could not decode image at $imagePath');
  }
  return _ImageAnalyzer.run(original);
}

/// Public service — callers use [analyze()].
/// CPU work runs in a background isolate via [compute()],
/// so the Flutter UI thread is never blocked.
class ImageAnalysisService {
  /// Analyse [imagePath] and return [VisualMetrics].
  /// Safe to await on the main thread.
  Future<VisualMetrics> analyze(String imagePath) =>
      compute(_analyzeInIsolate, imagePath);
}

// ── Internal analyser (used both in isolate and tests) ────────────────────────
class _ImageAnalyzer {
  static VisualMetrics run(img.Image original) {
    // Downscale for speed (max 640 px wide).
    final image = _downscale(original, maxWidth: 640);
    final w = image.width;
    final h = image.height;
    final totalPixels = w * h;

    final gray = _toGray(image);
    final meanLum = _meanLuminance(gray, totalPixels);
    final contrastScore = _michelsonContrast(gray);
    final edgeMap = _sobelEdge(gray, w, h);
    final edgeDensity = _edgeDensity(edgeMap, totalPixels);
    final lowDetailAreaRatio = _lowDetailRatio(gray, w, h);
    final contourDensity = _contourDensity(edgeMap, w, h, totalPixels);

    return VisualMetrics(
      edgeDensity: edgeDensity,
      lowDetailAreaRatio: lowDetailAreaRatio,
      contrastScore: contrastScore,
      contourDensity: contourDensity,
      meanLuminance: meanLum,
      imageWidth: original.width,
      imageHeight: original.height,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static img.Image _downscale(img.Image src, {required int maxWidth}) {
    if (src.width <= maxWidth) return src;
    final scale = maxWidth / src.width;
    return img.copyResize(
      src,
      width: maxWidth,
      height: (src.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }

  static Uint8List _toGray(img.Image image) {
    final w = image.width;
    final h = image.height;
    final out = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        final luma =
            (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
        out[y * w + x] = luma;
      }
    }
    return out;
  }

  static double _meanLuminance(Uint8List gray, int totalPixels) {
    int sum = 0;
    for (final v in gray) { sum += v; }
    return sum / totalPixels;
  }

  static double _michelsonContrast(Uint8List gray) {
    int minV = 255, maxV = 0;
    for (final v in gray) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final denom = maxV + minV;
    if (denom == 0) return 0.0;
    return (maxV - minV) / denom;
  }

  static List<double> _sobelEdge(Uint8List gray, int w, int h) {
    final edges = List<double>.filled(w * h, 0.0);
    const kx = [-1, 0, 1, -2, 0, 2, -1, 0, 1];
    const ky = [-1, -2, -1, 0, 0, 0, 1, 2, 1];
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        double gx = 0, gy = 0;
        for (int ky2 = -1; ky2 <= 1; ky2++) {
          for (int kx2 = -1; kx2 <= 1; kx2++) {
            final idx = (y + ky2) * w + (x + kx2);
            final ki = (ky2 + 1) * 3 + (kx2 + 1);
            final v = gray[idx].toDouble();
            gx += kx[ki] * v;
            gy += ky[ki] * v;
          }
        }
        edges[y * w + x] = math.sqrt(gx * gx + gy * gy);
      }
    }
    return edges;
  }

  static double _edgeDensity(List<double> edges, int totalPixels) {
    const threshold = 40.0;
    int edgePixels = 0;
    for (final v in edges) {
      if (v > threshold) edgePixels++;
    }
    return edgePixels / totalPixels;
  }

  static double _lowDetailRatio(Uint8List gray, int w, int h) {
    const blockSize = 16;
    const varianceThreshold = 80.0;
    int totalBlocks = 0, lowDetailBlocks = 0;

    for (int by = 0; by < h; by += blockSize) {
      for (int bx = 0; bx < w; bx += blockSize) {
        final values = <int>[];
        for (int dy = 0; dy < blockSize && by + dy < h; dy++) {
          for (int dx = 0; dx < blockSize && bx + dx < w; dx++) {
            values.add(gray[(by + dy) * w + (bx + dx)]);
          }
        }
        if (values.isEmpty) continue;
        final mean = values.reduce((a, b) => a + b) / values.length;
        final variance =
            values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
                values.length;
        totalBlocks++;
        if (variance < varianceThreshold) lowDetailBlocks++;
      }
    }
    return totalBlocks == 0 ? 0.0 : lowDetailBlocks / totalBlocks;
  }

  static double _contourDensity(
      List<double> edges, int w, int h, int totalPixels) {
    const threshold = 40.0;
    final visited = List<bool>.filled(w * h, false);
    int regionCount = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final idx = y * w + x;
        if (edges[idx] > threshold && !visited[idx]) {
          regionCount++;
          final stack = <int>[idx];
          visited[idx] = true;
          while (stack.isNotEmpty) {
            final cur = stack.removeLast();
            final cx = cur % w;
            final cy = cur ~/ w;
            for (int dy = -1; dy <= 1; dy++) {
              for (int dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) continue;
                final nx = cx + dx;
                final ny = cy + dy;
                if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
                final ni = ny * w + nx;
                if (!visited[ni] && edges[ni] > threshold) {
                  visited[ni] = true;
                  stack.add(ni);
                }
              }
            }
          }
        }
      }
    }
    return (regionCount * 10000.0) / totalPixels;
  }
}

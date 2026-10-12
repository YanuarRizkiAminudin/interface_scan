import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/visual_metrics.dart';

/// Pure-Dart image processing service.
/// Computes OpenCV-equivalent metrics: edge density, low-detail area ratio,
/// contrast score, contour density, and mean luminance.
class ImageAnalysisService {
  // ── public API ────────────────────────────────────────────────────────────

  /// Analyse the image at [imagePath] and return [VisualMetrics].
  /// Runs synchronously inside an isolate-friendly method so the caller can
  /// wrap it in `compute()` if desired.
  Future<VisualMetrics> analyze(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('Could not decode image at $imagePath');
    }

    // Work on a downscaled copy for speed (max 640 px wide).
    final image = _downscale(original, maxWidth: 640);

    final w = image.width;
    final h = image.height;
    final totalPixels = w * h;

    // 1. Convert to grayscale uint8 list
    final gray = _toGray(image);

    // 2. Mean luminance
    final meanLum = _meanLuminance(gray, totalPixels);

    // 3. Contrast score  (Michelson contrast: (max-min)/(max+min))
    final contrastScore = _michelsonContrast(gray);

    // 4. Sobel edge detection → edge density
    final edgeMap = _sobelEdge(gray, w, h);
    final edgeDensity = _edgeDensity(edgeMap, totalPixels);

    // 5. Low-detail / empty-space area ratio
    final lowDetailAreaRatio = _lowDetailRatio(gray, w, h);

    // 6. Contour / region density  (connected-component approximation)
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

  // ── private helpers ───────────────────────────────────────────────────────

  img.Image _downscale(img.Image src, {required int maxWidth}) {
    if (src.width <= maxWidth) return src;
    final scale = maxWidth / src.width;
    return img.copyResize(
      src,
      width: maxWidth,
      height: (src.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }

  /// Returns a flat Uint8List of grayscale luminance values (one per pixel).
  Uint8List _toGray(img.Image image) {
    final w = image.width;
    final h = image.height;
    final out = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        // Rec. 601 luma
        final luma =
            (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
        out[y * w + x] = luma;
      }
    }
    return out;
  }

  double _meanLuminance(Uint8List gray, int totalPixels) {
    int sum = 0;
    for (final v in gray) { sum += v; }
    return sum / totalPixels;
  }

  double _michelsonContrast(Uint8List gray) {
    int minV = 255, maxV = 0;
    for (final v in gray) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final denom = maxV + minV;
    if (denom == 0) return 0.0;
    return (maxV - minV) / denom;
  }

  /// 3×3 Sobel operator. Returns a flat float list (gradient magnitude per pixel).
  List<double> _sobelEdge(Uint8List gray, int w, int h) {
    final edges = List<double>.filled(w * h, 0.0);
    // Sobel kernels
    const kx = [-1, 0, 1, -2, 0, 2, -1, 0, 1];
    const ky = [-1, -2, -1, 0, 0, 0, 1, 2, 1];

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        double gx = 0, gy = 0;
        for (int ky2 = -1; ky2 <= 1; ky2++) {
          for (int kx2 = -1; kx2 <= 1; kx2++) {
            final idx = (y + ky2) * w + (x + kx2);
            final kernelIdx = (ky2 + 1) * 3 + (kx2 + 1);
            final v = gray[idx].toDouble();
            gx += kx[kernelIdx] * v;
            gy += ky[kernelIdx] * v;
          }
        }
        edges[y * w + x] = math.sqrt(gx * gx + gy * gy);
      }
    }
    return edges;
  }

  double _edgeDensity(List<double> edges, int totalPixels) {
    // Threshold: gradient > 40 counts as edge pixel
    const threshold = 40.0;
    int edgePixels = 0;
    for (final v in edges) {
      if (v > threshold) edgePixels++;
    }
    return edgePixels / totalPixels;
  }

  /// Estimates the proportion of the image that is "empty" or low-detail.
  /// Uses block-level variance: blocks with variance < threshold are "empty".
  double _lowDetailRatio(Uint8List gray, int w, int h) {
    const blockSize = 16;
    const varianceThreshold = 80.0; // low variance = uniform/empty region

    int totalBlocks = 0;
    int lowDetailBlocks = 0;

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

  /// Approximates contour density by counting connected edge-pixel regions
  /// using a fast union-find pass on thresholded edge map.
  double _contourDensity(
      List<double> edges, int w, int h, int totalPixels) {
    const threshold = 40.0;
    final visited = List<bool>.filled(w * h, false);
    int regionCount = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final idx = y * w + x;
        if (edges[idx] > threshold && !visited[idx]) {
          // BFS flood-fill to mark the region
          regionCount++;
          final queue = <int>[idx];
          visited[idx] = true;
          while (queue.isNotEmpty) {
            final cur = queue.removeLast();
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
                  queue.add(ni);
                }
              }
            }
          }
        }
      }
    }

    // Normalise: regions per 10 000 pixels
    return (regionCount * 10000.0) / totalPixels;
  }
}

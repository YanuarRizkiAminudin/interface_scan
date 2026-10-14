
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/evaluation_session.dart';
import '../../models/finding.dart';
import '../../models/ocr_result.dart';
import '../../models/screenshot_analysis.dart';
import '../../models/visual_metrics.dart';
import '../../services/ai_service.dart';
import '../../services/image_analysis_service.dart';
import '../../services/ocr_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/safe_file_image.dart';
import '../findings/findings_review_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AnalysisScreen – Step 1 of the evaluation flow
// ─────────────────────────────────────────────────────────────────────────────

class AnalysisScreen extends StatefulWidget {
  final String apiKey;
  final EvaluationSession? existingSession;

  const AnalysisScreen({
    super.key,
    required this.apiKey,
    this.existingSession,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

enum _PipelineStep { idle, imageAnalysis, ocr, ai, done }

class _AnalysisScreenState extends State<AnalysisScreen> {
  static const int _maxScreenshots = 5;
  static const int _minScreenshots = 3;

  final _picker = ImagePicker();
  final _imageService = ImageAnalysisService();
  final _ocrService = OcrService();
  final _storage = StorageService();
  final _uuid = const Uuid();

  late EvaluationSession _session;
  _PipelineStep _step = _PipelineStep.idle;
  String? _errorMessage;
  int _currentScreenshotIndex = 0;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _appNameCtrl;
  late final TextEditingController _mainTaskCtrl;

  // ── Init / dispose ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.existingSession != null) {
      _session = widget.existingSession!;
      _step = _session.allAnalyzed ? _PipelineStep.done : _PipelineStep.idle;
    } else {
      _session = EvaluationSession(
        id: _uuid.v4(),
        name: _defaultName(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    _nameCtrl = TextEditingController(text: _session.name);
    _appNameCtrl = TextEditingController(text: _session.appName);
    _mainTaskCtrl = TextEditingController(text: _session.mainTask);

    // Rebuild Analyze button whenever app name field changes.
    _appNameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _appNameCtrl.dispose();
    _mainTaskCtrl.dispose();
    _ocrService.close();
    super.dispose();
  }

  // ── Computed helpers ──────────────────────────────────────────────────────

  /// "Evaluation 12 Oct 2026"
  static String _defaultName() {
    final now = DateTime.now();
    return 'Evaluation ${now.day} ${DateFormat('MMM').format(now)} ${now.year}';
  }

  bool get _isAnalysing =>
      _step != _PipelineStep.idle && _step != _PipelineStep.done;

  bool get _canAddMore =>
      _session.screenshotCount < _maxScreenshots && !_isAnalysing;

  /// Analyze button active when ≥3 screenshots AND App/Website Name filled.
  bool get _canAnalyze =>
      !_isAnalysing &&
      _session.screenshotCount >= _minScreenshots &&
      _appNameCtrl.text.trim().isNotEmpty;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _addScreenshots() async {
    if (!_canAddMore) {
      if (_session.screenshotCount >= _maxScreenshots) {
        _showSnack(AppStrings.maxScreenshotsReached);
      }
      return;
    }
    final remaining = _maxScreenshots - _session.screenshotCount;
    final picked = await _picker.pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;

    setState(() {
      for (final xFile in picked) {
        final idx = _session.screenshotCount + 1;
        _session.screenshots
            .add(ScreenshotAnalysis(imagePath: xFile.path, index: idx));
      }
      _resetAnalysisState();
    });

    // Persist immediately so the session appears in Home history right away.
    _syncContext();
    await _storage.saveSession(_session);
  }

  void _removeScreenshot(int index) {
    if (_isAnalysing) return;
    setState(() {
      _session.screenshots.removeAt(index);
      // Re-number remaining entries.
      for (var i = 0; i < _session.screenshots.length; i++) {
        final s = _session.screenshots[i];
        final autoLabel = 'Screen ${s.index}';
        _session.screenshots[i] = ScreenshotAnalysis(
          imagePath: s.imagePath,
          index: i + 1,
          label: s.label == autoLabel ? 'Screen ${i + 1}' : s.label,
          visualMetrics: s.visualMetrics,
          ocrResult: s.ocrResult,
        );
      }
      _resetAnalysisState();
    });
  }

  Future<void> _renameScreenshot(int index) async {
    final s = _session.screenshots[index];
    final ctrl = TextEditingController(text: s.label);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.renameScreenshot),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: AppStrings.screenshotLabel,
            hintText: AppStrings.screenshotLabelHint,
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() {
        _session.screenshots[index] = ScreenshotAnalysis(
          imagePath: s.imagePath,
          index: s.index,
          label: result,
          visualMetrics: s.visualMetrics,
          ocrResult: s.ocrResult,
        );
      });
    }
  }

  /// Clears analysis results when screenshots change.
  void _resetAnalysisState() {
    _step = _PipelineStep.idle;
    _errorMessage = null;
    _session.visualMetrics = null;
    _session.ocrResult = null;
    _session.findings.clear();
    for (var i = 0; i < _session.screenshots.length; i++) {
      final s = _session.screenshots[i];
      _session.screenshots[i] =
          ScreenshotAnalysis(imagePath: s.imagePath, index: s.index, label: s.label);
    }
  }

  Future<void> _runAnalysis() async {
    if (!_canAnalyze) return;
    _syncContext();
    setState(() {
      _step = _PipelineStep.imageAnalysis;
      _errorMessage = null;
      _currentScreenshotIndex = 0;
    });

    try {
      final allMetrics = <VisualMetrics>[];
      final allOcr = <OcrResult>[];
      final allFindings = <Finding>[];

      for (var i = 0; i < _session.screenshots.length; i++) {
        if (!mounted) return;
        setState(() {
          _currentScreenshotIndex = i;
          _step = _PipelineStep.imageAnalysis;
        });

        final path = _session.screenshots[i].imagePath;

        // Analyse — skip this screenshot if decode fails (bad/corrupt file)
        VisualMetrics metrics;
        try {
          metrics = await _imageService.analyze(path);
        } catch (e) {
          // Log a warning and continue with remaining screenshots
          setState(() => _errorMessage =
              'Screen ${i + 1}: could not analyse image. Skipping. ($e)');
          continue;
        }
        allMetrics.add(metrics);

        setState(() => _step = _PipelineStep.ocr);
        OcrResult ocr;
        try {
          ocr = await _ocrService.recognize(path);
        } catch (_) {
          ocr = OcrResult(fullText: '', blocks: [], blockCount: 0);
        }
        allOcr.add(ocr);

        setState(() {
          _session.screenshots[i] = ScreenshotAnalysis(
            imagePath: path,
            index: _session.screenshots[i].index,
            label: _session.screenshots[i].label,
            visualMetrics: metrics,
            ocrResult: ocr,
          );
        });

        // Run AI per-screenshot so screenshotIndex is set correctly
        if (widget.apiKey.isNotEmpty) {
          try {
            final aiService = AiService(apiKey: widget.apiKey);
            final perScreenFindings = await aiService.getSuggestions(
              metrics: metrics,
              ocrResult: ocr,
              screenshotIndex: _session.screenshots[i].index,
            );
            allFindings.addAll(perScreenFindings);
          } on AiException catch (e) {
            setState(() => _errorMessage =
                'AI (screen ${i + 1}): ${e.userMessage}');
          }
        }
      }

      if (allMetrics.isEmpty) {
        throw Exception(
            'All screenshots failed to analyse. Check the image files.');
      }

      final aggMetrics = _aggregateMetrics(allMetrics);
      final aggOcr = _aggregateOcr(allOcr);
      setState(() {
        _session.visualMetrics = aggMetrics;
        _session.ocrResult = aggOcr;
        _session.findings = allFindings;
        _step = _PipelineStep.done;
      });
      await _storage.saveSession(_session);
    } on AiException catch (e) {
      setState(() {
        _errorMessage = e.userMessage;
        _step = _PipelineStep.idle;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _step = _PipelineStep.idle;
      });
    }
  }

  Future<void> _goToReview() async {
    _syncContext();
    await _storage.saveSession(_session);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FindingsReviewScreen(session: _session)),
    );
    setState(() {});
  }

  /// Writes controller values back to the session model.
  void _syncContext() {
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) _session.name = name;
    _session.appName = _appNameCtrl.text.trim();
    _session.mainTask = _mainTaskCtrl.text.trim();
  }

  /// Called when the user navigates back — saves even partial progress.
  Future<bool> _onWillPop() async {
    if (_session.hasScreenshots || _session.appName.isNotEmpty) {
      _syncContext();
      await _storage.saveSession(_session);
    }
    return true;
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Aggregation helpers ───────────────────────────────────────────────────

  VisualMetrics _aggregateMetrics(List<VisualMetrics> list) {
    double ed = 0, ld = 0, cs = 0, cd = 0, lum = 0;
    int w = 0, h = 0;
    for (final m in list) {
      ed += m.edgeDensity;
      ld += m.lowDetailAreaRatio;
      cs += m.contrastScore;
      cd += m.contourDensity;
      lum += m.meanLuminance;
      // Keep the largest dimensions as representative size.
      if (m.imageWidth > w) w = m.imageWidth;
      if (m.imageHeight > h) h = m.imageHeight;
    }
    final n = list.length;
    return VisualMetrics(
      edgeDensity: ed / n,
      lowDetailAreaRatio: ld / n,
      contrastScore: cs / n,
      contourDensity: cd / n,
      meanLuminance: lum / n,
      imageWidth: w,
      imageHeight: h,
    );
  }

  OcrResult _aggregateOcr(List<OcrResult> list) {
    final blocks = list.expand((r) => r.blocks).toList();
    return OcrResult(
      fullText: list.map((r) => r.fullText).join('\n\n---\n\n'),
      blocks: blocks,
      blockCount: blocks.length,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final count = _session.screenshotCount;

    return PopScope(
      // Save on back-press / gesture.
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _onWillPop();
      },
      child: Scaffold(
        // Let the scaffold shift up when the keyboard opens.
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text(AppStrings.analyzeScreenshots)),
        body: ListView(
          // Dismiss keyboard on scroll so the user can see thumbnails.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          // Extra bottom padding so content clears the FAB + keyboard.
          padding: const EdgeInsets.only(bottom: 160),
          children: [
            // ── 1. Context (Discover phase) ───────────────────────────
            const _SectionHeader(label: AppStrings.contextSection),
            _ContextFields(
              nameCtrl: _nameCtrl,
              appNameCtrl: _appNameCtrl,
              mainTaskCtrl: _mainTaskCtrl,
              enabled: !_isAnalysing,
            ),

            // ── 2. Screenshots ────────────────────────────────────────
            _SectionHeader(
              label:
                  '${AppStrings.screenshotsSection} · $count/$_maxScreenshots',
            ),
            _ScreenshotGrid(
              screenshots: _session.screenshots,
              canAdd: _canAddMore,
              onAdd: _addScreenshots,
              onRemove: _removeScreenshot,
              onRename: _renameScreenshot,
            ),

            // Single, compact flow tip — no duplicate hint banners.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                AppStrings.screenshotCountHint,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),

            // ── 3. Analyze button / progress ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _isAnalysing
                  ? _ProgressPanel(
                      step: _step,
                      current: _currentScreenshotIndex + 1,
                      total: count,
                    )
                  : _AnalyzeButton(
                      enabled: _canAnalyze,
                      isDone: _step == _PipelineStep.done,
                      onPressed: _runAnalysis,
                      screenshotCount: count,
                      appNameFilled: _appNameCtrl.text.trim().isNotEmpty,
                    ),
            ),

            // ── Error ─────────────────────────────────────────────────
            if (_errorMessage != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _ErrorBanner(message: _errorMessage!),
              ),

            // ── Results: visual metrics ───────────────────────────────
            if (_session.visualMetrics != null) ...[
              _SectionHeader(
                label: count > 1
                    ? '${AppStrings.visualMetrics} (${AppStrings.avgOf} $count ${AppStrings.screens})'
                    : AppStrings.visualMetrics,
              ),
              _VisualMetricsPanel(metrics: _session.visualMetrics!),
            ],

            // ── Results: per-screen accordion ─────────────────────────
            if (_session.allAnalyzed && count > 1) ...[
              const _SectionHeader(label: AppStrings.perScreenDetail),
              ..._session.screenshots
                  .map((s) => _ScreenshotDetailTile(screenshot: s)),
            ],

            // ── Results: OCR ──────────────────────────────────────────
            if (_session.ocrResult != null) ...[
              const _SectionHeader(label: AppStrings.ocrResults),
              _OcrPanel(result: _session.ocrResult!),
            ],

            // ── Results: AI suggestions preview ───────────────────────
            if (_session.findings.isNotEmpty) ...[
              _SectionHeader(
                label:
                    '${AppStrings.aiSuggestions} (${_session.findings.length})',
              ),
              _FindingsPreviewPanel(findings: _session.findings),
            ],

            // ── No API key warning ────────────────────────────────────
            if (widget.apiKey.isEmpty && _step == _PipelineStep.done)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _HintBanner(message: AppStrings.apiKeyMissing),
              ),
          ],
        ),

        // ── FAB: Review Findings (only after analysis complete) ───────────
        floatingActionButton: _step == _PipelineStep.done
            ? FloatingActionButton.extended(
                onPressed: _goToReview,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text(AppStrings.proceedToReview),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Context fields ────────────────────────────────────────────────────────────
//
// All three fields share identical styling: white fill, outlined border,
// floating label. The multi-line field ("Main User Task") uses a Stack to
// overlay a top-pinned icon because Flutter's built-in prefixIcon always
// centers vertically, which looks wrong on multi-line inputs.

class _ContextFields extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController appNameCtrl;
  final TextEditingController mainTaskCtrl;
  final bool enabled;

  const _ContextFields({
    required this.nameCtrl,
    required this.appNameCtrl,
    required this.mainTaskCtrl,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _FieldRow(
            controller: nameCtrl,
            enabled: enabled,
            label: AppStrings.evaluationName,
            icon: Icons.label_outline,
          ),
          const SizedBox(height: 12),
          _FieldRow(
            controller: appNameCtrl,
            enabled: enabled,
            label: AppStrings.appOrWebsite,
            hint: AppStrings.appOrWebsiteHint,
            icon: Icons.apps_outlined,
          ),
          const SizedBox(height: 12),
          _FieldRow(
            controller: mainTaskCtrl,
            enabled: enabled,
            label: AppStrings.mainTask,
            hint: AppStrings.mainTaskHint,
            icon: Icons.task_alt_outlined,
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}

/// One context field.
///
/// For single-line fields the icon is provided via [InputDecoration.prefixIcon]
/// (Flutter centers it vertically, which is correct for single-line).
/// For multi-line fields ([minLines] > 1) we use a [Stack] to pin the icon
/// to the top-left corner so it aligns with the first line of text.
class _FieldRow extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String? hint;
  final IconData icon;
  final int minLines;
  final int maxLines;

  const _FieldRow({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.icon,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
  });

  bool get _isMultiline => minLines > 1;

  /// Base [InputDecoration] shared by both single- and multi-line variants.
  InputDecoration _baseDec() => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        // Align the floating label with the hint for multi-line inputs.
        alignLabelWithHint: _isMultiline,
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8))),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_isMultiline) {
      // Single-line: use prefixIcon (Flutter centers it correctly here).
      return TextField(
        controller: controller,
        enabled: enabled,
        maxLines: 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: _baseDec().copyWith(
          prefixIcon: Icon(icon),
        ),
      );
    }

    // Multi-line: Stack the icon on top of the TextField so it pins to
    // the top-left and does not move when the text field grows.
    return Stack(
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: _baseDec().copyWith(
            // Reserve space for the manually-positioned icon.
            contentPadding: const EdgeInsets.fromLTRB(48, 16, 16, 16),
          ),
        ),
        // Icon pinned to the top-left, matching the 16 px top padding of the
        // TextField content so it visually sits beside the first text line.
        Positioned(
          left: 12,
          top: 16,
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? AppTheme.textSecondary
                : AppTheme.textSecondary.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

// ── Screenshot grid ───────────────────────────────────────────────────────────

class _ScreenshotGrid extends StatelessWidget {
  final List<ScreenshotAnalysis> screenshots;
  final bool canAdd;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final void Function(int) onRename;

  const _ScreenshotGrid({
    required this.screenshots,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = screenshots.length + (canAdd ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: screenshots.isEmpty && !canAdd
          ? _EmptyGrid(onTap: onAdd)
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: itemCount,
              itemBuilder: (ctx, i) {
                if (i < screenshots.length) {
                  return _ScreenshotThumbnail(
                    screenshot: screenshots[i],
                    onRemove: () => onRemove(i),
                    onRename: () => onRename(i),
                  );
                }
                return _AddTile(onTap: onAdd);
              },
            ),
    );
  }
}

class _EmptyGrid extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyGrid({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Center(
          child: Text(
            AppStrings.noScreenshotsYet,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenshotThumbnail extends StatelessWidget {
  final ScreenshotAnalysis screenshot;
  final VoidCallback onRemove;
  final VoidCallback onRename;

  const _ScreenshotThumbnail({
    required this.screenshot,
    required this.onRemove,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onRename, // long-press to rename
      child: Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail image
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SafeFileImage(
            path: screenshot.imagePath,
            fit: BoxFit.cover,
            fallback: Container(
              color: AppTheme.surface,
              child: const Icon(Icons.broken_image_outlined,
                  color: AppTheme.textSecondary),
            ),
          ),
        ),

        // Analysed tick (shown once metrics + OCR are done)
        if (screenshot.isAnalyzed)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: AppTheme.secondary, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 11, color: Colors.white),
            ),
          ),

        // Screen label gradient at the bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
            child: Text(
              screenshot.label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Remove × button (top-right)
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    ),   // Stack
    );   // GestureDetector
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 28, color: AppTheme.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 6),
            Text(
              AppStrings.addScreenshot,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Analyze button with inline requirements list ───────────────────────────────

class _AnalyzeButton extends StatelessWidget {
  final bool enabled;
  final bool isDone;
  final VoidCallback onPressed;
  final int screenshotCount;
  final bool appNameFilled;

  const _AnalyzeButton({
    required this.enabled,
    required this.isDone,
    required this.onPressed,
    required this.screenshotCount,
    required this.appNameFilled,
  });

  @override
  Widget build(BuildContext context) {
    final label = isDone ? AppStrings.reAnalyze : AppStrings.analyze;

    // Build the missing-requirements list only when the button is disabled.
    final missing = <String>[];
    if (screenshotCount < 3) {
      final need = 3 - screenshotCount;
      missing.add('$need more screenshot${need == 1 ? '' : 's'} needed');
    }
    if (!appNameFilled) missing.add('App / Website Name is required');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            disabledBackgroundColor: AppTheme.divider,
            disabledForegroundColor: AppTheme.textSecondary,
          ),
        ),
        if (!enabled && missing.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...missing.map(
            (msg) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.radio_button_unchecked,
                      size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(msg,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Progress panel ────────────────────────────────────────────────────────────

class _ProgressPanel extends StatelessWidget {
  final _PipelineStep step;
  final int current;
  final int total;

  const _ProgressPanel({
    required this.step,
    required this.current,
    required this.total,
  });

  String get _label {
    switch (step) {
      case _PipelineStep.imageAnalysis:
        return AppStrings.runningImageAnalysis;
      case _PipelineStep.ocr:
        return AppStrings.runningOcr;
      case _PipelineStep.ai:
        return AppStrings.generatingAiSuggestions;
      default:
        return AppStrings.analysisInProgress;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showProgress =
        step == _PipelineStep.imageAnalysis || step == _PipelineStep.ocr;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary)),
              ),
            ],
          ),
          if (showProgress && total > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${AppStrings.screenOf} $current ${AppStrings.of} $total',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: current / total,
                      minHeight: 5,
                      backgroundColor: AppTheme.divider,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Visual metrics panel ──────────────────────────────────────────────────────

class _VisualMetricsPanel extends StatelessWidget {
  final VisualMetrics metrics;
  const _VisualMetricsPanel({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          MetricCard(
            label: AppStrings.metricEdgeDensity,
            value: metrics.edgeDensity.toStringAsFixed(4),
            barValue: (metrics.edgeDensity / 0.25).clamp(0.0, 1.0),
            barColor: _edgeColor(metrics.edgeDensity),
            interpretation: metrics.edgeDensityInterpretation,
            icon: Icons.grain,
          ),
          MetricCard(
            label: AppStrings.metricContrastScore,
            value: metrics.contrastScore.toStringAsFixed(4),
            barValue: metrics.contrastScore,
            barColor: _contrastColor(metrics.contrastScore),
            interpretation: metrics.contrastInterpretation,
            icon: Icons.contrast,
          ),
          MetricCard(
            label: AppStrings.metricLowDetailArea,
            value:
                '${(metrics.lowDetailAreaRatio * 100).toStringAsFixed(1)}%',
            barValue: metrics.lowDetailAreaRatio,
            barColor: AppTheme.warning,
            interpretation: metrics.lowDetailInterpretation,
            icon: Icons.crop_free,
          ),
          MetricCard(
            label: AppStrings.metricContourDensity,
            value: metrics.contourDensity.toStringAsFixed(2),
            barValue: (metrics.contourDensity / 20).clamp(0.0, 1.0),
            barColor: AppTheme.primary,
            interpretation: AppStrings.metricRegionsPer10k,
            icon: Icons.account_tree_outlined,
          ),
          MetricCard(
            label: AppStrings.metricMeanLuminance,
            value: metrics.meanLuminance.toStringAsFixed(1),
            barValue: metrics.meanLuminance / 255,
            barColor: AppTheme.textSecondary,
            interpretation:
                '${metrics.imageWidth} × ${metrics.imageHeight} px',
            icon: Icons.light_mode_outlined,
          ),
        ],
      ),
    );
  }

  Color _edgeColor(double v) {
    if (v >= 0.15) return AppTheme.error;
    if (v >= 0.06) return AppTheme.warning;
    return AppTheme.secondary;
  }

  Color _contrastColor(double v) {
    if (v >= 0.7) return AppTheme.secondary;
    if (v >= 0.4) return AppTheme.warning;
    return AppTheme.error;
  }
}

// ── Per-screenshot collapsible detail tile ────────────────────────────────────

class _ScreenshotDetailTile extends StatefulWidget {
  final ScreenshotAnalysis screenshot;
  const _ScreenshotDetailTile({required this.screenshot});

  @override
  State<_ScreenshotDetailTile> createState() => _ScreenshotDetailTileState();
}

class _ScreenshotDetailTileState extends State<_ScreenshotDetailTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.screenshot.visualMetrics;
    final o = widget.screenshot.ocrResult;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 40,
              height: 40,
              child: SafeFileImage(
                path: widget.screenshot.imagePath,
                fit: BoxFit.cover,
                width: 40,
                height: 40,
                fallback: Container(
                  color: AppTheme.surface,
                  child: const Icon(Icons.image_outlined, size: 20),
                ),
              ),
            ),
          ),
          title: Text(widget.screenshot.label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: m != null
              ? Text(
                  'Contrast: ${m.contrastScore.toStringAsFixed(3)} · '
                  'Edge: ${m.edgeDensity.toStringAsFixed(3)} · '
                  'OCR: ${o?.blockCount ?? 0} blocks',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                )
              : null,
          trailing: Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            color: AppTheme.textSecondary,
          ),
          onExpansionChanged: (v) => setState(() => _expanded = v),
          children: [
            if (m != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    _Row(AppStrings.metricEdgeDensity, m.edgeDensity.toStringAsFixed(4)),
                    _Row(AppStrings.metricContrastScore, m.contrastScore.toStringAsFixed(4)),
                    _Row(AppStrings.metricLowDetailArea,
                        '${(m.lowDetailAreaRatio * 100).toStringAsFixed(1)}%'),
                    _Row(AppStrings.metricContourDensity, m.contourDensity.toStringAsFixed(2)),
                    _Row(AppStrings.metricMeanLuminance, m.meanLuminance.toStringAsFixed(1)),
                  ],
                ),
              ),
            if (o != null && o.fullText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(AppStrings.ocrSectionLabel,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      o.fullText.length > 300
                          ? '${o.fullText.substring(0, 300)}…'
                          : o.fullText,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

// ── OCR panel ─────────────────────────────────────────────────────────────────

class _OcrPanel extends StatelessWidget {
  final OcrResult result;
  const _OcrPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.text_fields,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${result.blockCount} text block'
                    '${result.blockCount == 1 ? '' : 's'} detected',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (result.fullText.isNotEmpty) ...[
                const Divider(height: 16),
                Text(
                  result.fullText.length > 500
                      ? '${result.fullText.substring(0, 500)}…'
                      : result.fullText,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.5),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('No text detected.',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Findings preview ──────────────────────────────────────────────────────────

class _FindingsPreviewPanel extends StatelessWidget {
  final List<Finding> findings;
  const _FindingsPreviewPanel({required this.findings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tap "${AppStrings.proceedToReview}" to accept, edit, or reject each finding.',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              ...findings.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text('H${f.heuristicId}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(f.title,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textPrimary)),
                      ),
                      Text('${(f.confidence * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Banners ───────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 13, color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  final String message;
  const _HintBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

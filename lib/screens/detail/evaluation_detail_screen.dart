import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/heuristics.dart';
import '../../core/theme/app_theme.dart';
import '../../models/evaluation_session.dart';
import '../../models/finding.dart';
import '../../services/storage_service.dart';
import '../../widgets/safe_file_image.dart';
import '../../widgets/severity_badge.dart';
import '../analysis/analysis_screen.dart';
import '../comparison/comparison_screen.dart';
import '../findings/findings_review_screen.dart';

/// Read-only summary of a completed evaluation.
class EvaluationDetailScreen extends StatefulWidget {
  final EvaluationSession session;
  const EvaluationDetailScreen({super.key, required this.session});

  @override
  State<EvaluationDetailScreen> createState() =>
      _EvaluationDetailScreenState();
}

class _EvaluationDetailScreenState extends State<EvaluationDetailScreen> {
  final _storage = StorageService();
  late EvaluationSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  Future<void> _reload() async {
    final fresh = await _storage.loadSession(_session.id);
    if (fresh != null && mounted) setState(() => _session = fresh);
  }

  Future<void> _openAnalysis(BuildContext ctx) async {
    final apiKey = await _storage.getApiKey();
    if (!ctx.mounted) return;
    await Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AnalysisScreen(apiKey: apiKey, existingSession: _session),
    ));
    _reload();
  }

  Future<void> _openReview(BuildContext ctx) async {
    await Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => FindingsReviewScreen(session: _session),
    ));
    _reload();
  }

  Future<void> _openComparison(BuildContext ctx) async {
    await Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => ComparisonScreen(session: _session),
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, HH:mm');
    final acceptedList = _session.acceptedFindings;
    final pendingList = _session.findings
        .where((f) => f.status == FindingStatus.pending)
        .toList();
    final pendingCount = _session.pendingCount;
    final rejectedCount = _session.rejectedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.evaluationDetail),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: AppStrings.continueAnalysis,
            onPressed: () => _openAnalysis(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ── Header ──────────────────────────────────────────────────
          _HeaderCard(session: _session, fmt: fmt),

          // ── Quick actions ────────────────────────────────────────────
          _ActionRow(
            hasFindings:
                _session.totalFindings > 0 || _session.allAnalyzed,
            onReview: () => _openReview(context),
            onCompare: () => _openComparison(context),
            onAnalyze: () => _openAnalysis(context),
          ),

          // ── Screenshots strip ────────────────────────────────────────
          const _SectionHeader(label: AppStrings.screenshotsLabel),
          _ScreenshotStrip(session: _session),

          // ── Visual metrics ───────────────────────────────────────────
          const _SectionHeader(label: AppStrings.metricsSummary),
          if (_session.visualMetrics != null)
            _MetricsCard(session: _session)
          else
            const _NotAnalyzedBanner(),

          // ── Findings summary counts ──────────────────────────────────
          _SectionHeader(
            label:
                '${AppStrings.findingsSummary} (${_session.totalFindings})',
          ),
          _FindingsSummaryCard(
            acceptedCount: acceptedList.length,
            pendingCount: pendingCount,
            rejectedCount: rejectedCount,
            totalFindings: _session.totalFindings,
          ),

          // ── Accepted findings ────────────────────────────────────────
          if (acceptedList.isNotEmpty) ...[
            _SectionHeader(
              label:
                  '${AppStrings.acceptedFindingsHeader} (${acceptedList.length})',
            ),
            ...acceptedList.map((f) => _FindingTile(finding: f)),
          ],

          // ── Pending findings ─────────────────────────────────────────
          if (pendingList.isNotEmpty) ...[
            _SectionHeader(
              label:
                  '${AppStrings.pendingFindingsHeader} (${pendingList.length})',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'These findings are awaiting your review.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.warning.withValues(alpha: 0.9)),
              ),
            ),
            ...pendingList.map((f) => _FindingTile(finding: f)),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

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

class _HeaderCard extends StatelessWidget {
  final EvaluationSession session;
  final DateFormat fmt;
  const _HeaderCard({required this.session, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.name,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            if (session.appName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.apps_outlined,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(session.appName,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
            if (session.mainTask.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.task_alt_outlined,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(session.mainTask,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ),
              ]),
            ],
            const Divider(height: 20),
            Row(children: [
              const Icon(Icons.schedule,
                  size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${AppStrings.updated} ${fmt.format(session.updatedAt)}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool hasFindings;
  final VoidCallback onReview;
  final VoidCallback onCompare;
  final VoidCallback onAnalyze;

  const _ActionRow({
    required this.hasFindings,
    required this.onReview,
    required this.onCompare,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (hasFindings) ...[
            _ActionButton(
              icon: Icons.rate_review_outlined,
              label: AppStrings.reviewFindings,
              color: AppTheme.primary,
              onTap: onReview,
            ),
            _ActionButton(
              icon: Icons.compare_arrows_outlined,
              label: AppStrings.comparison,
              color: AppTheme.secondary,
              onTap: onCompare,
            ),
          ],
          _ActionButton(
            icon: Icons.play_arrow_rounded,
            label: AppStrings.continueAnalysis,
            color: AppTheme.textSecondary,
            onTap: onAnalyze,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

class _ScreenshotStrip extends StatelessWidget {
  final EvaluationSession session;
  const _ScreenshotStrip({required this.session});

  @override
  Widget build(BuildContext context) {
    if (!session.hasScreenshots) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(AppStrings.noScreenshotsRecorded,
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: session.screenshots.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final s = session.screenshots[i];
          return Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SafeFileImage(
                  path: s.imagePath, width: 72, height: 96, fit: BoxFit.cover),
            ),
            const SizedBox(height: 2),
            Text(s.label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ]);
        },
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final EvaluationSession session;
  const _MetricsCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final m = session.visualMetrics!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          _MRow(AppStrings.metricEdgeDensity,
              m.edgeDensity.toStringAsFixed(4), m.edgeDensityInterpretation),
          _MRow(AppStrings.metricContrastScore,
              m.contrastScore.toStringAsFixed(4), m.contrastInterpretation),
          _MRow(AppStrings.metricLowDetailArea,
              '${(m.lowDetailAreaRatio * 100).toStringAsFixed(1)}%',
              m.lowDetailInterpretation),
          _MRow(AppStrings.metricMeanLuminance,
              m.meanLuminance.toStringAsFixed(1), ''),
        ]),
      ),
    );
  }
}

class _MRow extends StatelessWidget {
  final String label;
  final String value;
  final String interpretation;
  const _MRow(this.label, this.value, this.interpretation);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
        if (interpretation.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(interpretation,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
                textAlign: TextAlign.right),
          ),
        ],
      ]),
    );
  }
}

class _NotAnalyzedBanner extends StatelessWidget {
  const _NotAnalyzedBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(AppStrings.notAnalyzedYet,
                style:
                    TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ]),
      ),
    );
  }
}

class _FindingsSummaryCard extends StatelessWidget {
  final int acceptedCount, pendingCount, rejectedCount, totalFindings;
  const _FindingsSummaryCard({
    required this.acceptedCount,
    required this.pendingCount,
    required this.rejectedCount,
    required this.totalFindings,
  });

  @override
  Widget build(BuildContext context) {
    if (totalFindings == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(AppStrings.noFindingsRecorded,
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatBox(
                value: acceptedCount,
                label: AppStrings.accepted,
                color: AppTheme.secondary),
            _StatBox(
                value: pendingCount,
                label: AppStrings.pending,
                color: AppTheme.warning),
            _StatBox(
                value: rejectedCount,
                label: AppStrings.rejected,
                color: AppTheme.error),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _StatBox(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value.toString(),
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, color: color)),
      Text(label,
          style: const TextStyle(
              fontSize: 12, color: AppTheme.textSecondary)),
    ]);
  }
}

class _FindingTile extends StatelessWidget {
  final Finding finding;
  const _FindingTile({required this.finding});

  @override
  Widget build(BuildContext context) {
    final h = heuristicById(finding.heuristicId);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('H${finding.heuristicId}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(finding.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
              SeverityBadge(severity: finding.severity, small: true),
            ]),
            const SizedBox(height: 4),
            Text(h.shortName,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic)),
            if (finding.recommendation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 14, color: AppTheme.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(finding.recommendation,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary))),
                    ]),
              ),
            ],
            if (finding.evaluatorNote != null &&
                finding.evaluatorNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.person_outline,
                    size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(finding.evaluatorNote!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic)),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

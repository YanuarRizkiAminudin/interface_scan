
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/heuristics.dart';
import '../../core/theme/app_theme.dart';
import '../../models/evaluation_session.dart';
import '../../models/finding.dart';
import '../../models/screenshot_analysis.dart';
import '../../services/storage_service.dart';
import '../../widgets/safe_file_image.dart';
import '../../widgets/severity_badge.dart';

/// Step 3 (optional): Add redesign screenshot and compare with the original.
class ComparisonScreen extends StatefulWidget {
  final EvaluationSession session;
  const ComparisonScreen({super.key, required this.session});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  final _storage = StorageService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickRedesign() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => widget.session.redesignImagePath = picked.path);
    await _storage.saveSession(widget.session);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.comparison),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.compare_arrows), text: 'Side by Side'),
            Tab(icon: Icon(Icons.list_alt_outlined), text: 'Findings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SideBySideTab(
            session: widget.session,
            onAddRedesign: _pickRedesign,
          ),
          _FindingsSummaryTab(session: widget.session),
        ],
      ),
    );
  }
}

// ── Tab 1: Side-by-side ───────────────────────────────────────────────────────

class _SideBySideTab extends StatefulWidget {
  final EvaluationSession session;
  final VoidCallback onAddRedesign;

  const _SideBySideTab({required this.session, required this.onAddRedesign});

  @override
  State<_SideBySideTab> createState() => _SideBySideTabState();
}

class _SideBySideTabState extends State<_SideBySideTab> {
  // Synchronised scroll controllers
  final ScrollController _leftScroll = ScrollController();
  final ScrollController _rightScroll = ScrollController();
  bool _syncing = false;
  int _selectedScreenIndex = 0; // which original screenshot to show

  @override
  void initState() {
    super.initState();
    _leftScroll.addListener(() {
      if (_syncing) return;
      _syncing = true;
      if (_rightScroll.hasClients) {
        _rightScroll.jumpTo(_leftScroll.offset
            .clamp(0.0, _rightScroll.position.maxScrollExtent));
      }
      _syncing = false;
    });
    _rightScroll.addListener(() {
      if (_syncing) return;
      _syncing = true;
      if (_leftScroll.hasClients) {
        _leftScroll.jumpTo(_rightScroll.offset
            .clamp(0.0, _leftScroll.position.maxScrollExtent));
      }
      _syncing = false;
    });
  }

  @override
  void dispose() {
    _leftScroll.dispose();
    _rightScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final screenshots = session.screenshots;
    final selectedPath = screenshots.isNotEmpty
        ? screenshots[_selectedScreenIndex.clamp(0, screenshots.length - 1)]
            .imagePath
        : session.originalImagePath;

    return Column(
      children: [
        // ── Summary strip ──────────────────────────────────────────────────
        _ComparisonSummaryStrip(session: session),

        // ── Screenshot selector (only when session has multiple) ───────────
        if (screenshots.length > 1)
          _ScreenshotSelector(
            screenshots: screenshots,
            selectedIndex: _selectedScreenIndex,
            onSelect: (i) => setState(() => _selectedScreenIndex = i),
          ),

        // ── Images ────────────────────────────────────────────────────────
        Expanded(
          child: Row(
            children: [
              // Original
              Expanded(
                child: Column(
                  children: [
                    _PaneHeader(
                      label: AppStrings.original,
                      color: AppTheme.primary,
                      icon: Icons.image_outlined,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _leftScroll,
                        child: SafeFileImage(
                          path: selectedPath,
                          fit: BoxFit.fitWidth,
                          fallback: const _BrokenImage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),

              // Redesign
              Expanded(
                child: Column(
                  children: [
                    _PaneHeader(
                      label: AppStrings.redesign,
                      color: AppTheme.secondary,
                      icon: Icons.auto_fix_high_outlined,
                    ),
                    Expanded(
                      child: session.hasRedesign
                          ? SingleChildScrollView(
                              controller: _rightScroll,
                              child: SafeFileImage(
                                path: session.redesignImagePath!,
                                fit: BoxFit.fitWidth,
                                fallback: const _BrokenImage(),
                              ),
                            )
                          : _AddRedesignPlaceholder(
                              onTap: widget.onAddRedesign),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScreenshotSelector extends StatelessWidget {
  final List<ScreenshotAnalysis> screenshots;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _ScreenshotSelector({
    required this.screenshots,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(
            AppStrings.selectScreenToCompare,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(screenshots.length, (i) {
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => onSelect(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.divider,
                          ),
                        ),
                        child: Text(
                          screenshots[i].label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaneHeader extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _PaneHeader(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddRedesignPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _AddRedesignPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: AppTheme.surface,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 40,
                color: AppTheme.secondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text(
              AppStrings.addRedesignScreenshot,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image_outlined,
          size: 48, color: AppTheme.textSecondary),
    );
  }
}

class _ComparisonSummaryStrip extends StatelessWidget {
  final EvaluationSession session;
  const _ComparisonSummaryStrip({required this.session});

  @override
  Widget build(BuildContext context) {
    final accepted = session.acceptedFindings;
    final highSeverity =
        accepted.where((f) => f.severity >= 3).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          _StripStat(
            label: AppStrings.acceptedIssues,
            value: session.acceptedCount.toString(),
            color: AppTheme.primary,
          ),
          const SizedBox(width: 20),
          _StripStat(
            label: AppStrings.highCatastrophic,
            value: highSeverity.toString(),
            color: AppTheme.error,
          ),
          const SizedBox(width: 20),
          _StripStat(
            label: AppStrings.rejected,
            value: session.rejectedCount.toString(),
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _StripStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StripStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

// ── Tab 2: Findings summary list ──────────────────────────────────────────────

class _FindingsSummaryTab extends StatelessWidget {
  final EvaluationSession session;
  const _FindingsSummaryTab({required this.session});

  @override
  Widget build(BuildContext context) {
    if (session.findings.isEmpty) {
      return Center(
        child: Text(
          AppStrings.noFindingsRecorded,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final accepted = session.acceptedFindings;
    final pending = session.findings
        .where((f) => f.status == FindingStatus.pending)
        .toList();
    final rejected = session.findings
        .where((f) => f.status == FindingStatus.rejected)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (accepted.isNotEmpty) ...[
          _GroupHeader(
            label:
                '${AppStrings.acceptedFindingsGroup} (${accepted.length})',
            color: AppTheme.secondary,
          ),
          ...accepted.map((f) => _FindingSummaryTile(finding: f)),
        ],
        if (pending.isNotEmpty) ...[
          _GroupHeader(
            label:
                '${AppStrings.pendingFindingsHeader} (${pending.length})',
            color: AppTheme.warning,
          ),
          ...pending.map((f) => _FindingSummaryTile(finding: f)),
        ],
        if (rejected.isNotEmpty) ...[
          _GroupHeader(
            label:
                '${AppStrings.rejectedFindingsGroup} (${rejected.length})',
            color: AppTheme.error,
          ),
          ...rejected.map((f) => _FindingSummaryTile(finding: f)),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _GroupHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FindingSummaryTile extends StatelessWidget {
  final Finding finding;
  const _FindingSummaryTile({required this.finding});

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
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    'H${finding.heuristicId}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        finding.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        h.shortName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                SeverityBadge(severity: finding.severity, small: true),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              finding.reason,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),

            if (finding.recommendation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      child: Text(
                        finding.recommendation,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (finding.evaluatorNote != null &&
                finding.evaluatorNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      finding.evaluatorNote!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/heuristics.dart';
import '../../core/theme/app_theme.dart';
import '../../models/evaluation_session.dart';
import '../../models/finding.dart';
import '../../services/storage_service.dart';
import '../../widgets/finding_card.dart';
import '../../widgets/severity_badge.dart';
import '../comparison/comparison_screen.dart';
import '../findings/add_finding_screen.dart';
import '../heuristics/heuristics_screen.dart';

/// Step 2: Human reviews each AI-suggested finding —
/// Accept, Edit (with severity + note), or Reject.
class FindingsReviewScreen extends StatefulWidget {
  final EvaluationSession session;

  const FindingsReviewScreen({super.key, required this.session});

  @override
  State<FindingsReviewScreen> createState() => _FindingsReviewScreenState();
}

class _FindingsReviewScreenState extends State<FindingsReviewScreen> {
  final _storage = StorageService();
  late final List<Finding> _findings;

  // Filter
  _FilterOption _filter = _FilterOption.all;

  @override
  void initState() {
    super.initState();
    _findings = List.of(widget.session.findings);
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _accept(int index) {
    setState(() => _findings[index].status = FindingStatus.accepted);
    _autosave();
  }

  void _reject(int index) {
    setState(() => _findings[index].status = FindingStatus.rejected);
    _autosave();
  }

  void _edit(int index) {
    showDialog(
      context: context,
      builder: (_) => _EditFindingDialog(finding: _findings[index]),
    ).then((updated) {
      if (updated is Finding) {
        setState(() {
          _findings[index] = updated;
        });
        _autosave();
      }
    });
  }

  void _autosave() {
    widget.session.findings = List.of(_findings);
    _storage.saveSession(widget.session);
  }

  Future<void> _saveAndFinish() async {
    widget.session.findings = List.of(_findings);
    await _storage.saveSession(widget.session);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.evaluationSaved)),
    );
  }

  void _goToComparison() {
    widget.session.findings = List.of(_findings);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComparisonScreen(session: widget.session),
      ),
    );
  }

  Future<void> _openAddFinding() async {
    final result = await Navigator.push<Finding>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFindingScreen(session: widget.session),
      ),
    );
    if (result != null) {
      setState(() => _findings.add(result));
    }
  }

  void _openHeuristics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HeuristicsScreen()),
    );
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<({int originalIndex, Finding finding})> get _filteredFindings {
    return _findings
        .asMap()
        .entries
        .where((e) {
          switch (_filter) {
            case _FilterOption.all:
              return true;
            case _FilterOption.pending:
              return e.value.status == FindingStatus.pending;
            case _FilterOption.accepted:
              return e.value.status == FindingStatus.accepted;
            case _FilterOption.rejected:
              return e.value.status == FindingStatus.rejected;
          }
        })
        .map((e) => (originalIndex: e.key, finding: e.value))
        .toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accepted = _findings.where((f) => f.status == FindingStatus.accepted).length;
    final rejected = _findings.where((f) => f.status == FindingStatus.rejected).length;
    final pending = _findings.where((f) => f.status == FindingStatus.pending).length;
    final filtered = _filteredFindings;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.reviewFindings),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: AppStrings.heuristicsReference,
            onPressed: _openHeuristics,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: AppStrings.save,
            onPressed: _saveAndFinish,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary bar ─────────────────────────────────────────────────
          _SummaryBar(
            total: _findings.length,
            accepted: accepted,
            rejected: rejected,
            pending: pending,
          ),

          // ── Filter chips ─────────────────────────────────────────────────
          _FilterRow(
            current: _filter,
            onChanged: (f) => setState(() => _filter = f),
            counts: {
              _FilterOption.all: _findings.length,
              _FilterOption.pending: pending,
              _FilterOption.accepted: accepted,
              _FilterOption.rejected: rejected,
            },
          ),

          const Divider(height: 1),

          // ── Finding list ─────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      AppStrings.noFindings,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 100),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      return FindingCard(
                        finding: item.finding,
                        onAccept: () => _accept(item.originalIndex),
                        onEdit: () => _edit(item.originalIndex),
                        onReject: () => _reject(item.originalIndex),
                        onHeuristicTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HeuristicsScreen(
                              highlightId: item.finding.heuristicId,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // ── Bottom CTAs ──────────────────────────────────────────────────────
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Add manual finding
          FloatingActionButton(
            heroTag: 'add_finding_fab',
            onPressed: _openAddFinding,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primary,
            tooltip: AppStrings.addFindingManual,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'compare_fab',
            onPressed: _goToComparison,
            icon: const Icon(Icons.compare_arrows_outlined),
            label: const Text(AppStrings.comparison),
            backgroundColor: AppTheme.secondary,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'save_fab',
            onPressed: _saveAndFinish,
            icon: const Icon(Icons.save_outlined),
            label: const Text(AppStrings.saveEvaluation),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

// ── Filter enum ───────────────────────────────────────────────────────────────

enum _FilterOption { all, pending, accepted, rejected }

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int total, accepted, rejected, pending;
  const _SummaryBar({
    required this.total,
    required this.accepted,
    required this.rejected,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _Stat(label: AppStrings.total, value: total, color: AppTheme.primary),
          const SizedBox(width: 16),
          _Stat(label: AppStrings.accepted, value: accepted, color: AppTheme.secondary),
          const SizedBox(width: 16),
          _Stat(label: AppStrings.pending, value: pending, color: AppTheme.warning),
          const SizedBox(width: 16),
          _Stat(label: AppStrings.rejected, value: rejected, color: AppTheme.error),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  final _FilterOption current;
  final ValueChanged<_FilterOption> onChanged;
  final Map<_FilterOption, int> counts;

  const _FilterRow({
    required this.current,
    required this.onChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _FilterOption.values.map((opt) {
          final label = switch (opt) {
            _FilterOption.all => 'All',
            _FilterOption.pending => 'Pending',
            _FilterOption.accepted => 'Accepted',
            _FilterOption.rejected => 'Rejected',
          };
          final count = counts[opt] ?? 0;
          final selected = current == opt;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('$label ($count)'),
              selected: selected,
              onSelected: (_) => onChanged(opt),
              selectedColor: AppTheme.primary.withValues(alpha: 0.15),
              checkmarkColor: AppTheme.primary,
              labelStyle: TextStyle(
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Edit finding dialog ───────────────────────────────────────────────────────

class _EditFindingDialog extends StatefulWidget {
  final Finding finding;
  const _EditFindingDialog({required this.finding});

  @override
  State<_EditFindingDialog> createState() => _EditFindingDialogState();
}

class _EditFindingDialogState extends State<_EditFindingDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _reasonCtrl;
  late final TextEditingController _recCtrl;
  late final TextEditingController _noteCtrl;
  late int _severity;
  late int _heuristicId;

  @override
  void initState() {
    super.initState();
    final f = widget.finding;
    _titleCtrl = TextEditingController(text: f.title);
    _reasonCtrl = TextEditingController(text: f.reason);
    _recCtrl = TextEditingController(text: f.recommendation);
    _noteCtrl = TextEditingController(text: f.evaluatorNote ?? '');
    _severity = f.severity;
    _heuristicId = f.heuristicId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _reasonCtrl.dispose();
    _recCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Finding _build() => widget.finding.copyWith(
        heuristicId: _heuristicId,
        title: _titleCtrl.text.trim(),
        reason: _reasonCtrl.text.trim(),
        recommendation: _recCtrl.text.trim(),
        severity: _severity,
        // Preserve existing status — do not force-accept on edit.
        // If finding was pending, editing keeps it pending.
        // If it was rejected and user edits via "Revise", keep rejected
        // unless the caller explicitly changes status.
        status: widget.finding.status == FindingStatus.pending
            ? FindingStatus.pending
            : widget.finding.status,
        evaluatorNote:
            _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppStrings.editFinding,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Heuristic selector
            const Text(AppStrings.heuristicViolated,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: _heuristicId,
              decoration: const InputDecoration(),
              items: kNielsenHeuristics
                  .map((h) => DropdownMenuItem(
                        value: h.id,
                        child: Text(
                          'H${h.id} – ${h.shortName}',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _heuristicId = v);
              },
            ),

            const SizedBox(height: 12),

            _Field(label: AppStrings.findingTitle, controller: _titleCtrl),
            const SizedBox(height: 12),
            _Field(label: AppStrings.reason, controller: _reasonCtrl, maxLines: 3),
            const SizedBox(height: 12),
            _Field(label: AppStrings.recommendation, controller: _recCtrl, maxLines: 3),
            const SizedBox(height: 12),
            _Field(label: AppStrings.evaluatorNote, controller: _noteCtrl, maxLines: 2),

            const SizedBox(height: 16),

            Row(
              children: [
                const Text(AppStrings.severity,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(width: 8),
                SeverityBadge(severity: _severity),
              ],
            ),
            Slider(
              value: _severity.toDouble(),
              min: 0,
              max: 4,
              divisions: 4,
              label: AppTheme.severityLabels[_severity],
              activeColor:
                  AppTheme.severityColors[_severity],
              onChanged: (v) => setState(() => _severity = v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('0', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                Text(AppStrings.cosmeticToCatastrophic,
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                Text('4', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                  TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(AppStrings.cancel),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _build()),
                  child: const Text(AppStrings.acceptAndSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

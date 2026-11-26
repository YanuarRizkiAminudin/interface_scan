import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/constants/heuristics.dart';
import '../core/theme/app_theme.dart';
import '../models/finding.dart';
import 'severity_badge.dart';

/// Compact FindingCard with collapsible detail section.
/// Header row is always visible (~60px). Detail expands on tap.
class FindingCard extends StatefulWidget {
  final Finding finding;
  final VoidCallback onAccept;
  final VoidCallback onEdit;
  final VoidCallback onReject;
  final VoidCallback? onHeuristicTap;

  const FindingCard({
    super.key,
    required this.finding,
    required this.onAccept,
    required this.onEdit,
    required this.onReject,
    this.onHeuristicTap,
  });

  @override
  State<FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<FindingCard> {
  bool _expanded = false;

  Color get _statusColor {
    switch (widget.finding.status) {
      case FindingStatus.accepted:
        return AppTheme.secondary;
      case FindingStatus.rejected:
        return AppTheme.error;
      case FindingStatus.pending:
        return AppTheme.divider;
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.finding;
    final heuristic = heuristicById(f.heuristicId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _statusColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Always-visible header row ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // H-chip
                  GestureDetector(
                    onTap: widget.onHeuristicTap,
                    child: _HChip(id: f.heuristicId),
                  ),
                  const SizedBox(width: 8),
                  // Title + heuristic name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          heuristic.shortName,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Severity badge compact
                  SeverityBadge(severity: f.severity, small: true),
                  const SizedBox(width: 6),
                  // Status icon
                  _StatusIcon(status: f.status),
                  const SizedBox(width: 4),
                  // Expand chevron
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),

            // ── Expandable detail ────────────────────────────────────
            if (_expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta: affected element + screenshot
                    if (f.affectedElement.isNotEmpty)
                      _MetaRow(icon: Icons.touch_app_outlined, text: f.affectedElement),
                    if (f.screenshotIndex != null)
                      _MetaRow(
                        icon: Icons.photo_outlined,
                        text: 'Screen ${f.screenshotIndex}',
                      ),
                    if (f.affectedElement.isNotEmpty || f.screenshotIndex != null)
                      const SizedBox(height: 8),

                    // Reason
                    if (f.reason.isNotEmpty) ...[
                      _DetailSection(label: AppStrings.reason, text: f.reason),
                      const SizedBox(height: 8),
                    ],

                    // Recommendation
                    if (f.recommendation.isNotEmpty) ...[
                      _DetailSection(
                        label: AppStrings.recommendation,
                        text: f.recommendation,
                        highlight: true,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Evaluator note
                    if (f.evaluatorNote != null && f.evaluatorNote!.isNotEmpty) ...[
                      _DetailSection(label: AppStrings.evaluatorNote, text: f.evaluatorNote!),
                      const SizedBox(height: 8),
                    ],

                    // AI confidence
                    Row(
                      children: [
                        _ConfidencePill(value: f.confidence),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),

              // ── Action buttons ─────────────────────────────────────
              if (f.status == FindingStatus.pending)
                _PendingActions(
                  onReject: widget.onReject,
                  onEdit: widget.onEdit,
                  onAccept: widget.onAccept,
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text(AppStrings.revise),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HChip extends StatelessWidget {
  final int id;
  const _HChip({required this.id});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text('H$id',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primary)),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final FindingStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case FindingStatus.accepted:
        return const Icon(Icons.check_circle_rounded, color: AppTheme.secondary, size: 18);
      case FindingStatus.rejected:
        return const Icon(Icons.cancel_rounded, color: AppTheme.error, size: 18);
      case FindingStatus.pending:
        return const Icon(Icons.radio_button_unchecked, color: AppTheme.textSecondary, size: 18);
    }
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String label;
  final String text;
  final bool highlight;
  const _DetailSection({required this.label, required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3)),
        const SizedBox(height: 4),
        if (highlight)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2)),
            ),
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5)),
          )
        else
          Text(text,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5)),
      ],
    );
  }
}

class _PendingActions extends StatelessWidget {
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onAccept;
  const _PendingActions({required this.onReject, required this.onEdit, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          // Reject — icon only button
          _ActionBtn(
            icon: Icons.close_rounded,
            label: AppStrings.reject,
            color: AppTheme.error,
            filled: false,
            onTap: onReject,
          ),
          const SizedBox(width: 8),
          // Edit — icon only button
          _ActionBtn(
            icon: Icons.edit_outlined,
            label: AppStrings.edit,
            color: AppTheme.primary,
            filled: false,
            onTap: onEdit,
          ),
          const SizedBox(width: 8),
          // Accept — filled, takes remaining space
          Expanded(
            child: _ActionBtn(
              icon: Icons.check_rounded,
              label: AppStrings.accept,
              color: AppTheme.secondary,
              filled: true,
              onTap: onAccept,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon, required this.label, required this.color,
    required this.filled, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  final double value;
  const _ConfidencePill({required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    final color = value >= 0.7
        ? AppTheme.secondary
        : value >= 0.4
            ? AppTheme.warning
            : AppTheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text('AI $pct%',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

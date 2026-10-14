import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/constants/heuristics.dart';
import '../core/theme/app_theme.dart';
import '../models/finding.dart';
import 'severity_badge.dart';

/// A card that displays a single [Finding] with Accept / Edit / Reject controls.
/// Tapping the heuristic chip navigates to the Heuristics Reference screen.
class FindingCard extends StatelessWidget {
  final Finding finding;
  final VoidCallback onAccept;
  final VoidCallback onEdit;
  final VoidCallback onReject;
  /// Optional: called when the user taps the H-chip to view the heuristic detail.
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
  Widget build(BuildContext context) {
    final heuristic = heuristicById(finding.heuristicId);
    final statusColor = _statusColor(finding.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                GestureDetector(
                  onTap: onHeuristicTap,
                  child: _HeuristicChip(id: finding.heuristicId),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    finding.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                _StatusIndicator(status: finding.status),
              ],
            ),

            const SizedBox(height: 4),
            Text(
              heuristic.fullName,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),

            // Screenshot attribution
            if (finding.screenshotIndex != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.photo_outlined,
                      size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${AppStrings.screenOf} ${finding.screenshotIndex}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],

            const Divider(height: 16),

            // ── Reason ──────────────────────────────────────────────────────
            if (finding.reason.isNotEmpty)
              _Section(label: AppStrings.reason, text: finding.reason),
            if (finding.recommendation.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Section(
                  label: AppStrings.recommendation,
                  text: finding.recommendation),
            ],

            if (finding.evaluatorNote != null &&
                finding.evaluatorNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Section(
                  label: AppStrings.evaluatorNote,
                  text: finding.evaluatorNote!),
            ],

            const SizedBox(height: 10),

            // ── Severity + confidence ────────────────────────────────────────
            Row(
              children: [
                SeverityBadge(severity: finding.severity),
                const SizedBox(width: 8),
                _ConfidencePill(value: finding.confidence),
                const Spacer(),
              ],
            ),

            // ── Action buttons ───────────────────────────────────────────────
            if (finding.status == FindingStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text(AppStrings.reject),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text(AppStrings.edit),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text(AppStrings.accept),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text(AppStrings.revise),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(FindingStatus s) {
    switch (s) {
      case FindingStatus.accepted:
        return AppTheme.secondary;
      case FindingStatus.rejected:
        return AppTheme.error;
      case FindingStatus.pending:
        return AppTheme.divider;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HeuristicChip extends StatelessWidget {
  final int id;
  const _HeuristicChip({required this.id});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'H$id',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final FindingStatus status;
  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case FindingStatus.accepted:
        color = AppTheme.secondary;
        icon = Icons.check_circle;
        break;
      case FindingStatus.rejected:
        color = AppTheme.error;
        icon = Icons.cancel;
        break;
      case FindingStatus.pending:
        color = AppTheme.textSecondary;
        icon = Icons.hourglass_empty;
        break;
    }
    return Icon(icon, color: color, size: 20);
  }
}

class _Section extends StatelessWidget {
  final String label;
  final String text;
  const _Section({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(text,
            style:
                const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
      ],
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        'AI $pct%',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

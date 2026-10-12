import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A compact card showing one visual metric with a label, value, and
/// an optional colour-coded bar.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? interpretation;
  final double? barValue; // 0.0 – 1.0
  final Color? barColor;
  final IconData icon;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.interpretation,
    this.barValue,
    this.barColor,
    this.icon = Icons.bar_chart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            if (barValue != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: barValue!.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppTheme.divider,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(barColor ?? AppTheme.primary),
                ),
              ),
            ],
            if (interpretation != null) ...[
              const SizedBox(height: 6),
              Text(
                interpretation!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

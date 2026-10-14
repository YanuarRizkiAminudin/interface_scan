import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/heuristics.dart';
import '../../core/theme/app_theme.dart';

/// Reference screen showing all 10 Nielsen Usability Heuristics
/// with their full name, description, and a practical example.
class HeuristicsScreen extends StatefulWidget {
  /// If non-null, the screen opens with that heuristic expanded.
  final int? highlightId;

  const HeuristicsScreen({super.key, this.highlightId});

  @override
  State<HeuristicsScreen> createState() => _HeuristicsScreenState();
}

class _HeuristicsScreenState extends State<HeuristicsScreen> {
  final _scrollController = ScrollController();
  final List<GlobalKey> _keys =
      List.generate(10, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    if (widget.highlightId != null) {
      // Scroll to the highlighted heuristic after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final idx = widget.highlightId! - 1;
        if (idx >= 0 && idx < 10) {
          final ctx = _keys[idx].currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.heuristicsReference),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ── Intro ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              AppStrings.heuristicsSubtitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              AppStrings.heuristicsIntro,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Heuristic list ───────────────────────────────────────────
          ...kNielsenHeuristics.map((h) {
            final highlighted = widget.highlightId == h.id;
            return _HeuristicCard(
              key: _keys[h.id - 1],
              heuristic: h,
              highlighted: highlighted,
              initiallyExpanded: highlighted,
            );
          }),
        ],
      ),
    );
  }
}

class _HeuristicCard extends StatelessWidget {
  final NielsenHeuristic heuristic;
  final bool highlighted;
  final bool initiallyExpanded;

  const _HeuristicCard({
    super.key,
    required this.heuristic,
    this.highlighted = false,
    this.initiallyExpanded = false,
  });

  /// Practical example for each heuristic — short and memorable.
  static const Map<int, String> _examples = {
    1: 'Example: A progress bar shows how many steps remain during checkout.',
    2: 'Example: Use "Buy Now" instead of "Initiate Purchase Transaction".',
    3: 'Example: A clear "Undo" button lets users reverse accidental deletions.',
    4: 'Example: All primary action buttons use the same blue color throughout.',
    5: 'Example: A date picker disables past dates to prevent invalid input.',
    6: 'Example: Recently used items appear at the top so users don\'t memorize paths.',
    7: 'Example: Keyboard shortcuts let power users submit forms without clicking.',
    8: 'Example: A dashboard shows only key metrics, hiding rarely-used data.',
    9: 'Example: "Password must be 8+ characters" appears inline, not after submit.',
    10: 'Example: A "?" button opens a quick-start guide for first-time users.',
  };

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppTheme.primary : AppTheme.textSecondary;

    return Container(
      decoration: highlighted
          ? BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.04),
              border: Border(
                left: BorderSide(color: AppTheme.primary, width: 3),
              ),
            )
          : null,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              'H${heuristic.id}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          title: Text(
            heuristic.shortName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: highlighted
                  ? AppTheme.primary
                  : AppTheme.textPrimary,
            ),
          ),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            // Description
            Text(
              heuristic.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),

            // Practical example
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 15, color: AppTheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _examples[heuristic.id] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                        height: 1.5,
                      ),
                    ),
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

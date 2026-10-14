
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/evaluation_session.dart';
import '../../services/storage_service.dart';
import '../../widgets/safe_file_image.dart';
import '../analysis/analysis_screen.dart';
import '../detail/evaluation_detail_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  List<EvaluationSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    final sessions = await _storage.loadAllSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    }
  }

  Future<void> _openNewAnalysis() async {
    final apiKey = await _storage.getApiKey();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnalysisScreen(apiKey: apiKey)),
    );
    // Reload history after returning — the session may have been saved.
    _loadSessions();
  }

  Future<void> _openSession(EvaluationSession session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvaluationDetailScreen(session: session),
      ),
    );
    _loadSessions();
  }

  Future<void> _deleteSession(EvaluationSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.deleteEvaluation),
        content: const Text(AppStrings.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _storage.deleteSession(session.id);
      _loadSessions();
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppStrings.settings,
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const _EmptyState()
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView(
                    padding:
                        const EdgeInsets.only(top: 12, bottom: 100),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Text(
                          '${_sessions.length} '
                          '${_sessions.length == 1 ? AppStrings.evaluation : AppStrings.evaluations}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      ..._sessions.map(
                        (s) => _SessionCard(
                          session: s,
                          onTap: () => _openSession(s),
                          onDelete: () => _deleteSession(s),
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewAnalysis,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text(AppStrings.newEvaluation),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_search,
              size: 72,
              color: AppTheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 24),
            const Text(
              AppStrings.appName,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              AppStrings.appTagline,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.noEvaluationsYet,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final EvaluationSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, HH:mm');
    final accepted = session.acceptedCount;
    final total = session.totalFindings;
    final count = session.screenshotCount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Thumbnail: first screenshot
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: session.hasScreenshots
                      ? SafeFileImage(
                          path: session.screenshots.first.imagePath,
                          fit: BoxFit.cover,
                          width: 56,
                          height: 56,
                          fallback: const _ImagePlaceholder(),
                        )
                      : const _ImagePlaceholder(),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (session.appName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        session.appName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      fmt.format(session.updatedAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Chip(
                          label:
                              '$count ${count == 1 ? AppStrings.screen : AppStrings.screens2}',
                          color: AppTheme.textSecondary,
                        ),
                        if (total > 0)
                          _Chip(
                            label:
                                '$total ${total == 1 ? AppStrings.finding : AppStrings.findings}',
                            color: AppTheme.primary,
                          ),
                        if (accepted > 0)
                          _Chip(
                            label: '$accepted ${AppStrings.accepted.toLowerCase()}',
                            color: AppTheme.secondary,
                          ),
                        if (session.hasRedesign)
                          _Chip(
                            label: AppStrings.redesignBadge,
                            color: AppTheme.warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.textSecondary),
                onPressed: onDelete,
                tooltip: AppStrings.delete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: const Icon(Icons.image_outlined,
          color: AppTheme.textSecondary, size: 28),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

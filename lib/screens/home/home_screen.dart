import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/evaluation_session.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/safe_file_image.dart';
import '../analysis/analysis_screen.dart';
import '../detail/evaluation_detail_screen.dart';
import '../settings/settings_screen.dart';

// ── Sort options ──────────────────────────────────────────────────────────────

enum _SortOption { newest, oldest, mostFindings }

extension _SortOptionX on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.newest:      return 'Newest first';
      case _SortOption.oldest:      return 'Oldest first';
      case _SortOption.mostFindings:return 'Most findings';
    }
  }
  IconData get icon {
    switch (this) {
      case _SortOption.newest:      return Icons.arrow_downward_rounded;
      case _SortOption.oldest:      return Icons.arrow_upward_rounded;
      case _SortOption.mostFindings:return Icons.bar_chart_rounded;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  List<EvaluationSession> _all = [];
  List<EvaluationSession> _filtered = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  _SortOption _sort = _SortOption.newest;
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _loadSessions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    final sessions = await _storage.loadAllSessions();
    if (mounted) {
      _all = sessions;
      _applyFilter();
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    var result = q.isEmpty
        ? List.of(_all)
        : _all.where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.appName.toLowerCase().contains(q) ||
            s.mainTask.toLowerCase().contains(q)).toList();

    switch (_sort) {
      case _SortOption.newest:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case _SortOption.oldest:
        result.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case _SortOption.mostFindings:
        result.sort((a, b) => b.totalFindings.compareTo(a.totalFindings));
        break;
    }
    if (mounted) setState(() => _filtered = result);
  }

  Future<void> _openNewAnalysis() async {
    final apiKey = await _storage.getApiKey();
    if (!mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => AnalysisScreen(apiKey: apiKey)));
    _loadSessions();
  }

  Future<void> _openSession(EvaluationSession session) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => EvaluationDetailScreen(session: session)));
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
              child: const Text(AppStrings.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text(AppStrings.delete)),
        ],
      ),
    );
    if (confirmed == true) {
      await _storage.deleteSession(session.id);
      _loadSessions();
    }
  }

  void _openSettings() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed == true) await AuthService.signOut();
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) _searchCtrl.clear();
    });
  }

  void _showSortMenu() async {
    final chosen = await showModalBottomSheet<_SortOption>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sort evaluations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            ..._SortOption.values.map((opt) => ListTile(
                  leading: Icon(opt.icon,
                      color: _sort == opt
                          ? AppTheme.primary
                          : AppTheme.textSecondary),
                  title: Text(opt.label),
                  trailing: _sort == opt
                      ? const Icon(Icons.check_rounded,
                          color: AppTheme.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, opt),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null && chosen != _sort) {
      setState(() => _sort = chosen);
      _applyFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          // Search toggle
          IconButton(
            icon: Icon(_searchVisible
                ? Icons.search_off_rounded
                : Icons.search_rounded),
            tooltip: 'Search',
            onPressed: _toggleSearch,
          ),
          // Sort
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            onPressed: _showSortMenu,
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppStrings.settings,
            onPressed: _openSettings,
          ),
          // User avatar
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _signOut,
              child: const _UserAvatar(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: _searchVisible
                ? Container(
                    color: AppTheme.primary,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search by name, app, or task…',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 18),
                                onPressed: _searchCtrl.clear,
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        isDense: true,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── List ───────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _all.isEmpty
                    ? const _EmptyState()
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 48,
                                    color: AppTheme.textSecondary
                                        .withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                const Text('No evaluations match.',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadSessions,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(
                                  top: 8, bottom: 100),
                              itemCount: _filtered.length + 1,
                              itemBuilder: (ctx, i) {
                                if (i == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 8),
                                    child: Text(
                                      '${_filtered.length} '
                                      '${_filtered.length == 1 ? AppStrings.evaluation : AppStrings.evaluations}'
                                      '${_searchCtrl.text.isNotEmpty ? ' found' : ''}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary),
                                    ),
                                  );
                                }
                                final s = _filtered[i - 1];
                                return _SessionCard(
                                  session: s,
                                  onTap: () => _openSession(s),
                                  onDelete: () => _deleteSession(s),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewAnalysis,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text(AppStrings.newEvaluation),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 3,
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
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: const Icon(Icons.image_search_rounded,
                  size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            const Text(AppStrings.appName,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text(AppStrings.appTagline,
                style: TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            Text(
              AppStrings.noEvaluationsYet,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.6),
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
    final fmt = DateFormat('dd MMM yyyy');
    final accepted = session.acceptedCount;
    final pending  = session.pendingCount;
    final total    = session.totalFindings;
    final count    = session.screenshotCount;

    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.sp16, vertical: AppTheme.sp4),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded,
                color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('Delete',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(AppStrings.deleteEvaluation),
            content: const Text(AppStrings.deleteConfirm),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(AppStrings.cancel)),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style:
                      TextButton.styleFrom(foregroundColor: AppTheme.error),
                  child: const Text(AppStrings.delete)),
            ],
          ),
        );
        return confirmed == true;
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // ── Thumbnail ────────────────────────────────────────
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSm),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: session.hasScreenshots
                        ? SafeFileImage(
                            path: session.screenshots.first.imagePath,
                            fit: BoxFit.cover,
                            width: 64,
                            height: 64,
                            fallback: const _ImagePlaceholder(),
                          )
                        : const _ImagePlaceholder(),
                  ),
                ),

                const SizedBox(width: 14),

                // ── Info ─────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        session.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            height: 1.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // App name
                      if (session.appName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.apps_rounded,
                              size: 12, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(session.appName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ],

                      const SizedBox(height: 4),

                      // Date
                      Text(fmt.format(session.updatedAt),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),

                      const SizedBox(height: 6),

                      // Chips
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _Chip(
                            label: '$count screen${count == 1 ? '' : 's'}',
                            color: AppTheme.textSecondary,
                          ),
                          if (total > 0)
                            _Chip(
                              label: '$total finding${total == 1 ? '' : 's'}',
                              color: AppTheme.primary,
                            ),
                          if (accepted > 0)
                            _Chip(
                              label: '$accepted accepted',
                              color: AppTheme.secondary,
                            ),
                          if (pending > 0)
                            _Chip(
                              label: '$pending pending',
                              color: AppTheme.warning,
                            ),
                          if (session.hasRedesign)
                            _Chip(
                              label: 'Redesign',
                              color: AppTheme.primary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Chevron ──────────────────────────────────────────
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary, size: 20),
              ],
            ),
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
      color: AppTheme.primaryLight,
      child: const Icon(Icons.image_outlined,
          color: AppTheme.primary, size: 28),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    final user     = AuthService.currentUser;
    final photoUrl = user?.photoURL;
    final name     = user?.displayName ?? user?.email ?? 'User';
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Tooltip(
      message: '$name\nTap to sign out',
      child: CircleAvatar(
        radius: 17,
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        backgroundImage:
            photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null
            ? Text(
                initial,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
              )
            : null,
      ),
    );
  }
}

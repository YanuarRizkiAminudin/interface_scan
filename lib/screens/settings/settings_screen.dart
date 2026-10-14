import 'package:flutter/material.dart';

import '../../config/ai_config.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../heuristics/heuristics_screen.dart';

/// Full-page Settings screen.
/// Accessible via the gear icon in the HomeScreen app bar.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _apiKeyCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await _storage.getApiKey();
    if (mounted) {
      setState(() {
        _apiKeyCtrl.text = key;
        _loaded = true;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _storage.saveApiKey(_apiKeyCtrl.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.apiKeySaved)),
    );
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── AI section ──────────────────────────────────────────
                const _SectionLabel(label: 'AI Integration'),
                const SizedBox(height: 8),

                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppStrings.geminiApiKey,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _apiKeyCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            hintText: AppStrings.geminiApiKeyHint,
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          AppStrings.geminiApiKeyHelp,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Save button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(AppStrings.save),
                  ),
                ),

                const SizedBox(height: 32),

                // ── About section ───────────────────────────────────────
                const _SectionLabel(label: 'About'),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AboutRow(
                          label: 'App',
                          value: AppStrings.appName,
                        ),
                        const SizedBox(height: 8),
                        _AboutRow(
                          label: 'Description',
                          value: AppStrings.appTagline,
                        ),
                        const SizedBox(height: 8),
                        _AboutRow(
                          label: 'AI Model',
                          value: kGeminiModelLabel,
                        ),
                        const SizedBox(height: 8),
                        const _AboutRow(
                          label: 'Heuristics',
                          value: "Nielsen's 10 Usability Heuristics",
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Resources section ──────────────────────────────────
                const _SectionLabel(label: 'Resources'),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_outlined,
                        color: AppTheme.primary),
                    title: const Text(
                      AppStrings.heuristicsReference,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      AppStrings.heuristicsSubtitle,
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textSecondary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HeuristicsScreen()),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

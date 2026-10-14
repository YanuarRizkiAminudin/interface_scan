import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/ai_config.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../heuristics/heuristics_screen.dart';

/// Full-page Settings screen.
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
  bool _testing = false;
  bool _loaded = false;
  String? _keyError;

  @override
  void initState() {
    super.initState();
    _load();
    _apiKeyCtrl.addListener(() {
      if (_keyError != null) setState(() => _keyError = null);
    });
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

  /// Returns true if the key looks valid (starts with AIza, exactly 39 chars).
  bool _isKeyFormatValid(String key) =>
      key.startsWith('AIza') && key.length == 39;

  Future<void> _save() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isNotEmpty && !_isKeyFormatValid(key)) {
      setState(() => _keyError = AppStrings.apiKeyInvalid);
      return;
    }
    setState(() { _saving = true; _keyError = null; });
    await _storage.saveApiKey(key);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.apiKeySaved)),
    );
  }

  Future<void> _testConnection() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _keyError = 'Enter an API key first.');
      return;
    }
    if (!_isKeyFormatValid(key)) {
      setState(() => _keyError = AppStrings.apiKeyInvalid);
      return;
    }

    setState(() { _testing = true; _keyError = null; });

    // Ping Gemini with a minimal request.
    try {
      final uri = Uri.parse(
          '$kGeminiBaseUrl$kGeminiModel:generateContent?key=$key');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: '{"contents":[{"parts":[{"text":"hi"}]}],'
            '"generationConfig":{"maxOutputTokens":1}}',
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.connectionSuccess),
            backgroundColor: AppTheme.secondary,
          ),
        );
      } else if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        setState(() => _keyError =
            'Invalid key (HTTP ${response.statusCode}). Check the key and try again.');
      } else if (response.statusCode == 404) {
        setState(() => _keyError =
            'Model "$kGeminiModel" not found (HTTP 404). The app may need an update.');
      } else {
        setState(() => _keyError =
            'Gemini returned HTTP ${response.statusCode}. Try again later.');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _keyError = 'Connection timed out. Check your network.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _keyError = 'Network error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
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
                // ── AI Integration ─────────────────────────────────────
                _SectionLabel(label: AppStrings.sectionAi),
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
                            errorText: _keyError,
                            errorMaxLines: 3,
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

                const SizedBox(height: 12),

                // ── Save + Test buttons ─────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_testing || _saving) ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering_rounded,
                                size: 18),
                        label: Text(_testing
                            ? AppStrings.testingConnection
                            : AppStrings.testConnection),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_saving || _testing) ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: const Text(AppStrings.save),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── About ───────────────────────────────────────────────
                _SectionLabel(label: AppStrings.sectionAbout),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AboutRow(
                            label: AppStrings.labelApp,
                            value: AppStrings.appName),
                        const SizedBox(height: 8),
                        _AboutRow(
                            label: AppStrings.labelDescription,
                            value: AppStrings.appTagline),
                        const SizedBox(height: 8),
                        _AboutRow(
                            label: AppStrings.labelAiModel,
                            value: kGeminiModelLabel),
                        const SizedBox(height: 8),
                        _AboutRow(
                            label: AppStrings.labelHeuristics,
                            value: AppStrings.nielsenHeuristics),
                        const SizedBox(height: 8),
                        _AboutRow(
                            label: AppStrings.labelVersion,
                            value: AppStrings.appVersion),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Resources ───────────────────────────────────────────
                _SectionLabel(label: AppStrings.sectionResources),
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
      label,
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
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/heuristics.dart';
import '../../core/theme/app_theme.dart';
import '../../models/evaluation_session.dart';
import '../../models/finding.dart';
import '../../services/storage_service.dart';
import '../../widgets/severity_badge.dart';

/// Screen for adding a manual finding (without AI).
/// The evaluator picks a heuristic, writes a title, reason,
/// recommendation, and sets the severity.
class AddFindingScreen extends StatefulWidget {
  final EvaluationSession session;

  const AddFindingScreen({super.key, required this.session});

  @override
  State<AddFindingScreen> createState() => _AddFindingScreenState();
}

class _AddFindingScreenState extends State<AddFindingScreen> {
  final _storage = StorageService();
  final _uuid = const Uuid();

  final _titleCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _recCtrl = TextEditingController();

  int _heuristicId = 1;
  int _severity = 2;
  bool _saving = false;

  String? _titleError;
  String? _reasonError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _reasonCtrl.dispose();
    _recCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    bool ok = true;
    setState(() {
      _titleError = _titleCtrl.text.trim().isEmpty
          ? AppStrings.titleRequired
          : null;
      _reasonError = _reasonCtrl.text.trim().isEmpty
          ? AppStrings.reasonRequired
          : null;
    });
    if (_titleError != null || _reasonError != null) ok = false;
    return ok;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);

    final finding = Finding(
      id: _uuid.v4(),
      heuristicId: _heuristicId,
      title: _titleCtrl.text.trim(),
      reason: _reasonCtrl.text.trim(),
      recommendation: _recCtrl.text.trim(),
      confidence: 1.0, // manually added = full confidence
      severity: _severity,
      status: FindingStatus.accepted, // manual = auto-accepted
    );

    widget.session.findings.add(finding);
    await _storage.saveSession(widget.session);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.findingAdded)),
    );
    Navigator.pop(context, finding);
  }

  @override
  Widget build(BuildContext context) {
    final selected = heuristicById(_heuristicId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.addFindingManual),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    AppStrings.save,
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Info banner ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_outline,
                    size: 16, color: AppTheme.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.manualFindingInfo,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Heuristic picker ─────────────────────────────────────────
          const _FieldLabel(label: AppStrings.heuristicViolated),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _heuristicId,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
            ),
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
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              selected.description,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic),
            ),
          ),

          const SizedBox(height: 16),

          // ── Title ────────────────────────────────────────────────────
          const _FieldLabel(label: AppStrings.findingTitle, required: true),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: AppStrings.findingTitleHint,
              filled: true,
              fillColor: Colors.white,
              errorText: _titleError,
            ),
            onChanged: (_) {
              if (_titleError != null) {
                setState(() => _titleError = null);
              }
            },
          ),

          const SizedBox(height: 16),

          // ── Reason ───────────────────────────────────────────────────
          const _FieldLabel(
              label: AppStrings.findingReason, required: true),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: AppStrings.findingReasonHint,
              filled: true,
              fillColor: Colors.white,
              alignLabelWithHint: true,
              errorText: _reasonError,
            ),
            onChanged: (_) {
              if (_reasonError != null) {
                setState(() => _reasonError = null);
              }
            },
          ),

          const SizedBox(height: 16),

          // ── Recommendation (optional) ─────────────────────────────────
          const _FieldLabel(label: AppStrings.findingRecommendation),
          const SizedBox(height: 8),
          TextField(
            controller: _recCtrl,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: AppStrings.findingRecommendationHint,
              filled: true,
              fillColor: Colors.white,
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 24),

          // ── Severity ──────────────────────────────────────────────────
          Row(
            children: [
              const _FieldLabel(label: AppStrings.severity),
              const SizedBox(width: 12),
              SeverityBadge(severity: _severity),
            ],
          ),
          Slider(
            value: _severity.toDouble(),
            min: 0,
            max: 4,
            divisions: 4,
            label: AppTheme.severityLabels[_severity],
            activeColor: AppTheme.severityColors[_severity],
            onChanged: (v) => setState(() => _severity = v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0 – Cosmetic',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              Text('4 – Catastrophic',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),

          const SizedBox(height: 32),

          // ── Save button ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.add_task),
              label: const Text(AppStrings.addFinding),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.error,
                  fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

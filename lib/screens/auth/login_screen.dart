import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';

/// Android-style login — single "Sign in with Google" button.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    final user = await AuthService.signInWithGoogle();
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Sign-in cancelled or failed. Please try again.';
      });
    }
    // On success main.dart StreamBuilder navigates to Home/Onboarding.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FF), Color(0xFFF1F3F4)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 3),

                // ── App icon ───────────────────────────────────────────
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.image_search_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                // ── App name ───────────────────────────────────────────
                const Text(
                  'InterfaceScan',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'AI-Assisted UI Evaluation',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const Spacer(flex: 2),

                // ── Feature highlights ─────────────────────────────────
                _FeatureRow(
                  icon: Icons.analytics_outlined,
                  color: AppTheme.primary,
                  text: 'Visual metrics & AI heuristic analysis',
                ),
                const SizedBox(height: 10),
                _FeatureRow(
                  icon: Icons.rate_review_outlined,
                  color: AppTheme.secondary,
                  text: 'Review findings with Nielsen\'s 10 Heuristics',
                ),
                const SizedBox(height: 10),
                _FeatureRow(
                  icon: Icons.cloud_sync_outlined,
                  color: AppTheme.warning,
                  text: 'Synced across devices with Firebase',
                ),

                const Spacer(flex: 2),

                // ── Sign in with Google ────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.textPrimary,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      side: const BorderSide(color: AppTheme.divider, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.primary,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _GoogleG(),
                              const SizedBox(width: 12),
                              const Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                // ── Error ──────────────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 16, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                const Text(
                  'Your evaluations are stored securely\nand synced across your devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Feature row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _FeatureRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Google G logo (accurate 4-colour) ────────────────────────────────────────

class _GoogleG extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w / 2;
    final center = Offset(r, r);
    final strokeW = w * 0.19;

    // 4 coloured arcs: Blue, Red, Yellow, Green
    final arcs = [
      (AppTheme.primary,     -1.57,  1.57 + 0.4), // Blue   top+right
      (AppTheme.error,        1.57,  0.95),         // Red    bottom-right
      (AppTheme.warning,      2.52,  0.52),         // Yellow bottom
      (AppTheme.secondary,    3.04,  0.57),         // Green  left
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: r - strokeW / 2);

    for (final (color, start, sweep) in arcs) {
      paint.color = color;
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    // White horizontal bar (G cutout)
    final barPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(r, r),
      Offset(w - strokeW / 2, r),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

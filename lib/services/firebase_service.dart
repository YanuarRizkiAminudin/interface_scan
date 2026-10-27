import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/evaluation_session.dart';

/// Syncs evaluation sessions to Cloud Firestore.
///
/// Data is stored per user:
///   users/{uid}/evaluations/{sessionId}
///
/// This means each user only sees their own evaluations.
class FirebaseService {
  static final _db = FirebaseFirestore.instance;

  /// Returns the Firestore collection ref for the current user.
  /// Returns null if no user is signed in.
  static CollectionReference<Map<String, dynamic>>? _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('evaluations');
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  static Future<void> saveSession(EvaluationSession session) async {
    try {
      await _col()?.doc(session.id).set(session.toJson());
    } catch (_) {}
  }

  static Future<void> deleteSession(String id) async {
    try {
      await _col()?.doc(id).delete();
    } catch (_) {}
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  static Future<List<EvaluationSession>> loadAllSessions() async {
    try {
      final col = _col();
      if (col == null) return [];
      final snapshot = await col
          .orderBy('updatedAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) {
            try {
              return EvaluationSession.fromJson(doc.data());
            } catch (_) {
              return null;
            }
          })
          .whereType<EvaluationSession>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<EvaluationSession?> loadSession(String id) async {
    try {
      final doc = await _col()?.doc(id).get();
      if (doc == null || !doc.exists || doc.data() == null) return null;
      return EvaluationSession.fromJson(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  static Future<void> syncAll(List<EvaluationSession> sessions) async {
    try {
      final col = _col();
      if (col == null) return;
      final batch = _db.batch();
      for (final s in sessions) {
        batch.set(col.doc(s.id), s.toJson());
      }
      await batch.commit();
    } catch (_) {}
  }
}

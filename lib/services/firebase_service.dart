import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/evaluation_session.dart';

/// Syncs evaluation sessions to Cloud Firestore.
///
/// Collection structure:
///   evaluations/
///     {sessionId}/          ← one document per session
///       (all EvaluationSession fields as JSON)
///
/// Used alongside [StorageService] (local JSON) for offline-first
/// dual-write: data is always saved locally first, then synced to
/// Firestore when internet is available.
class FirebaseService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'evaluations';

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Saves or overwrites a session document in Firestore.
  /// Silently ignores errors so the app works offline.
  static Future<void> saveSession(EvaluationSession session) async {
    try {
      await _db
          .collection(_collection)
          .doc(session.id)
          .set(session.toJson());
    } catch (_) {
      // Offline or quota exceeded — local storage is still the source of truth.
    }
  }

  /// Deletes a session document from Firestore.
  static Future<void> deleteSession(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
    } catch (_) {}
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Loads all sessions from Firestore, sorted newest-first.
  /// Returns an empty list on any error (network, permissions, etc).
  static Future<List<EvaluationSession>> loadAllSessions() async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return EvaluationSession.fromJson(
                  doc.data());
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

  /// Loads a single session by ID from Firestore.
  static Future<EvaluationSession?> loadSession(String id) async {
    try {
      final doc =
          await _db.collection(_collection).doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return EvaluationSession.fromJson(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  // ── Sync ──────────────────────────────────────────────────────────────────

  /// Uploads all locally-known sessions to Firestore in one batch.
  /// Call this once after the app comes online.
  static Future<void> syncAll(
      List<EvaluationSession> sessions) async {
    try {
      final batch = _db.batch();
      for (final s in sessions) {
        batch.set(
            _db.collection(_collection).doc(s.id), s.toJson());
      }
      await batch.commit();
    } catch (_) {}
  }
}

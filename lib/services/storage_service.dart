import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/evaluation_session.dart';
import 'firebase_service.dart';

/// Offline-first storage with cloud sync.
///
/// Every write goes to LOCAL storage first (always works, even offline),
/// then also to Firestore (silently skipped if offline).
///
/// On load, we merge local + Firestore data so the list is always complete
/// regardless of connectivity.
class StorageService {
  static const String _indexKey = 'session_index';
  static const String _apiKeySecureKey = 'gemini_api_key';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── API key ───────────────────────────────────────────────────────────────

  Future<String> getApiKey() async {
    try {
      return await _secure.read(key: _apiKeySecureKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _secure.delete(key: _apiKeySecureKey);
    } else {
      await _secure.write(key: _apiKeySecureKey, value: trimmed);
    }
  }

  // ── Session storage — local ───────────────────────────────────────────────

  Future<Directory> _sessionDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/sessions');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _sessionFile(String id) async {
    final dir = await _sessionDir();
    return File('${dir.path}/$id.json');
  }

  /// Saves a session locally AND syncs to Firestore.
  Future<void> saveSession(EvaluationSession session) async {
    session.updatedAt = DateTime.now();

    // 1. Save locally (always works)
    final file = await _sessionFile(session.id);
    await file.writeAsString(session.toJsonString(), flush: true);
    await _addToIndex(session.id);

    // 2. Sync to Firestore (silently ignored if offline)
    await FirebaseService.saveSession(session);
  }

  /// Loads a single session — local first, fallback to Firestore.
  Future<EvaluationSession?> loadSession(String id) async {
    try {
      final file = await _sessionFile(id);
      if (await file.exists()) {
        return EvaluationSession.fromJsonString(
            await file.readAsString());
      }
      // Not found locally — try Firestore
      return await FirebaseService.loadSession(id);
    } catch (_) {
      return null;
    }
  }

  /// Loads all sessions.
  /// Merges local + Firestore: Firestore data fills in any gaps
  /// (e.g. sessions created on another device).
  Future<List<EvaluationSession>> loadAllSessions() async {
    // Local sessions
    final ids = await _getIndex();
    final local = <EvaluationSession>[];
    for (final id in ids) {
      final s = await loadSession(id);
      if (s != null) local.add(s);
    }

    // Cloud sessions (fills gaps, does not duplicate)
    final cloud = await FirebaseService.loadAllSessions();
    final localIds = local.map((s) => s.id).toSet();
    for (final cs in cloud) {
      if (!localIds.contains(cs.id)) {
        // New session from cloud — save locally too
        final file = await _sessionFile(cs.id);
        await file.writeAsString(cs.toJsonString(), flush: true);
        await _addToIndex(cs.id);
        local.add(cs);
      }
    }

    local.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return local;
  }

  /// Deletes a session locally AND from Firestore.
  Future<void> deleteSession(String id) async {
    await _removeFromIndex(id);
    final file = await _sessionFile(id);
    if (await file.exists()) await file.delete();
    await FirebaseService.deleteSession(id);
  }

  // ── Index helpers ─────────────────────────────────────────────────────────

  Future<List<String>> _getIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  Future<void> _addToIndex(String id) async {
    final ids = await _getIndex();
    if (!ids.contains(id)) ids.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_indexKey, jsonEncode(ids));
  }

  Future<void> _removeFromIndex(String id) async {
    final ids = await _getIndex();
    ids.remove(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_indexKey, jsonEncode(ids));
  }
}

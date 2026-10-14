import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/evaluation_session.dart';

/// Persists evaluation sessions to the app-documents directory (JSON files)
/// and keeps an index in SharedPreferences.
///
/// The Gemini API key is stored separately using [FlutterSecureStorage] so it
/// is encrypted at rest (Android Keystore / iOS Keychain) and never written
/// as plain text in SharedPreferences or committed to source control.
class StorageService {
  // ── Keys ──────────────────────────────────────────────────────────────────

  static const String _indexKey = 'session_index';
  static const String _apiKeySecureKey = 'gemini_api_key';

  // Secure storage instance with Android AES encryption.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── API key (secure) ──────────────────────────────────────────────────────

  /// Reads the API key from secure storage. Returns empty string if not set.
  Future<String> getApiKey() async {
    try {
      return await _secure.read(key: _apiKeySecureKey) ?? '';
    } catch (_) {
      // If secure storage fails (e.g. first launch on some emulators), return empty.
      return '';
    }
  }

  /// Saves the API key to secure storage (encrypted at rest).
  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _secure.delete(key: _apiKeySecureKey);
    } else {
      await _secure.write(key: _apiKeySecureKey, value: trimmed);
    }
  }

  // ── Session storage ───────────────────────────────────────────────────────

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

  /// Saves or overwrites a session on disk and updates the index.
  /// The caller is responsible for setting [session.updatedAt] before calling.
  Future<void> saveSession(EvaluationSession session) async {
    // Update timestamp here so it's always accurate at save time.
    session.updatedAt = DateTime.now();
    final file = await _sessionFile(session.id);
    await file.writeAsString(session.toJsonString(), flush: true);
    await _addToIndex(session.id);
  }

  /// Loads a single session by ID. Returns null if not found or corrupted.
  Future<EvaluationSession?> loadSession(String id) async {
    try {
      final file = await _sessionFile(id);
      if (!await file.exists()) return null;
      return EvaluationSession.fromJsonString(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// Loads all sessions sorted newest-first.
  Future<List<EvaluationSession>> loadAllSessions() async {
    final ids = await _getIndex();
    final sessions = <EvaluationSession>[];
    for (final id in ids) {
      final s = await loadSession(id);
      if (s != null) sessions.add(s);
    }
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  /// Deletes a session from disk and removes it from the index.
  Future<void> deleteSession(String id) async {
    await _removeFromIndex(id);
    final file = await _sessionFile(id);
    if (await file.exists()) await file.delete();
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

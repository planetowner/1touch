import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'local_cache_store.dart';

/// Small, generic SQLite cache for validated API response envelopes.
///
/// Cache failures are deliberately non-fatal: the network repositories remain
/// usable if storage is unavailable or an old row is corrupted.
class SqliteLocalCacheStore implements LocalCacheStore {
  SqliteLocalCacheStore({Future<Database> Function()? openDatabase})
      : _openDatabaseOverride = openDatabase;

  static const _databaseName = 'onetouch_live_test_cache.db';
  static const _databaseVersion = 1;
  static const _table = 'cache_entries';

  final Future<Database> Function()? _openDatabaseOverride;
  Future<Database>? _database;

  Future<Database> _open() async {
    final existing = _database;
    if (existing != null) return existing;
    final opening = _openDatabase();
    _database = opening;
    try {
      return await opening;
    } on Object {
      // A transient plugin/storage failure must be retryable on the next
      // operation instead of leaving a permanently failed Future cached.
      if (identical(_database, opening)) _database = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final override = _openDatabaseOverride;
    if (override != null) return override();
    final databasePath = path.join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (database, _) => database.execute('''
        CREATE TABLE $_table (
          cache_key TEXT NOT NULL,
          cache_scope TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          saved_at INTEGER NOT NULL,
          schema_version INTEGER NOT NULL,
          PRIMARY KEY (cache_key, cache_scope)
        )
      '''),
    );
  }

  @override
  Future<LocalCacheRecord?> read(
    String key, {
    String scope = LocalCacheScopes.global,
    int schemaVersion = 1,
  }) async {
    try {
      final rows = await (await _open()).query(
        _table,
        where: 'cache_key = ? AND cache_scope = ?',
        whereArgs: [key, scope],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.single;
      if (row['schema_version'] != schemaVersion) {
        await delete(key, scope: scope);
        return null;
      }
      final payload = jsonDecode(row['payload_json']! as String);
      if (payload is! Map && payload is! List) {
        await delete(key, scope: scope);
        return null;
      }
      return LocalCacheRecord(
        payload: payload as Object,
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          row['saved_at']! as int,
          isUtc: true,
        ),
        schemaVersion: schemaVersion,
      );
    } on Object catch (error) {
      debugPrint('Unable to read local cache $scope/$key: $error');
      return null;
    }
  }

  @override
  Future<void> write(
    String key,
    Object payload, {
    String scope = LocalCacheScopes.global,
    int schemaVersion = 1,
  }) async {
    try {
      await (await _open()).insert(
        _table,
        {
          'cache_key': key,
          'cache_scope': scope,
          'payload_json': jsonEncode(payload),
          'saved_at': DateTime.now().toUtc().millisecondsSinceEpoch,
          'schema_version': schemaVersion,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on Object catch (error) {
      debugPrint('Unable to write local cache $scope/$key: $error');
    }
  }

  @override
  Future<void> delete(
    String key, {
    String scope = LocalCacheScopes.global,
  }) async {
    try {
      await (await _open()).delete(
        _table,
        where: 'cache_key = ? AND cache_scope = ?',
        whereArgs: [key, scope],
      );
    } on Object catch (error) {
      debugPrint('Unable to delete local cache $scope/$key: $error');
    }
  }

  @override
  Future<void> clearScope(String scope) async {
    try {
      await (await _open()).delete(
        _table,
        where: 'cache_scope = ?',
        whereArgs: [scope],
      );
    } on Object catch (error) {
      debugPrint('Unable to clear local cache scope $scope: $error');
    }
  }
}

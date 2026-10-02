import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/local/sqlite_local_cache_store.dart';

void main() {
  late Directory databaseDirectory;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    databaseDirectory =
        await Directory.systemTemp.createTemp('onetouch_sqlite_cache_test_');
    await databaseFactory.setDatabasesPath(databaseDirectory.path);
  });

  tearDownAll(() async {
    await databaseFactory.deleteDatabase(
      path.join(databaseDirectory.path, 'onetouch_cache.db'),
    );
    await databaseDirectory.delete(recursive: true);
  });

  test('restores records after store recreation and isolates scopes', () async {
    final writer = SqliteLocalCacheStore();
    await writer.write('team:83', {'name': 'Cached team'});
    await writer.write('team:83', {'name': 'Private team'},
        scope: LocalCacheScopes.authenticatedUser);

    final reader = SqliteLocalCacheStore();
    expect((await reader.read('team:83'))?.payload, {'name': 'Cached team'});
    expect(
      (await reader.read('team:83', scope: LocalCacheScopes.authenticatedUser))
          ?.payload,
      {'name': 'Private team'},
    );

    await reader.clearScope(LocalCacheScopes.authenticatedUser);
    expect(
        await reader.read('team:83', scope: LocalCacheScopes.authenticatedUser),
        isNull);
    expect((await reader.read('team:83'))?.payload, {'name': 'Cached team'});
  });
}

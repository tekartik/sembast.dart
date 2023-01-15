library sembast.database_format_test;

import 'dart:async';

// ignore_for_file: implementation_imports
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/jdb.dart';
import 'package:sembast/src/sembast_jdb.dart';
import 'package:sembast_test/jdb_test_common.dart';
import 'package:sembast_test/test_common_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(databaseTestContextJdbMemory);
}

void defineTests(DatabaseTestContextJdb ctx) {
  //String getDbPath() => ctx.outPath + '.db';
  String? dbPath;
  // worst definition ever on purpose
  var store = StoreRef<Object?, Object?>.main();

  var factory = ctx.factory;
  Future<String?> prepareForDb() async {
    dbPath = dbPathFromName('jdb_database_format.db');
    await ctx.jdbFactory.delete(dbPath!);
    return dbPath;
  }

  SembastDatabase getSembastDatabase(Database db) => (db as SembastDatabase);
  // StorageJdb getStorageJdb(Database db) => getSembastDatabase(db).storageJdb;
  Future<Map<String, Object?>> exportToMap(Database db) =>
      getJdbDatabase(db)!.exportToMap();
  DatabaseExportStat getExportStat(Database db) =>
      getDatabaseExportStat(getSembastDatabase(db));
  Future compact(Database db) => getSembastDatabase(db).compact();
  Future deltaImport(Database db, int revision) =>
      getSembastDatabase(db).jdbDeltaImport(revision);

  Future importFromMap(Map map) {
    return jdbImportFromMap(ctx.jdbFactory, dbPath!, map);
  }

  Future dbImportFromMap(Database db, Map map) {
    return jdbDatabaseImportFromMap(getJdbDatabase(db)!, map);
  }

  group('basic format', () {
    setUp(() {
      //return fs.newFile(dbPath).delete().catchError((_) {});
    });

    tearDown(() {});

    test('open_no_version', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!);
      expect(await getJdbDatabase(db)!.exportToMap(), {
        'entries': <Object>[],
        'infos': [
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1}
          },
        ]
      });
      expect(getExportStat(db).lineCount, 0);
      expect(getExportStat(db).obsoleteLineCount, 0);
      expect(getExportStat(db).compactCount, 0);
      await db.close();
    });

    test('open_version_2', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!, version: 2);
      expect(await getJdbDatabase(db)!.exportToMap(), {
        'entries': <Object>[],
        'infos': [
          {
            'id': 'meta',
            'value': {'version': 2, 'sembast': 1}
          },
        ]
      });
      expect(getExportStat(db).lineCount, 0);
      await db.close();
    });

    test('open_no_version_then_2', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!, version: 1);
      await db.close();
      db = await factory.openDatabase(dbPath!, version: 2);
      expect(await getJdbDatabase(db)!.exportToMap(), {
        'entries': <Object>[],
        'infos': [
          {
            'id': 'meta',
            'value': {'version': 2, 'sembast': 1}
          },
        ]
      });
      await db.close();
    });

    test('1 string record', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!);
      try {
        await store.record(1).put(db, 'hi');
        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': [
            {
              'id': 1,
              'value': {'key': 1, 'value': 'hi'}
            }
          ],
          'infos': [
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
            {'id': 'revision', 'value': 1},
          ]
        });
      } finally {
        await db.close();
      }
    });

    test('1 string record delete compact', () async {
      await prepareForDb();
      var store = StoreRef<int, String>.main();
      var db = await factory.openDatabase(dbPath!);
      try {
        await store.record(1).put(db, 'hi');
        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': [
            {
              'id': 1,
              'value': {'key': 1, 'value': 'hi'}
            }
          ],
          'infos': [
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
            {'id': 'revision', 'value': 1},
          ]
        });
        await store.record(1).delete(db);
        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': [
            {
              'id': 2,
              'value': {'key': 1, 'deleted': true}
            }
          ],
          'infos': [
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
            {'id': 'revision', 'value': 2}
          ]
        });
        await compact(db);
        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': <Object>[],
          'infos': [
            {'id': 'deltaMinRevision', 'value': 2},
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
            {'id': 'revision', 'value': 2}
          ]
        });
      } finally {
        await db.close();
      }
    });

    test('1 string record delete auto compact', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!);
      try {
        await store.record(1).put(db, 'hi');
        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': [
            {
              'id': 1,
              'value': {'key': 1, 'value': 'hi'}
            }
          ],
          'infos': [
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
            {'id': 'revision', 'value': 1},
          ]
        });
        db = await reOpen(db);
        var exportStat = getDatabaseExportStat(db);
        expect(exportStat.compactCount, 0);
        expect(exportStat.lineCount, 1);
        expect(exportStat.obsoleteLineCount, 0);

        await store.record(1).delete(db);
        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': [
            {
              'id': 2,
              'value': {'key': 1, 'deleted': true}
            }
          ],
          'infos': [
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
            {'id': 'revision', 'value': 2}
          ]
        });

        db = await reOpen(db);
        exportStat = getDatabaseExportStat(db);
        expect(exportStat.compactCount, 1);
        expect(exportStat.lineCount, 1);
        expect(exportStat.obsoleteLineCount, 1);
        //await compact(db);
        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': <Object>[],
          'infos': [
            {'id': 'deltaMinRevision', 'value': 2},
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
            {'id': 'revision', 'value': 2}
          ]
        });
        db = await reOpen(db);
        exportStat = getDatabaseExportStat(db);
        expect(exportStat.compactCount, 0);
        expect(exportStat.lineCount, 0);
        expect(exportStat.obsoleteLineCount, 0);
      } finally {
        await db.close();
      }
    });

    test('deltaImport', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!);
      try {
        await store.record(1).put(db, 'hi');
        var storeEmptyFuture =
            store.query().onSnapshots(db).where((event) => event.isEmpty).first;
        var recordDeleteFuture = store
            .record(1)
            .onSnapshot(db)
            .where((snapshot) => snapshot == null)
            .first;
        await dbImportFromMap(db, {
          'entries': [
            {
              'id': 2,
              'value': {'key': 1, 'deleted': true}
            }
          ],
          'infos': [
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
            {'id': 'revision', 'value': 2}
          ]
        });
        // db = await factory.openDatabase(dbPath);
        // devPrint('0');
        await deltaImport(db, 2);
        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': [
            {
              'id': 2,
              'value': {'key': 1, 'deleted': true}
            }
          ],
          'infos': [
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
            {'id': 'revision', 'value': 2}
          ]
        });
        await storeEmptyFuture;
        await recordDeleteFuture;
      } finally {
        await db.close();
      }
    });

    test('deltaImport_full', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!);
      try {
        await store.record(1).put(db, 'hi');
        var recordDeleteFuture = store
            .record(1)
            .onSnapshot(db)
            .where((snapshot) => snapshot == null)
            .first;

        await dbImportFromMap(db, {
          'entries': <Object>[],
          'infos': [
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
            {'id': 'revision', 'value': 2},
            {'id': 'deltaMinRevision', 'value': 2}
          ]
        });
        // A full import will be performed
        await deltaImport(db, 2);

        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': <int>[],
          'infos': [
            {'id': 'deltaMinRevision', 'value': 2},
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
            {'id': 'revision', 'value': 2}
          ]
        });

        await recordDeleteFuture;
        //print(1);
      } finally {
        await db.close();
      }
    });

    test('import_export', () async {
      await prepareForDb();
      await importFromMap({
        'entries': [
          {
            'id': 1,
            'value': {'key': 1, 'value': 'hi'}
          }
        ],
        'infos': [
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1}
          }
        ]
      });
      var db = await factory.openDatabase(dbPath!);

      try {
        //await store.record(1).put(db, 'hi');
        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': [
            {
              'id': 1,
              'value': {'key': 1, 'value': 'hi'}
            }
          ],
          'infos': [
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
          ]
        });
      } finally {
        await db.close();
      }
    });

    test('import_1_deleted record', () async {
      await prepareForDb();
      await importFromMap({
        'entries': [
          {
            'id': 1,
            'value': {'key': 1, 'deleted': true}
          }
        ],
        'infos': [
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1}
          }
        ]
      });
      var db = await factory.openDatabase(dbPath!);

      try {
        //await store.record(1).put(db, 'hi');
        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': [
            {
              'id': 1,
              'value': {'key': 1, 'deleted': true}
            }
          ],
          'infos': [
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
          ]
        });
      } finally {
        await db.close();
      }
    });

    test('import_1_bad record_no_value', () async {
      await prepareForDb();
      await importFromMap({
        'entries': [
          {
            'id': 1,
            'value': {'key': 1}
          },
          {
            'id': 2,
            'value': {'key': 2, 'value': 'hi'}
          }
        ],
        'infos': [
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1}
          }
        ]
      });
      var db = await factory.openDatabase(dbPath!);

      try {
        //await store.record(1).put(db, 'hi');
        expect(await getJdbDatabase(db)!.exportToMap(), {
          'entries': [
            {
              'id': 2,
              'value': {'key': 2, 'value': 'hi'}
            }
          ],
          'infos': [
            {
              'id': 'meta',
              'value': {'version': 1, 'sembast': 1}
            },
          ]
        });
      } finally {
        await db.close();
      }
    });

    test('read 1 string record _main store', () async {
      await prepareForDb();
      await importFromMap({
        'entries': [
          {
            'id': 1,
            'value': {'key': 1, 'value': 'hi'}
          }
        ],
        'infos': [
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1}
          },
          {'id': 'revision', 'value': 1}
        ]
      });
      var db = await factory.openDatabase(dbPath!);
      expect(await store.record(1).get(db), 'hi');
      expect(await exportToMap(db), {
        'entries': [
          {
            'id': 1,
            'value': {'key': 1, 'value': 'hi'}
          }
        ],
        'infos': [
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1}
          },
          {'id': 'revision', 'value': 1}
        ]
      });

      await db.close();
      db = await factory.openDatabase(dbPath!);

      expect(await exportToMap(db), {
        'entries': [
          {
            'id': 1,
            'value': {'key': 1, 'value': 'hi'}
          }
        ],
        'infos': [
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1}
          },
          {'id': 'revision', 'value': 1}
        ]
      });
      expect(getExportStat(db).lineCount, 1);
      expect(getExportStat(db).obsoleteLineCount, 0); // don't count meta
      //await compact(db);
      await db.close();
    });
  });
}

JdbDatabase? getJdbDatabase(Database database) =>
    ((database as SembastDatabase).storageJdb as SembastStorageJdb).jdbDatabase;

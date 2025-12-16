library;

import 'dart:async';

import 'package:sembast/src/api/protected/database.dart'
    show SembastDatabaseFactoryMixin, SembastDatabase;

import 'test_common.dart';

void main() {
  defineDatabaseOpenHelperTests(memoryDatabaseContext);
}

void defineDatabaseOpenHelperTests(DatabaseTestContext ctx) {
  group('open_helper', () {
    late SembastDatabaseFactoryMixin factoryMixin;
    late SembastDatabase db;

    Future<void> open() async {
      db = asSembastDatabase(
        await factoryMixin.openDatabaseWithOptions(db.path, db.openOptions),
      );
    }

    setUp(() async {
      var database = await setupForTest(ctx, 'open_helper/open.db');
      factoryMixin = asSembastDatabaseFactoryMixin(ctx.factory);
      db = asSembastDatabase(database);
    });

    tearDown(() {
      return db.close();
    });

    test('open', () async {
      expect(
        factoryMixin.getExistingDatabaseOpenHelper(db.path),
        db.openHelper,
      );
      await db.close();
      expect(factoryMixin.getExistingDatabaseOpenHelper(db.path), isNull);
    });
    test('open reopen', () async {
      var openHelper = db.openHelper;
      await db.close();
      await open();
      expect(
        factoryMixin.getExistingDatabaseOpenHelper(db.path),
        isNot(openHelper),
      );
      await db.close();
      expect(factoryMixin.getExistingDatabaseOpenHelper(db.path), isNull);
    });
    test('open no await reopen', () async {
      var openHelper = db.openHelper;
      var results = <String>[];
      unawaited(
        openHelper.closeCompleted.then((_) {
          results.add('close completed');
        }),
      );
      unawaited(
        db.close().then((_) {
          results.add('db closed');
        }),
      );

      expect(openHelper.closing, isTrue);
      expect(
        factoryMixin.getExistingDatabaseOpenHelper(db.path),
        db.openHelper,
      );
      await open();
      expect(results, ['close completed', 'db closed']);
      expect(
        factoryMixin.getExistingDatabaseOpenHelper(db.path),
        isNot(openHelper),
      );
      await db.close();
      expect(factoryMixin.getExistingDatabaseOpenHelper(db.path), isNull);
    });
  });
}

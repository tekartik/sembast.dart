import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/api/protected/database.dart';
import 'package:test/test.dart';

class _T1 with SembastDatabaseFactoryMixin {
  @override
  Future doDeleteDatabase(String path) {
    throw UnimplementedError();
  }

  @override
  bool get hasStorage => throw UnimplementedError();

  @override
  SembastDatabase newDatabase(DatabaseOpenHelper openHelper) {
    throw UnimplementedError();
  }
}

void main() {
  group('src_database_format_mixin_test', () {
    test('getExistingDatabaseOpenHelper', () async {
      var factory1 = newDatabaseFactoryMemory() as SembastDatabaseFactoryMixin;
      var factory2 = newDatabaseFactoryMemory() as SembastDatabaseFactoryMixin;
      expect(factory1.getExistingDatabaseOpenHelper('test1'), isNull);
      var db1 = await factory1.openDatabase('test1');
      expect(factory1.getExistingDatabaseOpenHelper('test1'), isNotNull);
      expect(factory2.getExistingDatabaseOpenHelper('test1'), isNull);
      var db2 = await factory2.openDatabase('test1');
      expect(factory2.getExistingDatabaseOpenHelper('test1'), isNotNull);
      await db1.close();
      expect(factory1.getExistingDatabaseOpenHelper('test1'), isNull);
      expect(factory2.getExistingDatabaseOpenHelper('test1'), isNotNull);
      await db2.close();
      expect(factory2.getExistingDatabaseOpenHelper('test1'), isNull);
    });
    test('mixin', () {
      _T1();
    });
  });
}

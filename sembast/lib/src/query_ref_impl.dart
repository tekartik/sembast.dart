import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/query_ref.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/store_ref_impl.dart';

/// A query is unique
class SembastQueryRef<K, V> implements QueryRef<K, V> {
  final StoreRef<K, V> store;
  final SembastFinder finder;

  SembastQueryRef(this.store, SembastFinder finder)
      : this.finder = finder?.clone() as SembastFinder;

  @override
  String toString() => '$store $finder)';

  @override
  Stream<List<RecordSnapshot<K, V>>> onSnapshots(Database database) {
    var db = getDatabase(database);
    var ctlr = db.listener.addQuery(this);
    // Add the existing snapshot
    db.notificationLock.synchronized(() async {
      // The first result has no changes

      // Just filter
      var allMatching = await (store as SembastStoreRef<K, V>)
          .findImmutableRecords(database,
              finder: finder == null ? null : Finder(filter: finder.filter));
      await ctlr.add(allMatching, db.cooperator);
    });
    return ctlr.stream;
  }

  @override
  Future<List<RecordSnapshot<K, V>>> getSnapshots(DatabaseClient client) =>
      store.find(client, finder: finder);
}

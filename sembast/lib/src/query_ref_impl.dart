import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/query_ref.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/store_ref_impl.dart';
import 'package:sembast/src/api/v2/sembast.dart' as v2;

// ignore_for_file: deprecated_member_use_from_same_package

/// A query is unique
class SembastQueryRef<K, V> implements QueryRef<K, V> {
  /// The store.
  final StoreRef<K, V> store;

  /// The finder.
  final SembastFinder finder;

  /// Query ref implementation.
  SembastQueryRef(this.store, SembastFinder finder)
      : this.finder = finder?.clone() as SembastFinder;

  @override
  String toString() => '$store $finder)';

  @override
  Stream<List<RecordSnapshot<K, V>>> onSnapshots(v2.Database database) {
    var db = getDatabase(database);
    // Create the query but don't add it until first result is set
    var ctlr = db.listener.addQuery(this);
    // Add the existing snapshot
    var completer = Completer<List<ImmutableSembastRecord>>();

    db.notificationLock.synchronized(() async {
      // Get the result at query time first
      var allMatching = await completer.future;
      await ctlr.add(allMatching, db.cooperator);
    });

    // Read right away to get the content at call time
    () async {
      // Just filter
      try {
        var allMatching = await (store as SembastStoreRef<K, V>)
            .findImmutableRecords(database,
                finder: finder == null ? null : Finder(filter: finder.filter));
        completer.complete(allMatching);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
        ctlr.addError(error, stackTrace);
      }
    }();
    return ctlr.stream;
  }

  @override
  Future<List<RecordSnapshot<K, V>>> getSnapshots(DatabaseClient client) =>
      store.find(client, finder: finder);

  @override
  Future<RecordSnapshot<K, V>> getSnapshot(DatabaseClient client) =>
      store.findFirst(client, finder: finder);
}

import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/debug_utils.dart';
import 'package:sembast/src/finder_impl.dart';
import 'package:sembast/src/listener.dart';
import 'package:sembast/src/store_ref_impl.dart';

import 'import_common.dart';

/// A query is unique
class SembastQueryRef<K, V> implements QueryRef<K, V> {
  /// The store.
  final StoreRef<K, V> store;

  /// The finder.
  // ignore: deprecated_member_use_from_same_package
  final SembastFinder? finder;

  /// Query ref implementation.

  SembastQueryRef(
      this.store,
      // ignore: deprecated_member_use_from_same_package
      SembastFinder? finder)
      : finder = finder?.clone();

  @override
  String toString() => '$store $finder)';

  @override
  Stream<List<RecordSnapshot<K, V>>> onSnapshots(Database database) {
    var db = getDatabase(database);
    // Create the query but don't add it until first result is set
    late QueryListenerController<K, V> ctlr;
    ctlr = db.listener.addQuery(this, onListen: () async {
      // Add the existing snapshot

      // Read right away to get the content at call time

      // Just filter
      try {
        await db.notificationLock.synchronized(() async {
          // Find all matching, ignoring offset/limit but order them
          var allMatching = await (store as SembastStoreRef<K, V>)
              .findImmutableRecords(database,
                  finder: finder?.cloneWithoutLimits());
          // ignore: unawaited_futures

          // Get the result at query time first
          if (debugListener) {
            print('matching $ctlr: ${allMatching.length} on $this');
          }

          await ctlr.add(allMatching, db.cooperator);
        });
      } catch (error, stackTrace) {
        ctlr.addError(error, stackTrace);
      }
    });
    return ctlr.stream;
  }

  @override
  Future<List<RecordSnapshot<K, V>>> getSnapshots(DatabaseClient client) =>
      store.find(client, finder: finder);

  @override
  Future<RecordSnapshot<K, V>?> getSnapshot(DatabaseClient client) =>
      store.findFirst(client, finder: finder);

  @override
  Stream<RecordSnapshot<K, V>?> onSnapshot(Database database) {
    if (finder?.limit != 1) {
      return SembastQueryRef(store, cloneFinderFindFirst(finder))
          .onSnapshot(database);
    }
    return onSnapshots(database)
        .map((list) => list.isNotEmpty ? list.first : null);
  }
}

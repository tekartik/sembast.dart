import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/debug_utils.dart';
import 'package:sembast/src/listener.dart';
import 'package:sembast/src/store_ref_impl.dart';

import 'api/filter_ref.dart';
import 'import_common.dart';

/// A query is unique
class SembastFilterRef<K extends Key, V extends Value>
    implements FilterRef<K, V> {
  /// The store.
  final StoreRef<K, V> store;

  /// The filter.
  final Filter? filter;

  /// Query ref implementation.
  SembastFilterRef(
      this.store,
      // ignore: deprecated_member_use_from_same_package
      this.filter);

  @override
  String toString() => '$store $filter';

  @override
  Stream<int> onCount(Database database) {
    var db = getDatabase(database);
    // Create the query but don't add it until first result is set
    late CountListenerController<K, V> ctlr;
    ctlr = db.listener.addCount(this, onListen: () async {
      // Add the existing snapshot

      // Read right away to get the content at call time

      // Just filter
      try {
        await db.notificationLock.synchronized(() async {
          // Find all matching, ignoring offset/limit but order them
          var keys = await (store as SembastStoreRef<K, V>)
              .filterKeys(database, filter: filter);
          // ignore: unawaited_futures

          // Get the result at query time first
          if (debugListener) {
            print('matching $ctlr: ${keys.length} on $this');
          }

          ctlr.add(keys, db.cooperator);
        });
      } catch (error, stackTrace) {
        ctlr.addError(error, stackTrace);
      }
    });
    return ctlr.stream;
  }
}

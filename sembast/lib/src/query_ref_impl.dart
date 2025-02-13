import 'package:meta/meta.dart';
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
  final SembastFinder? finder;

  /// Query ref implementation.

  SembastQueryRef(
    this.store,
    // ignore: deprecated_member_use_from_same_package
    SembastFinder? finder,
  ) : finder = finder?.clone();

  @override
  String toString() => '$store $finder)';
}

/// Internal access
@protected
extension SembastQueryRefExtensionPrv<K, V> on QueryRef<K, V> {
  /// Sembast query ref. implementation.
  SembastQueryRef<K, V> get sembastQueryRef => this as SembastQueryRef<K, V>;

  /// Store ref
  StoreRef<K, V> get store => sembastQueryRef.store;
}

/// Common extension
extension SembastQueryRefCommonExtension<K, V> on QueryRef<K, V> {
  /// Finder if any.
  Finder? get finder => sembastQueryRef.finder;
}

/// Query db actions.
extension SembastQueryRefExtension<K, V> on QueryRef<K, V> {
  /// Find multiple records and listen for changes.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<List<RecordSnapshot<K, V>>> onSnapshots(Database database) {
    var db = getDatabase(database);
    // Create the query but don't add it until first result is set
    late QueryListenerController<K, V> ctlr;
    ctlr = db.listener.addQuery(
      this,
      onListen: () async {
        // Add the existing snapshot

        // Read right away to get the content at call time

        // Just filter
        try {
          // Make sure the first read matches the existing content.
          await ctlr.lock.synchronized(() async {
            // Find all matching, ignoring offset/limit but order them
            var allMatching = await sembastQueryRef.store.findImmutableRecords(
              database,
              finder:
                  sembastQueryRef.finder?.cloneWithoutLimits()
                      as SembastFinder?,
            );
            // ignore: unawaited_futures

            // Get the result at query time first
            if (debugListener) {
              // ignore: avoid_print
              print('matching $ctlr: ${allMatching.length} on $this');
            }

            await ctlr.add(allMatching, db.cooperator);
          });
        } catch (error, stackTrace) {
          ctlr.addError(error, stackTrace);
        }
      },
    );
    return ctlr.stream;
  }

  Future<void> _onListen(
    SembastDatabase database,
    QueryRecordsListenerController<K, V> ctlr,
  ) async {
    try {
      // Make sure the first read matches the existing content.
      await ctlr.lock.synchronized(() async {
        // Find all matching, ignoring offset/limit but order them
        var allMatching = await sembastQueryRef.store.findImmutableRecords(
          database,
          finder:
              sembastQueryRef.finder?.cloneWithoutLimits() as SembastFinder?,
        );
        // ignore: unawaited_futures

        // Get the result at query time first
        if (debugListener) {
          // ignore: avoid_print
          print('matching $ctlr: ${allMatching.length} on $this');
        }

        await ctlr.add(allMatching, database.cooperator);
      });
    } catch (error, stackTrace) {
      ctlr.addError(error, stackTrace);
    }
  }

  /// Find multiple records and listen for changes.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<List<K>> onKeys(Database database) {
    var db = getDatabase(database);

    // Create the query but don't add it until first result is set
    late QueryKeysListenerController<K, V> ctlr;
    ctlr = db.listener.addQueryKeys(
      this,
      onListen: () async {
        await _onListen(db, ctlr);
      },
    );
    return ctlr.stream;
  }

  /// Find multiple records.
  ///
  /// Returns an empty array if none found.
  Future<List<RecordSnapshot<K, V>>> getSnapshots(DatabaseClient client) =>
      sembastQueryRef.store.find(client, finder: sembastQueryRef.finder);

  /// Find multiple record keys
  ///
  /// Returns an empty array if none found.
  Future<List<K>> getKeys(DatabaseClient client) =>
      sembastQueryRef.store.findKeys(client, finder: sembastQueryRef.finder);

  /// Find first record matching the query.
  ///
  /// Returns null if none found.
  Future<RecordSnapshot<K, V>?> getSnapshot(DatabaseClient client) =>
      sembastQueryRef.store.findFirst(client, finder: sembastQueryRef.finder);

  /// Find first record key matching the query.
  ///
  /// Returns null if none found.
  Future<K?> getKey(DatabaseClient client) =>
      sembastQueryRef.store.findKey(client, finder: sembastQueryRef.finder);

  /// Find first record (null if none) and listen for changes.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<RecordSnapshot<K, V>?> onSnapshot(Database database) {
    if (sembastQueryRef.finder?.limit != 1) {
      return SembastQueryRef(
        sembastQueryRef.store,
        cloneFinderFindFirst(sembastQueryRef.finder),
      ).onSnapshot(database);
    }
    return onSnapshots(
      database,
    ).map((list) => list.isNotEmpty ? list.first : null);
  }

  /// Find first record key (null if none) and listen for changes.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<K?> onKey(Database database) {
    if (sembastQueryRef.finder?.limit != 1) {
      return SembastQueryRef(
        sembastQueryRef.store,
        cloneFinderFindFirst(sembastQueryRef.finder),
      ).onKey(database);
    }

    /// We know the list is limited to 1 here
    return onKeys(database).map((list) => list.isNotEmpty ? list.first : null);
  }

  /// count records.
  Future<int> count(DatabaseClient client) async =>
      (await getKeys(client)).length;

  /// onCount stream, called when the number of items changes.
  Stream<int> onCount(Database database) =>
      onKeys(database).map((e) => e.length);

  /// Delete records matching the query.
  Future<int> delete(DatabaseClient client) async {
    return store.delete(client, finder: finder);
  }
}

/// Query db actions. synchronous access.
extension SembastQueryRefSyncExtension<K, V> on QueryRef<K, V> {
  /// Find multiple records. Synchronous version.
  ///
  /// Returns an empty array if none found.
  List<RecordSnapshot<K, V>> getSnapshotsSync(DatabaseClient client) =>
      sembastQueryRef.store.findSync(client, finder: sembastQueryRef.finder);

  /// Find multiple record keys. Synchronous version.
  ///
  /// Returns an empty array if none found.
  List<K> getKeysSync(DatabaseClient client) => sembastQueryRef.store
      .findKeysSync(client, finder: sembastQueryRef.finder);

  /// Find first record matching the query. Synchrnous version.
  ///
  /// Returns null if none found.
  RecordSnapshot<K, V>? getSnapshotSync(DatabaseClient client) =>
      sembastQueryRef.store.findFirstSync(
        client,
        finder: sembastQueryRef.finder,
      );

  /// Find first record key matching the query. Synchrnous version.
  ///
  /// Returns null if none found.
  K? getKeySync(DatabaseClient client) =>
      sembastQueryRef.store.findKeySync(client, finder: sembastQueryRef.finder);

  /// count records. Synchronous version.
  int countSync(DatabaseClient client) => getKeysSync(client).length;

  /// Find first record (null if none) and listen for changes.
  ///
  /// First emit happens synchronously.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<RecordSnapshot<K, V>?> onSnapshotSync(Database database) {
    if (sembastQueryRef.finder?.limit != 1) {
      return SembastQueryRef(
        sembastQueryRef.store,
        cloneFinderFindFirst(sembastQueryRef.finder),
      ).onSnapshotSync(database);
    }
    return onSnapshotsSync(
      database,
    ).map((list) => list.isNotEmpty ? list.first : null);
  }

  /// Find first record key (null if none) and listen for changes.
  ///
  /// First emit happens synchronously.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<K?> onKeySync(Database database) {
    if (sembastQueryRef.finder?.limit != 1) {
      return SembastQueryRef(
        sembastQueryRef.store,
        cloneFinderFindFirst(sembastQueryRef.finder),
      ).onKeySync(database);
    }
    return onKeysSync(
      database,
    ).map((list) => list.isNotEmpty ? list.first : null);
  }

  /// Find multiple records and listen for changes.
  ///
  /// First emit happens synchronously.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<List<RecordSnapshot<K, V>>> onSnapshotsSync(Database database) {
    var db = getDatabase(database);
    // Create the query but don't add it until first result is set
    late QueryListenerController<K, V> ctlr;
    ctlr = db.listener.addQuery(
      this,
      onListen: () async {
        // Add the existing snapshot

        // Read right away to get the content at call time

        // Just filter
        try {
          await ctlr.lock.synchronized(() async {
            // Find all matching, ignoring offset/limit but order them
            var allMatching = sembastQueryRef.store.findImmutableRecordsSync(
              database,
              finder:
                  sembastQueryRef.finder?.cloneWithoutLimits()
                      as SembastFinder?,
            );
            // ignore: unawaited_futures

            // Get the result at query time first
            if (debugListener) {
              // ignore: avoid_print
              print('matching $ctlr: ${allMatching.length} on $this');
            }

            await ctlr.add(allMatching, db.cooperator);
          });
        } catch (error, stackTrace) {
          ctlr.addError(error, stackTrace);
        }
      },
    );
    return ctlr.stream;
  }

  Future<void> _onListenSync(
    SembastDatabase database,
    QueryRecordsListenerController<K, V> ctlr,
  ) async {
    try {
      // Make sure the first read matches the existing content.
      await ctlr.lock.synchronized(() async {
        // Find all matching, ignoring offset/limit but order them
        var allMatching = sembastQueryRef.store.findImmutableRecordsSync(
          database,
          finder:
              sembastQueryRef.finder?.cloneWithoutLimits() as SembastFinder?,
        );
        // ignore: unawaited_futures

        // Get the result at query time first
        if (debugListener) {
          // ignore: avoid_print
          print('matching $ctlr: ${allMatching.length} on $this');
        }

        await ctlr.add(allMatching, database.cooperator);
      });
    } catch (error, stackTrace) {
      ctlr.addError(error, stackTrace);
    }
  }

  /// Find multiple records and listen for changes.
  ///
  /// First emit happens synchronously.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<List<K>> onKeysSync(Database database) {
    var db = getDatabase(database);
    // Create the query but don't add it until first result is set
    late QueryKeysListenerController<K, V> ctlr;
    ctlr = db.listener.addQueryKeys(
      this,
      onListen: () async {
        await _onListenSync(db, ctlr);
      },
    );
    return ctlr.stream;
  }

  /// onCount stream, called when the number of items changes.
  ///
  /// first emit happens synchronously.
  Stream<int> onCountSync(Database database) =>
      onKeysSync(database).map((e) => e.length);
}

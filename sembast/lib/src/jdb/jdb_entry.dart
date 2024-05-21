import 'package:meta/meta.dart';
import 'package:sembast/src/env_utils.dart';
import 'package:sembast/src/import_common.dart';
import 'package:sembast/src/record_impl.dart';

/// Journal entry database.
class JdbInfoEntry {
  /// Jdb entry id.
  String? id;

  /// Jdb value
  Object? value;

  @override
  String toString() => '[$id] $value';

  /// Debug map.
  Map<String, Object?> exportToMap() {
    var map = <String, Object?>{
      'id': id,
      if (value != null) 'value': value,
    };
    return map;
  }
}

/// Journal entry database.
abstract class JdbEntry {
  /// Jdb entry id.
  int get id;

  /// Jdb record
  RecordRef<Key?, Value?> get record;

  /// True if deleted
  bool get deleted;

  @override
  String toString() => '[$id] $record ${deleted ? ' (deleted)' : ' $value'}';

  /// Jdb value
  Value? get value;

  /// Jdb value
  Value? get valueOrNull;
}

/// Read entry
class JdbReadEntry extends JdbEntry {
  @override
  late int id;

  @override
  late RecordRef<Key?, Value?> record;

  @override
  late Value value;

  @override
  Value? get valueOrNull => value;

  @override
  late bool deleted;
}

/// Write entry.
abstract class JdbWriteEntry extends JdbEntry {
  /// Write entry, typically from a txn record.
  factory JdbWriteEntry({required TxnRecord txnRecord}) =>
      JdbWriteEntryImpl(txnRecord: txnRecord);

  set revision(int? revision);

  /// Not null.
  @override
  Value get value;
}

/// Write entry base iplementation.
abstract class JdbWriteEntryBase implements JdbWriteEntry {
  /// Value. Should not be overriden.
  @override
  Value get value {
    try {
      return valueOrNull as Value;
    } catch (e) {
      if (isDebug) {
        // ignore: avoid_print
        print('error $e accessing value for $this');
      }
      if (deleted) {
        throw StateError('deleted accessing value for $this');
      } else {
        throw StateError('error $e accessing value for $this');
      }
    }
  }
}

/// Write entry.
class JdbWriteEntryImpl extends JdbWriteEntryBase {
  @override
  late int id;

  /// Write entry, typically from a txn record.
  JdbWriteEntryImpl({required this.txnRecord});

  /// Record
  TxnRecord? txnRecord;

  /// record Ref.
  @override
  RecordRef<Key?, Value?> get record => txnRecord!.ref;

  /// Used internally to check for corruption first when importing.
  @override
  Object? get valueOrNull => _txnRecordValueOrNull;

  Object? get _txnRecordValueOrNull =>
      (txnRecord?.deleted ?? true) ? null : txnRecord?.record.value;

  @override
  String toString() {
    // print if error is id not initialized, handle it...
    try {
      return '[$id] $record $valueOrNull';
    } catch (e) {
      return 'Invalid entry $valueOrNull';
    }
  }

  @override
  bool get deleted => txnRecord!.deleted;

  @override
  set revision(int? revision) {
    txnRecord!.record.revision = revision;
  }
}

/// Raw entry that allow creating entry for testing
@visibleForTesting
class JdbRawWriteEntry extends JdbWriteEntryBase {
  @override
  late final Value? valueOrNull;
  @override
  final bool deleted;
  @override
  final RecordRef<Key?, Value?> record;

  /// The id can be set later

  @override
  int get id => _id!;
  set id(int id) => _id = id;

  int? _id;

  /// testing only
  int? get idOrNull => _id;

  /// Raw entry.
  JdbRawWriteEntry(
      {int? id,
      required Value? value,
      this.deleted = false,
      required this.record,
      this.revision}) {
    valueOrNull = value;
    _id = id;
  }

  /// The revision can be set later
  @override
  int? revision;

  @override
  String toString() =>
      '$_id, ${record.store.name}/${record.key} ($revision) ${deleted ? 'deleted' : ''}';
}

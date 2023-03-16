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
class JdbWriteEntry extends JdbEntry {
  @override
  late int id;

  /// Write entry, typically from a txn record.
  JdbWriteEntry({required this.txnRecord});

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

  /// Value. Should not be overriden.
  @override
  Value get value {
    try {
      return valueOrNull as Value;
    } catch (e) {
      print('error $e accessing value for $this');
      if (deleted) {
        throw StateError('deleted accessing value for $this');
      } else {
        throw StateError('error $e accessing value for $this');
      }
    }
  }

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
}

/// Raw entry.
class JdbRawWriteEntry extends JdbWriteEntry {
  @override
  late final Value? valueOrNull;
  @override
  final bool deleted;
  @override
  final RecordRef<Key?, Value?> record;

  /// Raw entry.
  JdbRawWriteEntry(
      {required Value? value, required this.deleted, required this.record})
      : super(txnRecord: null) {
    valueOrNull = value;
  }
}

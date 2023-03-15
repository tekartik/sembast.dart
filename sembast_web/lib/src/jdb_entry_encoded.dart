import 'package:sembast_web/src/jdb_import.dart' as jdb;

/// Encoded write entry. prepared for being added in a transaction.
class JdbWriteEntryEncoded {
  final jdb.JdbWriteEntry _src;

  /// Encoded value (encoded only if a codec is specified, otherwise the raw
  /// encodable is set). Null for deleted.
  final Object? valueEncoded;

  /// Encoded write entry.
  JdbWriteEntryEncoded(this._src, this.valueEncoded);

  /// Store name.
  String get storeName => _src.record.store.name;

  /// Record key.
  Object get recordKey => _src.record.key!;

  /// True if deleted (valueEncoded not set).
  bool get deleted => _src.deleted;

  /// Set updated revision on the source.
  set revision(int revision) {
    _src.txnRecord?.record.revision = revision;
  }
}

/// Encoded read entry from cursor. decoded later.
class JdbReadEntryEncoded {
  /// The entry id.
  final int id;

  /// Store name.
  final String storeName;

  /// Record key.
  final Object recordKey;

  /// true if deleted.
  final bool deleted;

  /// Encoded value (encoded only if a codec is specified, otherwise the raw
  /// encodable is set). Null for deleted.
  final Object? valueEncoded;

  /// An entry is valid deleted or valid value.
  bool get isValid => deleted || valueEncoded != null;

  /// Encoded read entry from cursor. decoded later.
  JdbReadEntryEncoded(
      this.id, this.storeName, this.recordKey, this.deleted, this.valueEncoded);
}

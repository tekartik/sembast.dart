import 'package:sembast/src/api/protected/jdb.dart' as jdb;
import 'package:sembast/src/api/protected/type.dart';

import 'package:sembast/src/api/record_ref.dart';

/// Encoded entry shared.
abstract class JdbEntryEncoded {
  /// True if deleted.
  bool get deleted;

  /// Encoded value (encoded only if a codec is specified, otherwise the raw
  /// encodable is set). Null for deleted.
  Object? get valueEncoded;
}

/// Common helper.
extension JdbEntryEncodedExtension on JdbEntryEncoded {
  /// An entry is valid deleted or valid value.
  bool get isValid => deleted || valueEncoded != null;
}

/// Encoded write entry. prepared for being added in a transaction.
class JdbWriteEntryEncoded implements JdbEntryEncoded {
  final jdb.JdbWriteEntry _src;

  /// Encoded value (encoded only if a codec is specified, otherwise the raw
  /// encodable is set). Null for deleted.
  @override
  final Object? valueEncoded;

  /// Encoded write entry.
  JdbWriteEntryEncoded(this._src, this.valueEncoded);

  /// Store name.
  String get storeName => record.store.name;

  /// Record key.
  Object get recordKey => record.key!;

  /// True if deleted (valueEncoded not set).
  @override
  bool get deleted => _src.deleted;

  /// Record access.
  RecordRef<Key?, Value?> get record => _src.record;

  /// Set updated revision on the source.
  set revision(int revision) {
    _src.revision = revision;
  }
}

/// Encoded read entry from cursor/transaction. decoded later.
class JdbReadEntryEncoded implements JdbEntryEncoded {
  /// The entry id.
  final int id;

  /// Store name.
  final String storeName;

  /// Record key.
  final Object recordKey;

  /// true if deleted.
  @override
  final bool deleted;

  /// Encoded value (encoded only if a codec is specified, otherwise the raw
  /// encodable is set). Null for deleted.
  @override
  final Object? valueEncoded;

  /// Encoded read entry from cursor. decoded later.
  JdbReadEntryEncoded(
      this.id, this.storeName, this.recordKey, this.deleted, this.valueEncoded);
}

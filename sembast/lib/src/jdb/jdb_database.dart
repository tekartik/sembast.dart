import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sembast/src/api/protected/codec.dart';
import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast/src/api/protected/type.dart';
import 'package:sembast/src/api/store_ref.dart';

/// Jdb.
abstract class JdbDatabase {
  /// Codec to use.
  DatabaseOpenOptions get openOptions;

  /// Get revision update from the database
  Stream<int> get revisionUpdate;

  /// Get info.
  Future<JdbInfoEntry?> getInfoEntry(String id);

  /// Set info.
  Future setInfoEntry(JdbInfoEntry entry);

  /// Add entries in the database.
  Future<void> addEntries(List<JdbWriteEntry> entries);

  /// Read all entries.
  Stream<JdbEntry> get entries;

  /// Read delta entries since current revision
  Stream<JdbEntry> entriesAfterRevision(int revision);

  /// Read revision stored
  Future<int> getRevision();

  /// Generate unique int keys.
  Future<List<int>> generateUniqueIntKeys(String store, int count);

  /// Generate unique String keys.
  Future<List<String>> generateUniqueStringKeys(String store, int count);

  /// Close the database
  void close();

  /// Safe transaction write of multiple infos.
  Future<StorageJdbWriteResult> writeIfRevision(StorageJdbWriteQuery query);

  /// Read all context (re-open if needed). Test only.
  @visibleForTesting
  Future<Map<String, Object?>> exportToMap();

  /// Compact the database
  Future compact();

  /// Delta min revision
  Future<int> getDeltaMinRevision();

  /// Clear all data (testing only)
  Future clearAll();
}

/// Internal extension helper. protected.
extension JdbDatabaseInternalExt on JdbDatabase {
  /// True if it has async codec.
  bool get hasAsyncCodec => contentCodec?.isAsyncCodec ?? false;

  /// Sembast codec to use.
  SembastCodec? get sembastCodec => openOptions.codec;

  /// Codec used, null by default (json)
  Codec<Object?, String>? get contentCodec =>
      sembastCodecContentCodecOrNull(sembastCodec);

  JdbReadEntry _readEntryFromReadEntryEncoded(
      JdbReadEntryEncoded encoded, Object? value) {
    var id = encoded.id;
    var store = StoreRef<Key?, Value?>(encoded.storeName);
    var record = store.record(encoded.recordKey);
    var deleted = encoded.deleted;
    var entry = JdbReadEntry()
      ..id = id
      ..record = record
      ..deleted = deleted;
    if (!deleted) {
      entry.value = value!;
    }
    return entry;
  }

  /// Decode a read entry (sync codec)
  JdbReadEntry decodeReadEntrySync(JdbReadEntryEncoded entryEncoded) {
    Object? value;
    if (!entryEncoded.deleted) {
      value = entryEncoded.valueEncoded;

      /// Optionally decode with content codec.
      if (contentCodec != null && value is String) {
        value = contentCodec!.decodeContentSync<Object>(value);
      }
      if (value != null) {
        /// Deserialize unsupported types (Blob, Timestamp)
        value = sembastCodecFromJsonEncodable(sembastCodec, value);
      }
    }
    return _readEntryFromReadEntryEncoded(entryEncoded, value);
  }

  /// Decode a read entry (async codec)
  Future<JdbReadEntry> decodeReadEntryAsync(
      JdbReadEntryEncoded entryEncoded) async {
    Object? value;
    if (!entryEncoded.deleted) {
      value = entryEncoded.valueEncoded;

      /// Optionally decode with content codec.
      if (contentCodec != null && value is String) {
        value = await contentCodec!.decodeContentAsync<Object>(value);
      }
      if (value != null) {
        /// Deserialize unsupported types (Blob, Timestamp)
        value = sembastCodecFromJsonEncodable(sembastCodec, value);
      }
    }
    return _readEntryFromReadEntryEncoded(entryEncoded, value);
  }

  /// Encode entries, handling async codec if needed.
  Future<List<JdbWriteEntryEncoded>> encodeEntries(
      Iterable<JdbWriteEntry> entries) async {
    var encodedList = <JdbWriteEntryEncoded>[];
    var jsonEncodableCodec = sembastCodecJsonEncodableCodec(sembastCodec);
    final hasAsyncCodec = this.hasAsyncCodec;
    var contentCodec = this.contentCodec;
    for (var entry in entries) {
      Object? valueEncoded;
      if (!entry.deleted) {
        var value = entry.valueOrNull;
        if (value == null) {
          print('Invalid entry $entry');
          continue;
        }

        var encodableValue = jsonEncodableCodec.encode(value);

        /// If a codec is specified, write the value as a string instead.
        if (contentCodec != null) {
          if (hasAsyncCodec) {
            valueEncoded =
                await contentCodec.encodeContentAsync(encodableValue);
          } else {
            valueEncoded = contentCodec.encodeContentSync(encodableValue);
          }
        } else {
          valueEncoded = encodableValue;
        }
      }
      encodedList.add(JdbWriteEntryEncoded(entry, valueEncoded));
    }
    return encodedList;
  }
}

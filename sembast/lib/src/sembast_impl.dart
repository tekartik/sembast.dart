import 'package:sembast/src/api/sembast.dart';

/// The database version
const String dbVersionKey = 'version';

/// The internal version.
const String dbDembastVersionKey = 'sembast';

/// The codec key.
const String dbDembastCodecSignatureKey = 'codec';

/// The record key field.
const String dbRecordKey = 'key';

/// The record store field.
const String dbStoreNameKey = 'store';

/// The record value field.
const String dbRecordValueKey =
    'value'; // only for simple type where the key is not a string
/// The record deleted field.
const String dbRecordDeletedKey = 'deleted'; // boolean

/// Main store.
const String dbMainStore = '_main'; // main store name;

/// Main store reference.
final mainStoreRef = StoreRef<Object?, Object?>(dbMainStore);

/// Jdb revision.
const String jdbRevisionKey = 'revision';

/// Jdb delta min revision.
const String jdbDeltaMinRevisionKey = 'deltaMinRevision';

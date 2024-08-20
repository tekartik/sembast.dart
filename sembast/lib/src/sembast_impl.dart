import 'import_common.dart';
import 'store_ref_impl.dart';

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

/// Main store reference. to deprecate since it is not typed
StoreRef<Key, Value> mainStoreRef = SembastStoreRef<Key, Value>(dbMainStore);

/// Main store reference, key as int, value untyped
StoreRef<int, Value> intMainStoreRef = SembastStoreRef<int, Value>(dbMainStore);

/// Main store reference, key as String, value untyped
StoreRef<String, Value> stringMainStoreRef =
    SembastStoreRef<String, Value>(dbMainStore);

/// Jdb revision.
const String jdbRevisionKey = 'revision';

/// Jdb delta min revision.
const String jdbDeltaMinRevisionKey = 'deltaMinRevision';

import 'package:sembast/src/sembast_impl.dart';

/// Meta information
class Meta {
  /// the database version.
  int? version;

  /// Our internal version.
  int? sembastVersion = 1;

  /// Encoded {'signature': signature'} using the codec itself!
  String? codecSignature;

  /// Create from json.
  Meta.fromMap(Map map) {
    version = map[dbVersionKey] as int?;
    sembastVersion = map[dbDembastVersionKey] as int?;
    codecSignature = map[dbDembastCodecSignatureKey] as String?;
  }

  /// map matches meta definition?
  static bool isMapMeta(Map? map) {
    return map != null && map[dbVersionKey] != null;
  }

  /// Meta information.
  Meta({required this.version, this.codecSignature});

  /// To json.
  Map<String, Object?> toMap() {
    var map = <String, Object?>{
      dbVersionKey: version,
      dbDembastVersionKey: sembastVersion,
    };
    if (codecSignature != null) {
      map[dbDembastCodecSignatureKey] = codecSignature;
    }
    return map;
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

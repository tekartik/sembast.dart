import 'package:meta/meta.dart';
import 'package:sembast/src/sembast_impl.dart';

class Meta {
  int version;
  int sembastVersion = 1;

  /// Encoded {'signature': signature'} using the codec itself!
  String codecSignature;

  Meta.fromMap(Map map) {
    version = map[dbVersionKey] as int;
    sembastVersion = map[dbDembastVersionKey] as int;
    codecSignature = map[dbDembastCodecSignatureKey] as String;
  }

  static bool isMapMeta(Map map) {
    return map != null && map[dbVersionKey] != null;
  }

  Meta({@required this.version, this.codecSignature});

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      dbVersionKey: version,
      dbDembastVersionKey: sembastVersion
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

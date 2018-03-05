import 'package:sembast/src/sembast_impl.dart';

class Meta {
  int version;
  int sembastVersion = 1;

  Meta.fromMap(Map map) {
    version = map[dbVersionKey] as int;
    sembastVersion = map[dbDembastVersionKey] as int;
  }

  static bool isMapMeta(Map map) {
    return map[dbVersionKey] != null;
  }

  Meta(this.version);

  Map toMap() {
    var map = {dbVersionKey: version, dbDembastVersionKey: sembastVersion};
    return map;
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

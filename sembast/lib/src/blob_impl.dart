import 'dart:convert';
import 'dart:typed_data';

/// Sembast blob definition
class Blob implements Comparable<Blob> {
  /// Blob bytes. null not supported.
  final Uint8List bytes;

  /// Blob creation.
  Blob(this.bytes);

  /// Blob creation from int list.
  Blob.fromList(List<int> list) : bytes = Uint8List.fromList(list);

  /// Blob creation from base64.
  static Blob fromBase64(String base64) => Blob(base64Decode(base64));

  /// Blob length.
  int get length => bytes.length;

  /// The byte at a given index.
  int operator [](int index) => bytes[index];

  @override
  int get hashCode => bytes.length;

  @override
  bool operator ==(other) =>
      other is Blob &&
      () {
        if (other.length != length) {
          return false;
        }
        for (var i = 0; i < length; i++) {
          if (this[i] != other[i]) {
            return false;
          }
        }
        return true;
      }();

  @override
  String toString() => 'Blob(len: ${bytes.length})';

  @override
  int compareTo(Blob other) {
    for (var i = 0; i < length; i++) {
      if (i < other.length) {
        var cmp = this[i] - other[i];
        if (cmp != 0) {
          return cmp;
        }
      } else {
        // this is after
        return 1;
      }
    }
    return length - other.length;
  }

  /// Base64 encoding.
  String toBase64() => base64Encode(bytes);
}

@TestOn('vm') // Temp
library sembast_test.encrypt_codec_test;

import 'package:sembast/sembast.dart';
import 'package:sembast_test/encrypt_codec.dart';
import 'package:test/test.dart';

void main() {
  group('encrypt_codec', () {
    group('map', () {
      void _testCodec(SembastCodec codec) {
        var encrypted = codec.codec!.encode({'test': 1});
        var encrypted2 = codec.codec!.encode({'test': 1});

        expect(encrypted.length, 28);
        expect(encrypted2.length, 28);
        // They should not be equals!
        expect(encrypted, isNot(encrypted2));
        expect(codec.codec!.decode(encrypted), {'test': 1});
        expect(codec.codec!.decode(encrypted2), {'test': 1});
      }

      test('codec', () {
        _testCodec(getEncryptSembastCodec(password: 'test'));
        _testCodec(getEncryptSembastCodec(password: ''));
        _testCodec(getEncryptSembastCodec(
            password:
                'veryveryveryverylongpasswordveryveryveryverylongpasswordveryveryveryverylongpasswordveryveryveryverylongpassword'));
      });
      test('decode', () {
        dynamic testDecode(String encrypted) {
          expect(
              getEncryptSembastCodec(password: 'test').codec!.decode(encrypted),
              {'test': 1});
        }

        testDecode('57PnR5KpJv8=sKlpSc7eSt1F+w==');
        testDecode('Yj6M09ZJZNI=FZ/6SmEhirNYiQ==');
      });
    });
    test('non_map', () {
      var codec = getEncryptSembastCodec(password: 'test');
      var encrypted = codec.codec!.encode(1);
      print(encrypted);
      expect(codec.codec!.decode(encrypted), 1);
      expect(codec.codec!.decode('/rrxTMsFHFI=VA=='), 1);
      expect(codec.codec!.decode('QpInbufcf6w=Ag=='), 1);
    });
  });
}

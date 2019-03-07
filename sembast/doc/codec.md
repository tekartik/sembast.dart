# Codec and encryption

Sembast supports using a user-defined codec to encode/decode data when read/written to disk.
It provides a way to support encryption. Encryption itself is not part of sembast but an example of an xxtea based
encryption is provided in the [test folder](https://github.com/tekartik/sembast.dart/blob/master/sembast/test/xxtea_codec.dart).

```dart
// Initialize the encryption codec with a user password
var codec = getXXTeaSembastCodec(password: '[your_user_password]');

// Open the database with the codec
Database db = await factory.openDatabase(dbPath, codec: codec);

// ...your database is ready to use as encrypted

```

If you create multiple records, the content of the database will look like this where each record is encrypted using xxtea:

```
{"version":1,"sembast":1,"codec":"cEu6/oC1MpxjH2CbI/UmytCkQkW0V4elsiCbDg=="}
AxWM18uV0LCHVz+t+JIxdVHAg86Ahhdf1Okdug==
I2P31s9Q4aAb2pbyzDcHEfbn/UqUwgAd6Xb8ngMGWgevjamZSyUEX7cXvO9+L7gZBqR6TIbYkcXOSvfURnfLrUI6RPY=
8iEB8c4rCzJFrdy9zHnHbcq2UlcsPViRvR7X5jQeybI=
6K0vstc3HOOqJ9oNfqorBHl2OUaa9zumWivnIM0CJ29hXNBZvWCRQQktmIZUUv1unNeAueB8nLcLiaxxBWTKD4YCvf01qfiY6rO9KvMg9J4=
```

The header of the database will contain a signature encoded by the codec itself so that a database cannot be opened
if the password is wrong.

Any other custom encryption/codec can be used as long as you provide a way to encode/decode a Map to/from a String. If xxtea fits
your need. Simply add a dependency on `xxtea` and copy [this file](https://github.com/tekartik/sembast.dart/blob/master/sembast/test/xxtea_codec.dart)
to your project.

* More information on [xxtea on wikipedia](https://en.wikipedia.org/wiki/XXTEA)
* The xxtea implementation used from pub: https://pub.dartlang.org/packages/xxtea
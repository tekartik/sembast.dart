# Codec and encryption

Sembast supports using a user-defined codec to encode/decode data when read/written to disk.
It provides a way to support encryption. Encryption itself is not part of sembast but an example of a simple
encryption algorithm (Salsa20 and SHA256 used from external packages) 
is provided in the [test folder](https://github.com/tekartik/sembast.dart/blob/master/sembast_test/lib/encrypt_codec.dart).

In `pubspec.yaml`:
```yaml
dependencies:
  # Dependencies for encryption example
  encrypt: '>=3.1.0'
  crypto: '>=2.0.6'

```
```dart
// Initialize the encryption codec with a user password
var codec = getEncryptSembastCodec(password: '[your_user_password]');

// Open the database with the codec
Database db = await factory.openDatabase(dbPath, codec: codec);

// ...your database is ready to use

```

If you create multiple records, the content of the database will look like this where each record is encrypted:

```
"version":1,"sembast":1,"codec":"ZddmpxjrwUgJk7YnlC0lDhz7S2Iqcp8="}
Zdd+qwanmg1Qw6VkwnolQkWrRnctJMD9
Zdd+qwanmg5Qw6VkwnolQkWrQX0zNcLsqMobWlZppdFrayfLvTE2Q129UKIWbkdxrezXtzmQGajd+39xMhMe5w==
Zdd+qwanmg9Qw6VkwnolQkWrQXoxIpaiug==
Zdd+qwanmghQw6VkwnolQkWrQX0zNcL2otYFH0gmudNtdnXd+CYxUE29U6MbdkdypevetyCeAKjd7Xl1PwIc9y0ovYrPnatrpqeL
```

The header of the database will contain a signature encoded by the codec itself so that a database cannot be opened
if the password is wrong.

Any other custom encryption/codec can be used as long as you provide a way to encode/decode a json encodable 
object (Map, List, num, String, bool and num) to/from a single line String.

### Create an asynchronous codec

The codec must be able to handle the conversion of a json encodable data to a single line string. (i.e. json being one).
If your codec requires calling a plugin or an asynchronous operation you have to create an 
asynchronous codec. One solution is to subclass `AsyncContentCodecBase` (which is a `Codec<Object?, String>` but with
the synchronous encoding/decoding disabled) where you just have to implement:
- `decodeAsync`
- `encodeAsync`

```dart

/// My simple asynchronous codec.
class MyAsyncCodec extends AsyncContentCodecBase {
  String _reverseString(String text) => text.split('').reversed.join();

  @override
  Future<Object?> decodeAsync(String encoded) async {
    // Simple demo, just reverse the json asynchronously.
    return jsonDecode(_reverseString(encoded));
  }

  @override
  Future<String> encodeAsync(Object? input) async {
    // Simple demo, just reverse the json asynchronously.
    return _reverseString(jsonEncode(input));
  }
}
```

You have to specify a unique signature (not private) when opening the database with an sync codec:

```dart
// Open the database
var db = await factory.openDatabase('my_encoded_db.db',
    codec: SembastCodec(signature: 'my_codec', codec: MyAsyncCodec()));
```
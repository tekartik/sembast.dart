import 'dart:convert';

import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

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

void main() {
  test('async_codec_test', () async {
    // In memory factory for unit test
    var factory = databaseFactoryMemory;

    // Define the store
    var store = StoreRef<String, String>.main();
    // Define the record
    var record = store.record('my_key');

    // Open the database
    var db = await factory.openDatabase('my_encoded_db.db',
        codec: SembastCodec(signature: 'my_codec', codec: MyAsyncCodec()));

    // Write a record
    await record.put(db, 'my_value');

    // Verify record content.
    expect(await record.get(db), 'my_value');

    // Close the database
    await db.close();
  });
}

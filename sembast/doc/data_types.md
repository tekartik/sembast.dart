# Sembast data types

Supported types depends on JSON supported types.

## Keys

Supported key types are:
- int (default with autoincrement when no key are passed)
- String (supports generation of unique key)

## Values

Supported value types are:
- `String`
- `num` (`int` and `double`)
- `Map<String, Object?>` (`Object?` being any of the supported types)
- `List<Object?>` (`Object?` being any of the supported types, `Iterable` is not a supported types, use to `toList()` to convert any iterable)
- `bool`
- `null` (the root record value itself cannot be null though)
- `Blob` (custom type)
- `Timestamp` (custom type)

Map must be of type `Map<String, Object?>`.

The root document data cannot be `null` (but null are accepted for map values, i.e. `{"test": null}`, `[1, null, "test"]` is ok but `null` is not)

## Keys and map keys

In general prefer ASCII keys.

Dots (`.`) are treated as separator for values and queries. To allow for such key during update, query filter and sort
orders, you can escape them using `FieldKey.escape`. It uses backticks, if your key is already surrounded by backticks
you should also escape it. 

```dart
var value = record['path.sub'];
// means value at {'path': {'sub': value}}
value = record[FieldKey.escape('path.sub')];
// means value at {'path.sub': value}
```

## DateTime

`DateTime` is not a supported type. Similarly to firestore, it should be stored as a `Timestamp` object.

Timestamp can easily be convert `toDateTime()` and `fromDateTime(dateTime)`.

## Blob

`Uint8List` is not a supported type. It will be stored as `List<int>`. You should wrap your bytes in a `Blob` object. 
Big blob should/could also be stored in a dedicated file (and only keep a reference to it in sembast).
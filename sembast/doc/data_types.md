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
- `Map<String, Object?>`
- `List<Object?>` (`Iterable` is not a supported types, use to `List()` to convert any iterable)
- `bool`
- `null` (the record value itself cannot be null)
- `Blob` (custom type)
- `Timestamp` (custom type)

Using the Store API, Map must be of type `Map<String, Object?>`.

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
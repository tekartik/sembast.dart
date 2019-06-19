# Sembast data types

Supported types depends on JSON supported types.

## Keys

Supported key types are:
- int (default with autoincrement when no key are passed)
- String (supports generation of unique key)
- double (not recommended)


## Values

Supported value types are:
- String.
- num (int and double)
- Map
- List
- bool
- `null`

Using the Store API, Map must be of type `Map<String, dynamic>`.

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

`DateTime` is not a supported type. Personally I store them as 
int (millisSinceEpoch) for easy sorting and queries or string (iso8601)

## Blob

`Uint8List` is not a supported type. It will be stored as `List<int>`. You can also encode it as base64 and save it
as a `String`. Big blob could also be stored in a dedicated file.
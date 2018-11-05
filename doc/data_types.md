# Sembast data types

Supported types depends on JSON supported types.

## Keys

Supported key types are:
- int (default with autoincrement when no key are passed)
- String
- double

## Values

Supported value types are:
- String.
- num (int and double)
- Map
- List
- bool
- `null`

## DateTime

`DateTime` is not a supported SQLite type. Personally I store them as 
int (millisSinceEpoch) for easy sorting and queries or string (iso8601)
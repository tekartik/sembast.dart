import 'dart:collection';

/// True if the value is an array or map.
@Deprecated('unused')
bool isValueMutable(dynamic value) {
  return value is Map || value is Iterable;
}

/// Make a value immutable.
Object immutableValue(Object? value) => immutableValueOrNull(value)!;

/// Make a value immutable.
Object? immutableValueOrNull(Object? value) {
  if (value is Map) {
    return ImmutableMap<String, Object?>(value);
  } else if (value is Iterable) {
    return ImmutableList<Object?>(value);
  }
  return value;
}

/// Immutable list.
class ImmutableList<E> extends ListBase<E> {
  final List<E> _list;

  @override
  int get length => _list.length;

  /// Immutable list.
  ImmutableList(Iterable<E> list) : _list = list.toList(growable: false);

  @override
  E operator [](int index) => immutableValueOrNull(_list[index]) as E;

  @override
  void operator []=(int index, value) => throw StateError('read only');

  @override
  set length(int newLength) => throw StateError('read only');
}

/// Immutable map.
class ImmutableMap<K, V> extends MapBase<K, V> {
  final Map<K, V> _map;

  /// raw map.
  Map<K, V> get rawMap => _map;

  /// Immutable map.
  ImmutableMap(Map map) : _map = map.cast<K, V>();

  @override
  V? operator [](Object? key) => immutableValueOrNull(_map[key as K]) as V?;

  @override
  void operator []=(K key, V value) => throw StateError('read only');

  @override
  void clear() => throw StateError('read only');

  @override
  Iterable<K> get keys => _map.keys;

  @override
  V remove(Object? key) => throw StateError('read only');
}

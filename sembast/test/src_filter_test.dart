library sembast.src_filter_test;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:sembast/src/api/v2/sembast.dart';
import 'package:sembast/src/filter_impl.dart' show filterMatchesRecord;

import 'test_common.dart';

var store = StoreRef.main();
var record = store.record(1);

RecordSnapshot snapshot(dynamic value) => record.snapshot(value);

bool _match(Filter filter, dynamic value) {
  return filterMatchesRecord(filter, snapshot(value));
}

void main() {
  group('src_filter_test', () {
    test('equals', () {
      var filter = Filter.equals('test', 1);
      expect(_match(filter, {'test': 1}), isTrue);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {'test': {}}), isFalse);
      expect(_match(filter, {'test': []}), isFalse);
      expect(
          _match(filter, {
            'test': [1]
          }),
          isFalse);
      expect(_match(filter, {'no_test': null}), isFalse);
      expect(_match(filter, {}), isFalse);
      expect(_match(filter, null), isFalse);
      expect(_match(filter, 'test'), isFalse);
      expect(_match(filter, []), isFalse);

      filter = Filter.equals('test', 1, anyInList: true);
      expect(
          _match(filter, {
            'test': [1]
          }),
          isTrue);
      expect(
          _match(filter, {
            'test': ['no', 1, true]
          }),
          isTrue);
      expect(_match(filter, {'test': {}}), isFalse);
      expect(_match(filter, {'test': 1}), isFalse);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {'test': []}), isFalse);
      expect(_match(filter, {'no_test': null}), isFalse);
      expect(_match(filter, {}), isFalse);
      expect(_match(filter, null), isFalse);
      expect(_match(filter, 'test'), isFalse);
      expect(_match(filter, []), isFalse);
    });

    test('sub.field', () {
      var filter = Filter.equals('sub.field', 1);
      expect(_match(filter, {'sub.field': 1}), isFalse);
      expect(
          _match(filter, {
            'sub': {'field': 1}
          }),
          isTrue);
    });
    test('field_with_dot', () {
      var filter = Filter.equals(FieldKey.escape('sub.field'), 1);
      expect(_match(filter, {'sub.field': 1}), isTrue);
      expect(
          _match(filter, {
            'sub': {'field': 1}
          }),
          isFalse);
    });

    test('greaterThanOrEguals', () {
      var filter = Filter.greaterThanOrEquals('test', 1);
      expect(_match(filter, {'test': 1}), isTrue);
      expect(_match(filter, {'test': 2}), isTrue);
      expect(_match(filter, {'test': 0}), isFalse);
      expect(_match(filter, {}), isFalse);
    });

    test('greaterThan', () {
      var filter = Filter.greaterThan('test', 1);
      expect(_match(filter, {'test': 1}), isFalse);
      expect(_match(filter, {'test': 2}), isTrue);
      expect(_match(filter, {'test': 0}), isFalse);
      expect(_match(filter, {}), isFalse);
    });

    test('or', () {
      var filter =
          Filter.or([Filter.equals('test', 1), Filter.equals('test', 2)]);
      expect(_match(filter, {'test': 1}), isTrue);
      expect(_match(filter, {'test': 2}), isTrue);
      expect(_match(filter, {'test': 3}), isFalse);
    });

    test('and', () {
      var filter =
          Filter.and([Filter.equals('test1', 1), Filter.equals('test2', 2)]);
      expect(_match(filter, {'test1': 1, 'test2': 2}), isTrue);
      expect(
          _match(filter, {'test1': 1, 'test2': 2, 'dummy': 'value'}), isTrue);
      expect(_match(filter, {'test1': 1}), isFalse);
      expect(_match(filter, {'test2': 2}), isFalse);
      expect(_match(filter, {'test1': 1, 'test2': 3}), isFalse);
      expect(_match(filter, {'test1': 2, 'test2': 2}), isFalse);
    });

    test('lessThanOrEguals', () {
      var filter = Filter.lessThanOrEquals('test', 1);
      expect(_match(filter, {'test': 1}), isTrue);
      expect(_match(filter, {'test': 2}), isFalse);
      expect(_match(filter, {'test': 0}), isTrue);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {}), isFalse);
    });

    test('key', () {
      var filter = Filter.byKey(1);
      expect(_match(filter, null), isTrue);
      expect(
          filterMatchesRecord(filter, store.record(1).snapshot(null)), isTrue);
      expect(filterMatchesRecord(filter, store.record('dummy').snapshot(null)),
          isFalse);
      expect(
          filterMatchesRecord(filter, store.record(2).snapshot(null)), isFalse);
      filter = Filter.byKey('my_key');
      expect(filterMatchesRecord(filter, store.record('my_key').snapshot(null)),
          isTrue);
      expect(_match(filter, null), isFalse);
      expect(
          filterMatchesRecord(filter, store.record(1).snapshot(null)), isFalse);
      expect(filterMatchesRecord(filter, store.record('dummy').snapshot(null)),
          isFalse);
    });

    test('lessThan', () {
      var filter = Filter.lessThan('test', 1);
      expect(_match(filter, {'test': 1}), isFalse);
      expect(_match(filter, {'test': 2}), isFalse);
      expect(_match(filter, {'test': 0}), isTrue);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {}), isFalse);
    });

    test('custom', () {
      var filter = Filter.custom((record) => record['valid'] == true);
      expect(_match(filter, {'valid': true}), isTrue);
      expect(_match(filter, {'valid': false}), isFalse);
      expect(_match(filter, null), isFalse);
      expect(_match(filter, 'dummy'), isFalse);
      expect(_match(filter, {'valid': 1}), isFalse);
      expect(_match(filter, {'_valid': 1}), isFalse);
      expect(_match(filter, {'_valid': false}), isFalse);
      expect(_match(filter, {'_valid': true}), isFalse);
    });

    test('matches', () {
      var filter = Filter.matches('test', '^f');
      expect(_match(filter, {'test': 'fish'}), isTrue);
      expect(_match(filter, {'test': 'f'}), isTrue);
      expect(_match(filter, {'test': 'e'}), isFalse);
      expect(_match(filter, {'test': 'g'}), isFalse);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {'test': {}}), isFalse);
      expect(_match(filter, {'test': []}), isFalse);
      expect(
          _match(filter, {
            'test': [1]
          }),
          isFalse);
      expect(_match(filter, {'no_test': null}), isFalse);
      expect(_match(filter, {}), isFalse);
      expect(_match(filter, null), isFalse);
      expect(_match(filter, 'test'), isFalse);
      expect(_match(filter, []), isFalse);

      filter = Filter.matches('test', '^f', anyInList: true);
      expect(
          _match(filter, {
            'test': ['fish']
          }),
          isTrue);
      expect(
          _match(filter, {
            'test': ['no', 'food', true]
          }),
          isTrue);
      expect(
          _match(filter, {
            'test': ['f']
          }),
          isTrue);
      expect(
          _match(filter, {
            'test': ['e']
          }),
          isFalse);
      expect(
          _match(filter, {
            'test': ['g']
          }),
          isFalse);
      expect(
          _match(filter, {
            'test': [1]
          }),
          isFalse);

      expect(_match(filter, {'test': {}}), isFalse);
      expect(_match(filter, {'test': 1}), isFalse);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {'test': []}), isFalse);
      expect(_match(filter, {'no_test': null}), isFalse);
      expect(_match(filter, {}), isFalse);
      expect(_match(filter, null), isFalse);
      expect(_match(filter, 'test'), isFalse);
      expect(_match(filter, []), isFalse);

      /// The key!
      filter = Filter.matches(Field.key, '^f', anyInList: true);
      expect(filterMatchesRecord(filter, store.record(['f']).snapshot(null)),
          isTrue);
      expect(filterMatchesRecord(filter, store.record(['e']).snapshot(null)),
          isFalse);
      expect(
          filterMatchesRecord(filter, store.record(1).snapshot(null)), isFalse);
    });
  });
}

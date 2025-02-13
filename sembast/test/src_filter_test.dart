library;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:sembast/src/filter_impl.dart' show filterMatchesRecord;

import 'test_common.dart';

var store = StoreRef<int, Object>.main();
var record = store.record(1);

RecordSnapshot snapshot(Object value) => record.snapshot(value);

bool _match(Filter? filter, Object value) {
  return filterMatchesRecord(filter, snapshot(value));
}

void main() {
  group('src_filter_test', () {
    test('null filter', () {
      expect(_match(null, {'test': 1}), isTrue);
    });
    test('equals', () {
      var filter = Filter.equals('test', 1);
      expect(_match(filter, {'test': 1}), isTrue);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {'test': <String, Object>{}}), isFalse);
      expect(_match(filter, {'test': <int>[]}), isFalse);
      expect(
        _match(filter, {
          'test': [1],
        }),
        isFalse,
      );
      expect(_match(filter, {'no_test': null}), isFalse);
      expect(_match(filter, <String, Object>{}), isFalse);
      // expect(_match(filter, null), isFalse);
      expect(_match(filter, 'test'), isFalse);
      expect(_match(filter, <Object>[]), isFalse);

      filter = Filter.equals('test', 1, anyInList: true);
      expect(
        _match(filter, {
          'test': [1],
        }),
        isTrue,
      );
      expect(
        _match(filter, {
          'test': ['no', 1, true],
        }),
        isTrue,
      );
      expect(_match(filter, {'test': <String, Object>{}}), isFalse);
      expect(_match(filter, {'test': 1}), isFalse);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {'test': <Object>[]}), isFalse);
      expect(_match(filter, {'no_test': null}), isFalse);
      expect(_match(filter, <String, Object>{}), isFalse);
      // expect(_match(filter, null), isFalse);
      expect(_match(filter, 'test'), isFalse);
      expect(_match(filter, <Object>[]), isFalse);
    });

    test('equalsMap', () {
      var filter = Filter.equals('test', {'sub': 1});
      var notFilter = Filter.notEquals('test', {'sub': 1});

      void testEquals(Object value, bool success) {
        expect(_match(filter, value), success);
        expect(_match(notFilter, value), !success);
      }

      testEquals({
        'test': {'sub': 1},
      }, true);
      testEquals({'no_test': null}, false);
      testEquals({'test': null}, false);
      testEquals({'test': <String, Object>{}}, false);
      testEquals({'test': <Object>[]}, false);
      testEquals({
        'test': {'sub': 2},
      }, false);
    });

    test('equalsList', () {
      var filter = Filter.equals('test', [1]);
      var notFilter = Filter.notEquals('test', [1]);

      void testEquals(Object value, bool success) {
        expect(_match(filter, value), success);
        expect(_match(notFilter, value), !success);
      }

      testEquals({
        'test': [1],
      }, true);
      testEquals({'no_test': null}, false);
      testEquals({'test': null}, false);
      testEquals({'test': <String, Object>{}}, false);
      testEquals({'test': <Object>[]}, false);
      testEquals({
        'test': [2],
      }, false);
    });

    test('sub.field', () {
      var filter = Filter.equals('sub.field', 1);
      expect(_match(filter, {'sub.field': 1}), isFalse);
      expect(
        _match(filter, {
          'sub': {'field': 1},
        }),
        isTrue,
      );
    });
    test('sub.field not null', () {
      var filter = Filter.notEquals('sub.field', null);
      expect(
        _match(filter, {
          'sub': {'field': 1},
        }),
        isTrue,
      );
      expect(
        _match(filter, {
          'sub': {'field': null},
        }),
        isFalse,
      );
    });
    test('sub.field null', () {
      var filter = Filter.equals('sub.field', null);
      expect(
        _match(filter, {
          'sub': {'field': 1},
        }),
        isFalse,
      );
      expect(
        _match(filter, {
          'sub': {'field': null},
        }),
        isTrue,
      );
      expect(_match(filter, {}), isTrue);
    });
    test('sub.listfield', () {
      var filter = Filter.equals('sub.field', 1, anyInList: true);
      expect(
        _match(filter, {
          'sub.field': [1],
        }),
        isFalse,
      );
      expect(
        _match(filter, {
          'sub': {
            'field': [1],
          },
        }),
        isTrue,
      );
    });
    test('item_array', () {
      var filter = Filter.equals('sub.0', 1);
      expect(_match(filter, {'sub': <Object?>[]}), isFalse);
      expect(
        _match(filter, {
          'sub': [1],
        }),
        isTrue,
      );
      expect(
        _match(filter, {
          'sub': {'0': 1},
        }),
        isTrue,
      );
      filter = Filter.equals('sub.@', 1);
      expect(_match(filter, {'sub': <Object?>[]}), isFalse);
      expect(
        _match(filter, {
          'sub': [1],
        }),
        isTrue,
      );
    });
    test('field_with_dot', () {
      var filter = Filter.equals(FieldKey.escape('sub.field'), 1);
      expect(_match(filter, {'sub.field': 1}), isTrue);
      expect(
        _match(filter, {
          'sub': {'field': 1},
        }),
        isFalse,
      );
    });

    test('greaterThanOrEguals', () {
      var filter = Filter.greaterThanOrEquals('test', 1);
      expect(_match(filter, {'test': 1}), isTrue);
      expect(_match(filter, {'test': 2}), isTrue);
      expect(_match(filter, {'test': 0}), isFalse);
      expect(_match(filter, <String, Object>{}), isFalse);
    });

    test('greaterThan', () {
      var filter = Filter.greaterThan('test', 1);
      expect(_match(filter, {'test': 1}), isFalse);
      expect(_match(filter, {'test': 2}), isTrue);
      expect(_match(filter, {'test': 0}), isFalse);
      expect(_match(filter, <String, Object>{}), isFalse);
    });

    test('or', () {
      var filter = Filter.or([
        Filter.equals('test', 1),
        Filter.equals('test', 2),
      ]);
      expect(_match(filter, {'test': 1}), isTrue);
      expect(_match(filter, {'test': 2}), isTrue);
      expect(_match(filter, {'test': 3}), isFalse);
    });

    test('not', () {
      var filter = Filter.not(Filter.equals('test', 2));
      expect(_match(filter, {'test': 1}), isTrue);
      expect(_match(filter, {'test': 2}), isFalse);
      filter = Filter.not(Filter.not(Filter.equals('test', 2)));
      expect(_match(filter, {'test': 2}), isTrue);
      expect(_match(filter, {'test': 1}), isFalse);
    });

    final alwaysMatchFilter = Filter.custom((_) => true);
    final neverMatchFilter = Filter.custom((_) => false);

    test('operator | and &', () {
      expect(_match(alwaysMatchFilter | alwaysMatchFilter, 'dummy'), isTrue);
      expect(_match(alwaysMatchFilter & alwaysMatchFilter, 'dummy'), isTrue);
      expect(_match(alwaysMatchFilter | neverMatchFilter, 'dummy'), isTrue);
      expect(_match(neverMatchFilter | alwaysMatchFilter, 'dummy'), isTrue);
      expect(_match(alwaysMatchFilter & neverMatchFilter, 'dummy'), isFalse);
      expect(_match(neverMatchFilter & alwaysMatchFilter, 'dummy'), isFalse);
      // precedence
      // Dart's precedence rules specify & to have higher precedence than |
      expect(
        _match(
          neverMatchFilter | alwaysMatchFilter & alwaysMatchFilter,
          'dummy',
        ),
        isTrue,
      );
      expect(
        _match(
          alwaysMatchFilter | neverMatchFilter & neverMatchFilter,
          'dummy',
        ),
        isTrue,
      );
      expect(
        _match(
          neverMatchFilter | alwaysMatchFilter & neverMatchFilter,
          'dummy',
        ),
        isFalse,
      );
      expect(
        _match(
          neverMatchFilter | neverMatchFilter & alwaysMatchFilter,
          'dummy',
        ),
        isFalse,
      );
      expect(
        _match(
          neverMatchFilter & alwaysMatchFilter | alwaysMatchFilter,
          'dummy',
        ),
        isTrue,
      );
      expect(
        _match(
          neverMatchFilter & neverMatchFilter | alwaysMatchFilter,
          'dummy',
        ),
        isTrue,
      );
      expect(
        _match(
          neverMatchFilter & alwaysMatchFilter | neverMatchFilter,
          'dummy',
        ),
        isFalse,
      );
      expect(
        _match(
          alwaysMatchFilter & neverMatchFilter | neverMatchFilter,
          'dummy',
        ),
        isFalse,
      );
    });

    test('and', () {
      var filter = Filter.and([
        Filter.equals('test1', 1),
        Filter.equals('test2', 2),
      ]);
      expect(_match(filter, {'test1': 1, 'test2': 2}), isTrue);
      expect(
        _match(filter, {'test1': 1, 'test2': 2, 'dummy': 'value'}),
        isTrue,
      );
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
      expect(_match(filter, <String, Object>{}), isFalse);
    });

    test('key', () {
      var intStore = StoreRef<int, Object>.main();
      var store = StoreRef<String, Object>.main();
      var filter = Filter.byKey(1);
      expect(_match(filter, 'dummy'), isTrue);
      expect(
        filterMatchesRecord(filter, intStore.record(1).snapshot('dummy')),
        isTrue,
      );
      expect(
        filterMatchesRecord(filter, store.record('dummy').snapshot('dummy')),
        isFalse,
      );
      expect(
        filterMatchesRecord(filter, intStore.record(2).snapshot('dummy')),
        isFalse,
      );
      filter = Filter.byKey('my_key');
      expect(
        filterMatchesRecord(filter, store.record('my_key').snapshot('dummy')),
        isTrue,
      );
      expect(_match(filter, 'dummy'), isFalse);
      expect(
        filterMatchesRecord(filter, intStore.record(1).snapshot('dummy')),
        isFalse,
      );
      expect(
        filterMatchesRecord(filter, store.record('dummy').snapshot('dummy')),
        isFalse,
      );
      filter = Filter.byKey(null);
      expect(_match(filter, 'dummy'), isFalse);
    });

    test('lessThan', () {
      var filter = Filter.lessThan('test', 1);
      expect(_match(filter, {'test': 1}), isFalse);
      expect(_match(filter, {'test': 2}), isFalse);
      expect(_match(filter, {'test': 0}), isTrue);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, <String, Object>{}), isFalse);
    });

    test('custom', () {
      var filter = Filter.custom((record) => record['valid'] == true);
      expect(_match(filter, {'valid': true}), isTrue);
      expect(_match(filter, {'valid': false}), isFalse);
      expect(_match(filter, 'dummy'), isFalse);
      expect(_match(filter, {'valid': 1}), isFalse);
      expect(_match(filter, {'_valid': 1}), isFalse);
      expect(_match(filter, {'_valid': false}), isFalse);
      expect(_match(filter, {'_valid': true}), isFalse);
    });

    test('matches', () {
      var store = StoreRef<String, Object>.main();
      var filter = Filter.matches('test', '^f');
      expect(_match(filter, {'test': 'fish'}), isTrue);
      expect(_match(filter, {'test': 'f'}), isTrue);
      expect(_match(filter, {'test': 'e'}), isFalse);
      expect(_match(filter, {'test': 'g'}), isFalse);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {'test': <String, Object?>{}}), isFalse);
      expect(_match(filter, {'test': <Object>[]}), isFalse);
      expect(
        _match(filter, {
          'test': [1],
        }),
        isFalse,
      );
      expect(_match(filter, {'no_test': null}), isFalse);
      expect(_match(filter, <String, Object>{}), isFalse);
      expect(_match(filter, 'dummy'), isFalse);
      expect(_match(filter, 'test'), isFalse);
      expect(_match(filter, <Object>[]), isFalse);

      /// The key!
      filter = Filter.matches(Field.key, '^f');

      expect(
        filterMatchesRecord(filter, store.record('f').snapshot('dummy')),
        isTrue,
      );
      expect(
        filterMatchesRecord(filter, store.record('e').snapshot('dummy')),
        isFalse,
      );

      var intStore = StoreRef<int, Object>.main();
      expect(
        filterMatchesRecord(filter, intStore.record(1).snapshot('dummy')),
        isFalse,
      );

      filter = Filter.matches('test', '^f', anyInList: true);
      expect(
        _match(filter, {
          'test': ['fish'],
        }),
        isTrue,
      );
      expect(
        _match(filter, {
          'test': ['no', 'food', true],
        }),
        isTrue,
      );
      expect(
        _match(filter, {
          'test': ['f'],
        }),
        isTrue,
      );
      expect(
        _match(filter, {
          'test': ['e'],
        }),
        isFalse,
      );
      expect(
        _match(filter, {
          'test': ['g'],
        }),
        isFalse,
      );
      expect(
        _match(filter, {
          'test': [1],
        }),
        isFalse,
      );

      expect(_match(filter, {'test': <String, Object>{}}), isFalse);
      expect(_match(filter, {'test': 1}), isFalse);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {'test': <Object>[]}), isFalse);
      expect(_match(filter, {'no_test': null}), isFalse);
      expect(_match(filter, <String, Object>{}), isFalse);
      expect(_match(filter, 'dummy'), isFalse);
      expect(_match(filter, 'test'), isFalse);
      expect(_match(filter, <Object>[]), isFalse);
    });
  });
}

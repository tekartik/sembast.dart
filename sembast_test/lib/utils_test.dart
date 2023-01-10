library sembast.test.utils_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast_memory.dart';
// ignore_for_file: implementation_imports
import 'package:sembast/src/database_impl.dart' show SembastDatabase;
import 'package:sembast/src/utils.dart';

import 'test_common.dart';

void main() {
  group('utils', () {
    late SembastDatabase db;
    setUpAll(() async {
      // Dummy database to access sanitizeInputValue
      db = (await newDatabaseFactoryMemory().openDatabase('dummy'))
          as SembastDatabase;
    });
    tearDownAll(() async {
      await db.close();
    });
    V? sanitizeInputValue<V extends Object>(RecordValueBase value) {
      return db.sanitizeInputValue<V>(value);
    }

    test('sanitize_input_map', () {
      var map = <Object?, Object?>{'test': 1};
      final sanitizedMap = sanitizeInputValue<Map<String, Object?>>(map);
      expect(sanitizedMap, map);
      try {
        sanitizeInputValue<Map<String, Object>>(map);
        fail('should fail');
      } on ArgumentError catch (_) {}
      try {
        sanitizeInputValue<Map<String, String>>(map);
        fail('should fail');
      } on ArgumentError catch (_) {}
      try {
        sanitizeInputValue<Map<String, int>>(map);
        fail('should fail');
      } on ArgumentError catch (_) {}
    });

    test('sanitize_input_list', () {
      var list = <Object?>[1];
      final sanitizedList = sanitizeInputValue<List<Object?>>(list);

      expect(sanitizedList, list);
      try {
        sanitizeInputValue<List<Object>>(list);
        fail('should fail');
      } on ArgumentError catch (_) {}
      try {
        sanitizeInputValue<List<String>>(list);
        fail('should fail');
      } on ArgumentError catch (_) {}
      try {
        sanitizeInputValue<List<int>>(list);
        fail('should fail');
      } on ArgumentError catch (_) {}
    });

    test('sanitize_nested_map', () {
      var map = <Object?, Object?>{
        'test': <Object?, List>{
          'sub': [
            {
              'value': {'sub': 'value'}
            }
          ]
        },
        'list': <Object?, List<Map<String, Object?>>>{
          'sub': [
            {
              'value': {'sub': 'value'},
              'list': [1]
            }
          ]
        }
      };
      final sanitizedMap = sanitizeInputValue<Map<String, Object?>>(map);
      sanitizeInputValue<Map<String, Object?>>(map);
      expect(sanitizedMap, map);
    });

    test('sanitize iterable', () {
      try {
        sanitizeInputValue({
          'item': [1].map((e) => e)
        });
        fail('should fail');
      } on ArgumentError catch (_) {}
      sanitizeInputValue({
        'item': [1].map((e) => e).toList()
      });
    });

    test('cloneValue', () {
      var existing = {
        'test': 1,
        'nested': {
          'sub': 2,
          'list': [
            {'n': 1},
            2
          ]
        }
      };
      var cloned = cloneValue(existing);
      expect(cloned, existing);
      existing['test'] = 3;
      (existing['nested'] as Map)['sub'] = 4;
      (((existing['nested'] as Map)['list'] as List)[0] as Map)['n'] = 5;
      // Make sure chaging the existing does not change the clone
      expect(existing, {
        'test': 3,
        'nested': {
          'sub': 4,
          'list': [
            {'n': 5},
            2
          ]
        }
      });
      expect(cloned, {
        'test': 1,
        'nested': {
          'sub': 2,
          'list': [
            {'n': 1},
            2
          ]
        }
      });
    });
    test('check_value', () {
      expect(
          checkValue({
            'test': [
              true,
              1.0,
              1,
              {'sub': 1}
            ]
          }),
          isTrue);
      expect(checkValue(DateTime.now()), isFalse);
      expect(checkValue([DateTime.now()]), isFalse);
      expect(checkValue({'test': DateTime.now()}), isFalse);
      expect(checkValue({1: 2}), isFalse);
      expect(checkValue({'test.with.dot': 1}), isFalse);
    });

    test('mergeInnerMap', () {
      expect(
          mergeValue({
            't1': {'s1': 1}
          }, {
            't1': {'s2': 2}
          }),
          {
            't1': {'s2': 2}
          });
      expect(
          mergeValue({
            't1': {'s1': 1}
          }, {
            't1.s2': 2
          }),
          {
            't1': {'s1': 1, 's2': 2}
          });
    });
    test('mergeSubInnerMap', () {
      expect(
          mergeValue({
            't1': {
              's1': {'u1': 1}
            }
          }, {
            't1': {'s2': 2}
          }),
          {
            't1': {'s2': 2}
          });
      expect(
          mergeValue({
            't1': {
              's1': {'u1': 1}
            },
            's2': 2
          }, {
            't1.s1': {'u2': 3}
          }),
          {
            't1': {
              's1': {'u2': 3}
            },
            's2': 2
          });
    });

    test('mergeValue', () {
      expect(mergeValue(null, null), null);
      expect(mergeValue(null, 1), 1);
      expect(mergeValue(1, null), 1);
      expect(mergeValue({'t': 1}, null), {'t': 1});
      expect(mergeValue({'t': 1}, '2'), '2');
      expect(mergeValue('2', {'t': 1}), {'t': 1});

      expect(mergeValue({'t': 1}, {'t': 2}), {'t': 2});
      expect(mergeValue({'t': 1}, {'u': 2}), {'t': 1, 'u': 2});
      expect(mergeValue({'t': 1}, {'u': 2, 't': null}), {'t': null, 'u': 2});
      expect(mergeValue({'t': 1}, {'u': 2, 't': FieldValue.delete}), {'u': 2});
      expect(
          mergeValue({
            'sub': {'t': 1}
          }, {
            'sub': {'u': 2}
          }),
          {
            'sub': {'u': 2}
          });

      expect(
          mergeValue({
            'sub': {'t': 1, 'u': 2}
          }, {
            'sub.t': FieldValue.delete
          }),
          {
            'sub': {'u': 2}
          });
      expect(
          mergeValue({
            'sub': {'t': 1, 'u': 2}
          }, {
            'sub.dummy': FieldValue.delete
          }),
          {
            'sub': {'t': 1, 'u': 2}
          });
      expect(
          mergeValue({
            'sub': {
              't': 1,
              'nested': {'t': 1, 'u': 2}
            }
          }, {
            'sub.nested.t': FieldValue.delete
          }),
          {
            'sub': {
              't': 1,
              'nested': {'u': 2}
            }
          });
      expect(
          mergeValue({
            'sub': {'t': 1}
          }, {
            'sub.u': 2
          }),
          {
            'sub': {'t': 1, 'u': 2}
          });
      expect(
          mergeValue({
            'sub': {
              't': 1,
              'nested': {'t': 1, 'u': 2}
            }
          }, {
            'sub.nested.u': 3,
            'sub.nested.v.w': 4
          }),
          {
            'sub': {
              't': 1,
              'nested': {
                't': 1,
                'u': 3,
                'v': {'w': 4}
              }
            }
          });
    });

    test('mapValue', () {
      var map = <String, Object?>{};
      expect(getPartsMapValue<int>(map, ['test', 'sub']), null);
      setPartsMapValue(map, ['test', 'sub'], 1);
      expect(map, {
        'test': {'sub': 1}
      });
      expect(getPartsMapValue<int>(map, ['test', 'sub']), 1);
      setPartsMapValue(map, ['test', 'sub'], 2);
      expect(map, {
        'test': {'sub': 2}
      });
      setPartsMapValue(map, ['test', 'sub2'], 3);
      expect(map, {
        'test': {'sub': 2, 'sub2': 3}
      });
      setPartsMapValue(map, ['test'], 1);
      expect(map, {'test': 1});
    });

    test('backtick', () {
      expect(backtickChrCode, 96);
      expect(isBacktickEnclosed('``'), isTrue);
      expect(isBacktickEnclosed('`é`'), isTrue);
      expect(isBacktickEnclosed('```'), isTrue);
      expect(isBacktickEnclosed(''), isFalse);
      expect(isBacktickEnclosed('`'), isFalse);
      expect(isBacktickEnclosed('`_'), isFalse);
      expect(isBacktickEnclosed('_`'), isFalse);
    });

    test('mergeValue with backticks', () {
      expect(mergeValue({'foo.bar': 1}, {'foo.bar': 2}), {
        'foo.bar': 1,
        'foo': {'bar': 2}
      });
      expect(
          mergeValue({'foo.bar': 1}, {'foo.bar': 2}, allowDotsInKeys: true), {
        'foo.bar': 2,
      });
      expect(mergeValue({'foo.bar': 1}, {'`foo.bar`': 2}), {
        'foo.bar': 2,
      });
    });
  });
}

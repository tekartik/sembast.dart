library sembast.compat.src_filter_test;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:sembast/sembast.dart';

import 'test_common.dart';

class CompatCustomFilter implements Filter {
  @override
  bool match(Record record) {
    return record['valid'] == true;
  }
}

bool _match(Filter filter, dynamic value) {
  return filter.match(Record(null, value));
}

void main() {
  group('compat_src_filter_test', () {
    test('equals', () {
      var filter = Filter.equal('test', 1);
      expect(_match(filter, {'test': 1}), isTrue);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {'no_test': null}), isFalse);
      expect(_match(filter, {}), isFalse);
      expect(_match(filter, null), isFalse);
      expect(_match(filter, 'test'), isFalse);
      expect(_match(filter, []), isFalse);
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

    test('lessThanOrEguals', () {
      var filter = Filter.lessThanOrEquals('test', 1);
      expect(_match(filter, {'test': 1}), isTrue);
      expect(_match(filter, {'test': 2}), isFalse);
      expect(_match(filter, {'test': 0}), isTrue);
      expect(_match(filter, {'test': null}), isFalse);
      expect(_match(filter, {}), isFalse);
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
      var filter = CompatCustomFilter();
      expect(_match(filter, {'valid': true}), isTrue);
      expect(_match(filter, {'valid': false}), isFalse);
      expect(_match(filter, null), isFalse);
      expect(_match(filter, {'valid': 1}), isFalse);
      expect(_match(filter, {'_valid': 1}), isFalse);
      expect(_match(filter, {'_valid': false}), isFalse);
      expect(_match(filter, {'_valid': true}), isFalse);
    });
  });
}

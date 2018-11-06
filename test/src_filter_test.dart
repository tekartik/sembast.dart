library sembast.io_file_system_test;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:sembast/sembast.dart';
import 'test_common.dart';

void main() {
  group('src_filter_test', () {
    test('equals', () {
      var filter = Filter.equal('test', 1);
      expect(filter.match(Record(null, {'test': 1})), isTrue);
      expect(filter.match(Record(null, {'test': null})), isFalse);
      expect(filter.match(Record(null, {'no_test': null})), isFalse);
      expect(filter.match(Record(null, {})), isFalse);
      expect(filter.match(Record(null, null)), isFalse);
      expect(filter.match(Record(null, 'test')), isFalse);
      expect(filter.match(Record(null, [])), isFalse);
    });

    test('greaterThanOrEguals', () {
      var filter = Filter.greaterThanOrEquals('test', 1);
      expect(filter.match(Record(null, {'test': 1})), isTrue);
      expect(filter.match(Record(null, {'test': 2})), isTrue);
      expect(filter.match(Record(null, {'test': 0})), isFalse);
      expect(filter.match(Record(null, {})), isFalse);
    });

    test('greaterThan', () {
      var filter = Filter.greaterThan('test', 1);
      expect(filter.match(Record(null, {'test': 1})), isFalse);
      expect(filter.match(Record(null, {'test': 2})), isTrue);
      expect(filter.match(Record(null, {'test': 0})), isFalse);
      expect(filter.match(Record(null, {})), isFalse);
    });

    test('lessThanOrEguals', () {
      var filter = Filter.lessThanOrEquals('test', 1);
      expect(filter.match(Record(null, {'test': 1})), isTrue);
      expect(filter.match(Record(null, {'test': 2})), isFalse);
      expect(filter.match(Record(null, {'test': 0})), isTrue);
      expect(filter.match(Record(null, {'test': null})), isFalse);
      expect(filter.match(Record(null, {})), isFalse);
    });

    test('lessThan', () {
      var filter = Filter.lessThan('test', 1);
      expect(filter.match(Record(null, {'test': 1})), isFalse);
      expect(filter.match(Record(null, {'test': 2})), isFalse);
      expect(filter.match(Record(null, {'test': 0})), isTrue);
      expect(filter.match(Record(null, {'test': null})), isFalse);
      expect(filter.match(Record(null, {})), isFalse);
    });
  });
}

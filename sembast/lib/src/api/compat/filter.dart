// ignore_for_file: public_member_api_docs

/// @deprecated v2
@deprecated
class FilterOperation {
  final int value;

  const FilterOperation._(this.value);

  static const FilterOperation equals = FilterOperation._(1);
  static const FilterOperation notEquals = FilterOperation._(2);
  static const FilterOperation lessThan = FilterOperation._(3);
  static const FilterOperation lessThanOrEquals = FilterOperation._(4);
  static const FilterOperation greaterThan = FilterOperation._(5);
  static const FilterOperation greaterThanOrEquals = FilterOperation._(6);
  static const FilterOperation inList = FilterOperation._(7);
  static const FilterOperation matches = FilterOperation._(8);

  @override
  String toString() {
    switch (this) {
      case FilterOperation.equals:
        return '=';
      case FilterOperation.notEquals:
        return '!=';
      case FilterOperation.lessThan:
        return '<';
      case FilterOperation.lessThanOrEquals:
        return '<=';
      case FilterOperation.greaterThan:
        return '>';
      case FilterOperation.greaterThanOrEquals:
        return '>=';
      case FilterOperation.inList:
        return 'IN';
      case FilterOperation.matches:
        return 'MATCHES';
      default:
        throw '${this} not supported';
    }
  }
}

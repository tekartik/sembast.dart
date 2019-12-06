import 'dart:math';

import 'package:sembast/src/cooperator.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sort.dart';
import 'package:sembast/src/utils.dart';

import 'api/compat/finder.dart';
import 'api/compat/record.dart';

// ignore_for_file: deprecated_member_use_from_same_package

/// Sort and limit a list.
Future<List<ImmutableSembastRecord>> sortAndLimit(
    List<ImmutableSembastRecord> results,
    SembastFinder finder,
    Cooperator cooperator) async {
  final cooperateOn = cooperator?.cooperateOn == true;
  if (finder != null) {
    // sort
    if (cooperateOn) {
      var sort = Sort(cooperator);
      await sort.sort(
          results,
          (Record record1, Record record2) =>
              finder.compareThenKey(record1, record2));
    } else {
      results
          .sort((record1, record2) => finder.compareThenKey(record1, record2));
    }

    Future<List<ImmutableSembastRecord>> filterStart(
        List<ImmutableSembastRecord> results) async {
      var startIndex = 0;
      for (var i = 0; i < results.length; i++) {
        if (cooperator?.needCooperate == true) {
          await cooperator.cooperate();
        }
        if (finder.starts(results[i], finder.start)) {
          startIndex = i;
          break;
        }
      }
      if (startIndex != 0) {
        return results.sublist(startIndex);
      }
      return results;
    }

    Future<List<ImmutableSembastRecord>> filterEnd(
        List<ImmutableSembastRecord> results) async {
      var endIndex = 0;
      for (var i = results.length - 1; i >= 0; i--) {
        if (cooperator?.needCooperate == true) {
          await cooperator.cooperate();
        }
        if (finder.ends(results[i], finder.end)) {
          // continue
        } else {
          endIndex = i + 1;
          break;
        }
      }
      if (endIndex != results.length) {
        return results.sublist(0, endIndex);
      }
      return results;
    }

    try {
      // handle start
      if (finder.start != null) {
        results = await filterStart(results);
      }
      // handle end
      if (finder.end != null) {
        results = await filterEnd(results);
      }
    } catch (e) {
      print('Make sure you are comparing boundaries with a proper type');
      rethrow;
    }

    // offset
    if (finder.offset != null) {
      results = results.sublist(min(finder.offset, results.length));
    }
    // limit
    if (finder.limit != null) {
      results = results.sublist(0, min(finder.limit, results.length));
    }
  } else {
    if (cooperateOn) {
      var sort = Sort(cooperator);
      await sort.sort(results, compareRecordKey);
    } else {
      results.sort(compareRecordKey);
    }
  }
  return results;
}

// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Copied and modified from dart_sdk
// ignore_for_file: non_constant_identifier_names

import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/cooperator.dart';

/// Dual-Pivot Quicksort algorithm.
///
/// This class implements the dual-pivot quicksort algorithm as presented in
/// Vladimir Yaroslavskiy's paper.
///
/// Some improvements have been copied from Android's implementation.
class Sort {
  /// Cooperator to use.
  final Cooperator cooperator;

  // When a list has less then [:_INSERTION_SORT_THRESHOLD:] elements it will
  // be sorted by an insertion sort.
  static const int _insertionSortThreshold = 32;

  /// Constructor.
  Sort(this.cooperator);

  /// Sorts all elements of the given list [:a:] according to the given
  /// [:compare:] function.
  ///
  /// The [:compare:] function takes two arguments [:x:] and [:y:] and returns
  ///  -1 if [:x < y:],
  ///   0 if [:x == y:], and
  ///   1 if [:x > y:].
  ///
  /// The function's behavior must be consistent. It must not return different
  /// results for the same values.
  Future sort<E>(List<E> a, int Function(E a, E b) compare) {
    return _doSort(a, 0, a.length - 1, compare);
  }

  /// Sorts the list in the interval [:left:] to [:right:] (both inclusive).
  Future _doSort<E>(
    List<E> a,
    int left,
    int right,
    int Function(E a, E b) compare,
  ) async {
    if ((right - left) <= _insertionSortThreshold) {
      return _insertionSort(a, left, right, compare);
    } else {
      return _dualPivotQuicksort(a, left, right, compare);
    }
  }

  Future _insertionSort<E>(
    List<E> a,
    int left,
    int right,
    int Function(E a, E b) compare,
  ) async {
    for (var i = left + 1; i <= right; i++) {
      var el = a[i];
      var j = i;
      while ((j > left) && (compare(a[j - 1], el) > 0)) {
        if (cooperator.needCooperate) {
          await cooperator.cooperate();
        }
        a[j] = a[j - 1];
        j--;
      }
      a[j] = el;
    }
  }

  Future _dualPivotQuicksort<E>(
    List<E> a,
    int left,
    int right,
    int Function(E a, E b) compare,
  ) async {
    assert(right - left > _insertionSortThreshold);

    // Compute the two pivots by looking at 5 elements.
    final sixth = (right - left + 1) ~/ 6;
    final index1 = left + sixth;
    final index5 = right - sixth;
    final index3 = (left + right) ~/ 2; // The midpoint.
    final index2 = index3 - sixth;
    final index4 = index3 + sixth;

    var el1 = a[index1];
    var el2 = a[index2];
    var el3 = a[index3];
    var el4 = a[index4];
    var el5 = a[index5];

    // Sort the selected 5 elements using a sorting network.
    if (compare(el1, el2) > 0) {
      var t = el1;
      el1 = el2;
      el2 = t;
    }
    if (compare(el4, el5) > 0) {
      var t = el4;
      el4 = el5;
      el5 = t;
    }
    if (compare(el1, el3) > 0) {
      var t = el1;
      el1 = el3;
      el3 = t;
    }
    if (compare(el2, el3) > 0) {
      var t = el2;
      el2 = el3;
      el3 = t;
    }
    if (compare(el1, el4) > 0) {
      var t = el1;
      el1 = el4;
      el4 = t;
    }
    if (compare(el3, el4) > 0) {
      var t = el3;
      el3 = el4;
      el4 = t;
    }
    if (compare(el2, el5) > 0) {
      var t = el2;
      el2 = el5;
      el5 = t;
    }
    if (compare(el2, el3) > 0) {
      var t = el2;
      el2 = el3;
      el3 = t;
    }
    if (compare(el4, el5) > 0) {
      var t = el4;
      el4 = el5;
      el5 = t;
    }

    var pivot1 = el2;
    var pivot2 = el4;

    // el2 and el4 have been saved in the pivot variables. They will be written
    // back, once the partitioning is finished.
    a[index1] = el1;
    a[index3] = el3;
    a[index5] = el5;

    a[index2] = a[left];
    a[index4] = a[right];

    var less = left + 1; // First element in the middle partition.
    var great = right - 1; // Last element in the middle partition.

    var pivots_are_equal = (compare(pivot1, pivot2) == 0);
    if (pivots_are_equal) {
      var pivot = pivot1;
      // Degenerated case where the partitioning becomes a Dutch national flag
      // problem.
      //
      // [ |  < pivot  | == pivot | unpartitioned | > pivot  | ]
      //  ^             ^          ^             ^            ^
      // left         less         k           great         right
      //
      // a[left] and a[right] are undefined and are filled after the
      // partitioning.
      //
      // Invariants:
      //   1) for x in ]left, less[ : x < pivot.
      //   2) for x in [less, k[ : x == pivot.
      //   3) for x in ]great, right[ : x > pivot.
      for (var k = less; k <= great; k++) {
        var ak = a[k];
        var comp = compare(ak, pivot);
        if (cooperator.needCooperate) {
          await cooperator.cooperate();
        }

        if (comp == 0) continue;
        if (comp < 0) {
          if (k != less) {
            a[k] = a[less];
            a[less] = ak;
          }
          less++;
        } else {
          // comp > 0.
          //
          // Find the first element <= pivot in the range [k - 1, great] and
          // put [:ak:] there. We know that such an element must exist:
          // When k == less, then el3 (which is equal to pivot) lies in the
          // interval. Otherwise a[k - 1] == pivot and the search stops at k-1.
          // Note that in the latter case invariant 2 will be violated for a
          // short amount of time. The invariant will be restored when the
          // pivots are put into their final positions.
          while (true) {
            comp = compare(a[great], pivot);
            if (cooperator.needCooperate) {
              await cooperator.cooperate();
            }

            if (comp > 0) {
              great--;
              // This is the only location in the while-loop where a new
              // iteration is started.
              continue;
            } else if (comp < 0) {
              // Triple exchange.
              a[k] = a[less];
              a[less++] = a[great];
              a[great--] = ak;
              break;
            } else {
              // comp == 0;
              a[k] = a[great];
              a[great--] = ak;
              // Note: if great < k then we will exit the outer loop and fix
              // invariant 2 (which we just violated).
              break;
            }
          }
        }
      }
    } else {
      // We partition the list into three parts:
      //  1. < pivot1
      //  2. >= pivot1 && <= pivot2
      //  3. > pivot2
      //
      // During the loop we have:
      // [ | < pivot1 | >= pivot1 && <= pivot2 | unpartitioned  | > pivot2  | ]
      //  ^            ^                        ^              ^             ^
      // left         less                     k              great        right
      //
      // a[left] and a[right] are undefined and are filled after the
      // partitioning.
      //
      // Invariants:
      //   1. for x in ]left, less[ : x < pivot1
      //   2. for x in [less, k[ : pivot1 <= x && x <= pivot2
      //   3. for x in ]great, right[ : x > pivot2
      for (var k = less; k <= great; k++) {
        var ak = a[k];
        var comp_pivot1 = compare(ak, pivot1);
        if (cooperator.needCooperate) {
          await cooperator.cooperate();
        }

        if (comp_pivot1 < 0) {
          if (k != less) {
            a[k] = a[less];
            a[less] = ak;
          }
          less++;
        } else {
          var comp_pivot2 = compare(ak, pivot2);
          if (cooperator.needCooperate) {
            await cooperator.cooperate();
          }
          if (comp_pivot2 > 0) {
            while (true) {
              var comp = compare(a[great], pivot2);
              if (cooperator.needCooperate) {
                await cooperator.cooperate();
              }

              if (comp > 0) {
                great--;
                if (great < k) break;
                // This is the only location inside the loop where a new
                // iteration is started.
                continue;
              } else {
                // a[great] <= pivot2.
                comp = compare(a[great], pivot1);
                if (cooperator.needCooperate) {
                  await cooperator.cooperate();
                }

                if (comp < 0) {
                  // Triple exchange.
                  a[k] = a[less];
                  a[less++] = a[great];
                  a[great--] = ak;
                } else {
                  // a[great] >= pivot1.
                  a[k] = a[great];
                  a[great--] = ak;
                }
                break;
              }
            }
          }
        }
      }
    }

    // Move pivots into their final positions.
    // We shrunk the list from both sides (a[left] and a[right] have
    // meaningless values in them) and now we move elements from the first
    // and third partition into these locations so that we can store the
    // pivots.
    a[left] = a[less - 1];
    a[less - 1] = pivot1;
    a[right] = a[great + 1];
    a[great + 1] = pivot2;

    // The list is now partitioned into three partitions:
    // [ < pivot1   | >= pivot1 && <= pivot2   |  > pivot2   ]
    //  ^            ^                        ^             ^
    // left         less                     great        right

    // Recursive descent. (Don't include the pivot values.)
    await _doSort(a, left, less - 2, compare);
    await _doSort(a, great + 2, right, compare);

    if (pivots_are_equal) {
      // All elements in the second partition are equal to the pivot. No
      // need to sort them.
      return;
    }

    // In theory it should be enough to call _doSort recursively on the second
    // partition.
    // The Android source however removes the pivot elements from the recursive
    // call if the second partition is too large (more than 2/3 of the list).
    if (less < index1 && great > index5) {
      while (compare(a[less], pivot1) == 0) {
        if (cooperator.needCooperate) {
          await cooperator.cooperate();
        }
        less++;
      }
      while (compare(a[great], pivot2) == 0) {
        if (cooperator.needCooperate) {
          await cooperator.cooperate();
        }
        great--;
      }

      // Copy paste of the previous 3-way partitioning with adaptions.
      //
      // We partition the list into three parts:
      //  1. == pivot1
      //  2. > pivot1 && < pivot2
      //  3. == pivot2
      //
      // During the loop we have:
      // [ == pivot1 | > pivot1 && < pivot2 | unpartitioned  | == pivot2 ]
      //              ^                      ^              ^
      //            less                     k              great
      //
      // Invariants:
      //   1. for x in [ *, less[ : x == pivot1
      //   2. for x in [less, k[ : pivot1 < x && x < pivot2
      //   3. for x in ]great, * ] : x == pivot2
      for (var k = less; k <= great; k++) {
        var ak = a[k];
        var comp_pivot1 = compare(ak, pivot1);
        if (cooperator.needCooperate) {
          await cooperator.cooperate();
        }

        if (comp_pivot1 == 0) {
          if (k != less) {
            a[k] = a[less];
            a[less] = ak;
          }
          less++;
        } else {
          var comp_pivot2 = compare(ak, pivot2);
          if (comp_pivot2 == 0) {
            while (true) {
              var comp = compare(a[great], pivot2);
              if (cooperator.needCooperate) {
                await cooperator.cooperate();
              }

              if (comp == 0) {
                great--;
                if (great < k) break;
                // This is the only location inside the loop where a new
                // iteration is started.
                continue;
              } else {
                // a[great] < pivot2.
                comp = compare(a[great], pivot1);
                if (cooperator.needCooperate) {
                  await cooperator.cooperate();
                }

                if (comp < 0) {
                  // Triple exchange.
                  a[k] = a[less];
                  a[less++] = a[great];
                  a[great--] = ak;
                } else {
                  // a[great] == pivot1.
                  a[k] = a[great];
                  a[great--] = ak;
                }
                break;
              }
            }
          }
        }
      }
      // The second partition has now been cleared of pivot elements and looks
      // as follows:
      // [  *  |  > pivot1 && < pivot2  | * ]
      //        ^                      ^
      //       less                  great
      // Sort the second partition using recursive descent.
      await _doSort(a, less, great, compare);
    } else {
      // The second partition looks as follows:
      // [  *  |  >= pivot1 && <= pivot2  | * ]
      //        ^                        ^
      //       less                    great
      // Simply sort it by recursive descent.
      await _doSort(a, less, great, compare);
    }
  }
}

/// Find the sorted index of an item
int findSortedIndex<T>(List<T> list, T item, int Function(T a, T b) compare) {
  var start = 0;
  var end = list.length;

  while (start < end) {
    var pivot = start + ((end - start) ~/ 2);
    var value = list[pivot];
    var cmp = compare(value, item);
    if (cmp < 0) {
      start = pivot + 1;
    } else {
      end = pivot;
    }
  }
  return start;
}

library sembast.test.src_stream_utils_test;

import 'package:sembast/src/stream_utils.dart';
import 'package:test/test.dart';

void main() {
  Stream<Object?> emptyStream() => Stream.fromIterable(<Object?>[]);
  Stream<int?> oneIntStream([int value = 1]) =>
      Stream.fromIterable(<int?>[value]);
  group('stream_utils', () {
    test('streamJoinAll', () {
      expect(emptyStream(), emitsInOrder([emitsDone]));
      expect(streamJoinAll([emptyStream()]), emitsInOrder([emitsDone]));

      expect(streamJoinAll([emptyStream(), emptyStream()]),
          emitsInOrder([emitsDone]));
      expect(oneIntStream(), emitsInOrder([1, emitsDone]));
      expect(oneIntStream(2), emitsInOrder([2, emitsDone]));
      expect(
          streamJoinAll([oneIntStream(), oneIntStream(2)]),
          emitsInOrder([
            [1, 2],
            emitsDone
          ]));
      expect(streamJoinAll([emptyStream(), oneIntStream()]),
          emitsInOrder([emitsDone]));
      expect(
          streamJoinAll([
            oneIntStream(),
            Stream.fromIterable([2, 3])
          ]),
          emitsInOrder([
            [1, 2],
            [1, 3],
            emitsDone
          ]));
      expect(
          streamJoinAll([
            Stream.fromIterable([1, 2, 3]),
            Stream.fromIterable([4, 5])
          ]),
          emitsInOrder([
            [1, 4],
            [2, 4],
            [2, 5],
            [3, 5],
            emitsDone
          ]));
      expect(
          streamJoinAll([
            Stream.fromIterable([1]),
            Stream.fromIterable([2, 3]),
            Stream.fromIterable([4, 5, 6])
          ]),
          emitsInOrder([
            [1, 2, 4],
            [1, 3, 4],
            [1, 3, 5],
            [1, 3, 6],
            emitsDone
          ]));
    });
  });
}

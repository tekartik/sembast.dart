// This file was copied from
// https://github.com/flutter/plugins/blob/master/packages/cloud_firestore/lib/src/utils/push_id_generator.dart

// Copyright 2017, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

/// Utility class for generating Firebase child node keys.
///
/// Since the Flutter plugin API is asynchronous, there's no way for us
/// to use the native SDK to generate the node key synchronously and we
/// have to do it ourselves if we want to be able to reference the
/// newly-created node synchronously.
///
/// This code is based on a Firebase blog post and ported to Dart.
/// https://firebase.googleblog.com/2015/02/the-2120-ways-to-ensure-unique_68.html
class PushIdGenerator {
  /// The char set.
  static const String pushChars =
      '-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz';

  static final Random _random = Random();

  static int? _lastPushTime;

  static final List<int?> _lastRandChars = List<int?>.filled(12, null);

  /// Generate a child name.
  static String generatePushChildName() {
    var now = DateTime.now().millisecondsSinceEpoch;
    final duplicateTime = (now == _lastPushTime);
    _lastPushTime = now;

    final timeStampChars = List<String?>.filled(8, null);
    for (var i = 7; i >= 0; i--) {
      timeStampChars[i] = pushChars[now % 64];
      now = (now / 64).floor();
    }
    assert(now == 0);

    final result = StringBuffer(timeStampChars.join());

    if (!duplicateTime) {
      for (var i = 0; i < 12; i++) {
        _lastRandChars[i] = _random.nextInt(64);
      }
    } else {
      _incrementArray();
    }
    for (var i = 0; i < 12; i++) {
      result.write(pushChars[_lastRandChars[i]!]);
    }
    assert(result.length == 20);
    return result.toString();
  }

  static void _incrementArray() {
    for (var i = 11; i >= 0; i--) {
      if (_lastRandChars[i] != 63) {
        _lastRandChars[i] = _lastRandChars[i]! + 1;
        return;
      }
      _lastRandChars[i] = 0;
    }
  }
}

/// Generate a key.
String generateStringKey() => PushIdGenerator.generatePushChildName();

import 'dart:async';
import 'dart:convert';

import 'package:sembast/sembast.dart';

import 'sembast_codec.dart';

/// Asynchronous content codec that can be used in a sembast codec.
/// T is typically a String while source is a json encodable.
abstract class AsyncCodec<S, T> implements Codec<S, T> {
  @override
  @Deprecated('use decodeAsync')
  S decode(T encoded);

  @override
  @Deprecated('use encodeAsync')
  T encode(S input);

  /// To implement.
  Future<S> decodeAsync(T encoded);

  /// To implement.
  Future<T> encodeAsync(S input);
}

/// Base implementation for an async codec.
abstract class AsyncCodecBase<S, T> implements AsyncCodec<S, T> {
  @override
  S decode(T encoded) =>
      throw UnsupportedError('no sync decode, use decodeAsync');

  @override
  T encode(S input) =>
      throw UnsupportedError('no sync encode, use encodeAsync');

  @override
  Converter<T, S> get decoder =>
      throw UnsupportedError('decoder, use decodeAsync');

  @override
  Converter<S, T> get encoder =>
      throw UnsupportedError('encoder, use encodeAsync');

  @override
  Codec<S, R> fuse<R>(Codec<T, R> other) => throw UnsupportedError('fuse');

  @override
  Codec<T, S> get inverted => throw UnsupportedError('inverted');
}

/// Base class for a custion implementation, by defining only [decodeAsync]
/// and [encodeAsync]
abstract class AsyncContentCodecBase extends AsyncCodecBase<Object?, String> {}

/// Async codec for demonstration purpose.
class AsyncContentJsonCodec extends AsyncContentCodecBase {
  @override
  Future<Object> decodeAsync(String encoded) async {
    return json.decode(encoded) as Object;
  }

  @override
  Future<String> encodeAsync(Object? input) async {
    return json.encode(input);
  }
}

/// Async support, used internally
extension SembastCodecAsyncSupport on SembastCodec {
  /// True if a codec is async.
  bool get hasAsyncCodec => codec?.isAsyncCodec ?? false;

  /// Use the one defined or the default one
  Codec<Object?, String> get _contentCodec => sembastCodecContentCodec(this);

  /// Decode a single line of content.
  FutureOr<T> decodeContent<T extends Object>(String encoded) =>
      _contentCodec.decodeContent(encoded);

  /// Decode a single line of content (sync)
  T decodeContentSync<T extends Object>(String encoded) =>
      _contentCodec.decodeContentSync<T>(encoded);

  /// Decode a single line of content (async)
  Future<T> decodeContentAsync<T extends Object>(String encoded) =>
      _contentCodec.decodeContentAsync<T>(encoded);

  /// Encode a content to a single line.
  FutureOr<String> encodeContent(Object value) =>
      _contentCodec.encodeContent(value);

  /// Decode a single line of content (async)
  Future<String> encodeContentAsync(Object value) =>
      _contentCodec.encodeContentAsync(value);

  /// Decode a single line of content (sync)
  String encodeContentSync(Object value) =>
      _contentCodec.encodeContentSync(value);
}

/// Async support, used internally
extension SembastContentCodecAsyncSupport on Codec<Object?, String> {
  /// True if a codec is async.
  bool get isAsyncCodec => this is AsyncCodec;

  /// Use the one defined or the default one
  Codec<Object?, String> get _contentCodecSync => this;

  AsyncCodec<Object?, String> get _contentCodecAsync =>
      this as AsyncCodec<Object?, String>;

  /// Decode a single line of content.
  FutureOr<T> decodeContent<T extends Object>(String encoded) {
    if (isAsyncCodec) {
      return decodeContentAsync<T>(encoded);
    } else {
      return decodeContentSync<T>(encoded);
    }
  }

  /// Decode a single line of content (async)
  Future<T> decodeContentAsync<T extends Object>(String encoded) async {
    return (await _contentCodecAsync.decodeAsync(encoded)) as T;
  }

  /// Decode a single line of content (sync)
  T decodeContentSync<T extends Object>(String encoded) {
    return _contentCodecSync.decode(encoded) as T;
  }

  /// Encode a single line of content.
  FutureOr<String> encodeContent(Object value) {
    if (isAsyncCodec) {
      return encodeContentAsync(value);
    } else {
      return encodeContentSync(value);
    }
  }

  /// Encode a single line of content (async)
  Future<String> encodeContentAsync(Object value) async {
    return (await _contentCodecAsync.encodeAsync(value));
  }

  /// Encode a single line of content (sync)
  String encodeContentSync(Object value) {
    return _contentCodecSync.encode(value);
  }
}

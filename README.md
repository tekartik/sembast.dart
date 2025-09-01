# sembast

[![pub package](https://img.shields.io/pub/v/sembast.svg)](https://pub.dev/packages/sembast)
[![Build Status](https://travis-ci.org/tekartik/sembast.dart.svg?branch=master)](https://travis-ci.org/tekartik/sembast.dart)
[![codecov](https://codecov.io/gh/tekartik/sembast.dart/branch/master/graph/badge.svg)](https://codecov.io/gh/tekartik/sembast.dart)

NoSQL persistent embedded file system document-based database for Dart VM and Flutter with encryption support.

## General

Yet another NoSQL persistent store database solution.

Pure dart solution working on Dart VM and Flutter using the file system as storage (1 database = 1 file). Works in
memory (Browser, VM, Flutter, Node) for testing purpose

* Supports single process io applications (Pure dart single file IO VM/Flutter storage supported)
* Support transactions
* Version management
* Helpers for finding data
* Web support (including Flutter Web) through [`sembast_web`](https://pub.dev/packages/sembast_web).
* Can work on top of sqflite through [`sembast_sqflite`](https://pub.dev/packages/sembast_sqflite).

Usage example: 
* [notepad_sembast](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_sembast): Simple flutter notepad working on all platforms (web/mobile/desktop)
 ([online demo](https://alextekartik.github.io/flutter_app_example/notepad_sembast/))
* [demo_sembast](https://github.com/alextekartik/flutter_app_example/tree/master/demo_sembast): Simplest sembast demo based on the app template with added persistency. [Online demo](https://alextekartik.github.io/flutter_app_example/demo_sembast)
  

Follow the [guide](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/guide.md).

## Documentation

* [Documentation](https://github.com/tekartik/sembast.dart/blob/master/sembast/README.md)

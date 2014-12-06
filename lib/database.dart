library tekartik_iodb.database;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:tekartik_core/dev_utils.dart';

class _Meta {

  int version;

  _Meta.fromJson(Map json) {
    version = json["version"];
  }

  _Meta(this.version);

  Map toJson() {
    var map = {
      "version": version
    };
    return map;
  }
}
class Database {

  String _path;

  _Meta _meta;
  String get path => _path;
  int get version => _meta.version;

  bool _opened = false;
  File _file;

  /**
   * only valid before open
   */
  static Future delete(String path) {
    return new File(path).exists().then((exists) {
      return new File(path).delete(recursive: true).catchError((_) {
      });
    });
  }

  Database();

  Future onUpgrade(int oldVersion, int newVersion) {
    // default is to clear everything
    return new Future.value();
  }

  Future onDowngrade(int oldVersion, int newVersion) {
    // default is to clear everything
    return new Future.value();
  }

  Future open(String path, [int version]) {
    if (_opened) {
      return new Future.value();
    }
    _Meta meta;
    return FileSystemEntity.isFile(path).then((isFile) {
      if (!isFile) {
        return new File(path).create(recursive: true).then((File file) {

        }).catchError((e) {
          return FileSystemEntity.isFile(path).then((isFile) {
            if (!isFile) {
              throw e;
            }
          });
        });
      }
    }).then((_) {
      File file = new File(path);

      return file.openRead().transform(UTF8.decoder).transform(new LineSplitter()).first.then((firstLine) {
        meta = new _Meta.fromJson(JSON.decode(firstLine));
        version = meta.version;

      }).catchError((e, st) {
        // devError("$e $st");
        // no version yet

        // if no version asked this is a read-only view only
        if (version == null) {
          throw e;
        }
        meta = new _Meta(version);
        IOSink sink = file.openWrite(mode: FileMode.WRITE);


        sink.writeln(JSON.encode(meta.toJson()));
      });
    }).then((_) {
      _path = path;
      _meta = meta;
      _opened = true;
    });

  }

  void close() {
    _opened = false;
    // return new Future.value();
  }
}

import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:tekartik_app_web_build/dhttpd.dart';

Future<void> main(List<String> args) async {
  await run('''
      dart pub get
      webdev build -o web:build
  ''');
  await dhttpdReady();
  stdout.writeln('http://localhost:8080');
  await Shell(workingDirectory: 'build').run('dhttpd');
}

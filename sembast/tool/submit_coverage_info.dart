
import 'dart:io';

import 'package:http/io_client.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';

Future<void> main() async {
  final shell = Shell();

  // CODECOV_TOKEN must be defined on travis
  final codeCovToken = userEnvironment['CODECOV_TOKEN'];
  final dartVersion = userEnvironment['TRAVIS_DART_VERSION'];

  if (dartVersion == 'stable') {
    if (codeCovToken != null) {
      try {
        final dir = await Directory.systemTemp.createTemp('sembast');
        final bashFilePath = join(dir.path, 'codecov.bash');
        await File(bashFilePath)
            .writeAsString(await IOClient().read('https://codecov.io/bash'));
        await shell.run('bash $bashFilePath');
      } catch (e) {
        stderr.writeln('Publishing code coverage failed ($e)');
      }
    } else {
      stdout.writeln(
          'CODECOV_TOKEN not defined. Not publishing coverage information');
    }
  } else {
    stdout.writeln('No code coverage for non-stable dart version $dartVersion');
  }
}

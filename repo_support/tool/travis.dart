import 'package:path/path.dart';
import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  for (var dir in ['sembast', 'sembast_web', 'sembast_test']) {
    shell = shell.pushd(join('..', dir));
    await shell.run('''
    
  pub get
  dart tool/travis.dart
  
''');
    shell = shell.popd();
  }
}

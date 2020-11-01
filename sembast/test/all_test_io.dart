library sembast.test.all_test_io;

import 'database_codec_test.dart' as database_codec_test;
import 'test_common.dart';

void ioDefineFileSystemTests(FileSystemTestContext ctx) {
  database_codec_test.defineTests(ctx);
}

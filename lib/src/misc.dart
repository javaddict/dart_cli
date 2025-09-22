import 'dart:io';

import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import 'file_system.dart';
import 'process.dart';

String? which(String program) {
  final pr = [
    Platform.isWindows ? 'where' : 'which',
    program,
  ].run(showCommand: false, showMessages: false);
  return pr.ok ? pr.output : null;
}

// If this is an executable named "program" and is executed through PATH,
// [Platform.script.path] will be `'${Directory.current.path}/program'` but not
// the correct one in PATH.
String get scriptPath {
  var p = Platform.script.path;
  if (Platform.isWindows) {
    // [Platform.script.path] is something like "/C:/msys64/home/..." on
    // Windows. It might be a bug.
    if (RegExp(r'^/\S:/').hasMatch(p)) {
      p = p.substring(1);
    }
  }
  if (!p.isFile()) {
    p = which(basename(p)) ?? p;
  }
  return p;
}

final pwd = Directory.current.path;

final _cachedRegExps = <String, RegExp>{};

RegExp getRegExp(String pattern) {
  _cachedRegExps[pattern] ??= RegExp(pattern);
  return _cachedRegExps[pattern]!;
}

final _uuid = Uuid();
final _tempFiles = <String>[];

String createTempFile({String? suffix}) {
  final f =
      '${join(Directory.systemTemp.path, _uuid.v4())}${suffix != null && suffix[0] != '.' ? '.' : ''}${suffix ?? ''}';
  _tempFiles.add(f);
  f.create();
  return f;
}

void deleteTempFiles() {
  _tempFiles.forEach(delete);
  _tempFiles.clear();
}

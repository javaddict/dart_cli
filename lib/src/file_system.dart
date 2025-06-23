import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart';

import 'process.dart';

// In MSYS2, we use '\n' as the line terminator.
final _lineTerminator = Platform.isWindows && env['SHELL'] != null
    ? '\n'
    : Platform.lineTerminator;

extension Path on String {
  bool isDirectory() => FileSystemEntity.isDirectorySync(this);

  bool isFile() => FileSystemEntity.isFileSync(this);

  bool isLink() => FileSystemEntity.isLinkSync(this);

  bool exists() =>
      FileSystemEntity.typeSync(this) != FileSystemEntityType.notFound;

  void delete() {
    // deleteSync() throws an exception if the file does not exist.
    if (exists()) {
      // [deleteSync] works on all [FileSystemEntity] types when [recursive] is true.
      File(this).deleteSync(recursive: true);
    }
  }

  List<String> readLines() => File(this).readAsLinesSync();

  void copyTo(String path) {
    if (isFile() || isLink()) {
      path.parent.createDir();
      File(this).copySync(path);
    } else if (isDirectory()) {
      _copyDirectory(Directory(this), Directory(path));
    }
  }

  void _copyDirectory(Directory srcDir, Directory destDir) {
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }

    srcDir.listSync(recursive: false).forEach((entity) {
      final newPath = join(destDir.path, basename(entity.path));
      if (entity is File) {
        entity.copySync(newPath);
      } else if (entity is Directory) {
        _copyDirectory(entity, Directory(newPath));
      }
    });
  }

  void moveTo(String path) {
    try {
      File(this).renameSync(path);
    } on FileSystemException {
      // This will work even when [path] is at a different drive.
      if (isFile()) {
        copyTo(path);
        delete();
      } else if (isDirectory()) {
        _copyDirectory(Directory(this), Directory(path));
        delete();
      }
    }
  }

  void clear() {
    if (isFile() || isLink()) {
      File(this).writeAsStringSync('', flush: true);
    } else if (isDirectory()) {
      Directory(this).listSync(recursive: true).forEach((entity) {
        // [deleteSync] works on all [FileSystemEntity] types when [recursive] is true.
        entity.deleteSync(recursive: true);
      });
    }
  }

  void write(String s, {bool clearFirst = false}) =>
      File(this).writeAsStringSync(
        s,
        mode: clearFirst ? FileMode.write : FileMode.append,
        flush: true,
      );

  void writeln(String s, {String? newLine, bool append = true}) =>
      File(this).writeAsStringSync(
        '$s${newLine ?? _lineTerminator}',
        mode: append ? FileMode.append : FileMode.write,
        flush: true,
      );

  List<String> find(String glob) {
    final r = <String>[];
    final d = Directory(this);
    final g = Glob(glob);
    if (d.existsSync()) {
      for (final e in d.listSync(recursive: true)) {
        final s = relative(e.path, from: d.path);
        if (g.matches(s)) {
          r.add(join(this, s));
        }
      }
    }
    return r;
  }

  bool touch() {
    final file = File(this);
    if (Platform.isWindows) {
      try {
        if (file.existsSync()) {
          final now = DateTime.timestamp();
          file.setLastAccessedSync(now);
          file.setLastModifiedSync(now);
        } else {
          if (file.parent.existsSync()) {
            file.createSync();
          }
        }
      } catch (e) {
        stderr.writeln(e);
        return false;
      }
      return true;
    } else {
      return ['touch', this].run(showCommand: false, showMessages: false).ok;
    }
  }

  DateTime get lastModified => File(this).lastModifiedSync();

  bool isNewerThan(String other) => lastModified.isAfter(other.lastModified);

  bool isOlderThan(String other) => lastModified.isBefore(other.lastModified);

  void create() {
    File(this).createSync(recursive: true);
  }

  void createDir() {
    Directory(this).createSync(recursive: true);
  }

  String get parent => dirname(this);
}

// Also good for tear-off
void create(String path) {
  path.create();
}

// Also good for tear-off
void createDir(String path) {
  path.createDir();
}

// Also good for tear-off
void delete(String path) {
  path.delete();
}

// Also good for tear-off
bool touch(String path) {
  return path.touch();
}

extension FileExt on File {
  void clear() => writeAsStringSync('');

  void write(String s, {bool clearFirst = false}) => writeAsStringSync(
    s,
    mode: clearFirst ? FileMode.write : FileMode.append,
    flush: true,
  );

  void writeln(String s, {String? newLine, bool clearFirst = false}) =>
      writeAsStringSync(
        '$s${newLine ?? _lineTerminator}',
        mode: clearFirst ? FileMode.write : FileMode.append,
        flush: true,
      );
}

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
    final type = FileSystemEntity.typeSync(this);
    switch (type) {
      case FileSystemEntityType.file:
      case FileSystemEntityType.link:
        File(this).copyTo(File(path));
      case FileSystemEntityType.directory:
        Directory(this).copyTo(Directory(path));
      case FileSystemEntityType.notFound:
        throw FileSystemException('File or directory not found', this);
      default:
        throw UnimplementedError('Unsupported file system entity type: $type');
    }
  }

  void moveTo(String path) {
    final type = FileSystemEntity.typeSync(this);
    switch (type) {
      case FileSystemEntityType.file:
      case FileSystemEntityType.link:
        try {
          File(this).renameSync(path);
        } on FileSystemException {
          copyTo(path);
          delete();
        }
      case FileSystemEntityType.directory:
        try {
          Directory(this).renameSync(path);
        } on FileSystemException {
          Directory(this).copyTo(Directory(path));
          delete();
        }
      case FileSystemEntityType.notFound:
        throw FileSystemException('File or directory not found', this);
      default:
        throw UnimplementedError('Unsupported file system entity type: $type');
    }
  }

  void clear() {
    final type = FileSystemEntity.typeSync(this);
    switch (type) {
      case FileSystemEntityType.file:
      case FileSystemEntityType.link:
        File(this).clear();
      case FileSystemEntityType.directory:
        Directory(this).clear();
      case FileSystemEntityType.notFound:
        throw FileSystemException('File or directory not found', this);
      default:
        throw UnimplementedError('Unsupported file system entity type: $type');
    }
  }

  void write(String s, {bool clearFirst = false}) =>
      File(this).write(s, clearFirst: clearFirst);

  void writeln(String s, {String? newLine, bool clearFirst = true}) =>
      File(this).writeln(s, newLine: newLine, clearFirst: clearFirst);

  List<String> find(String glob) =>
      Directory(this).find(glob).map((e) => e.path).toList();

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

File _getReal(File file) {
  final type = FileSystemEntity.typeSync(file.path);
  final real = switch (type) {
    FileSystemEntityType.directory => throw FileSystemException(
      'Is a directory',
      file.path,
    ),
    FileSystemEntityType.link => File(file.resolveSymbolicLinksSync()),
    FileSystemEntityType.notFound || FileSystemEntityType.file => file,
    _ => throw UnimplementedError('Unsupported file system entity type: $type'),
  };
  real.parent.createSync(recursive: true);
  return real;
}

extension FileExt on File {
  void copyTo(File file) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('File not found', path);
    } else if (type == FileSystemEntityType.directory) {
      throw FileSystemException('Is a directory', path);
    } else if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.link) {
      throw UnimplementedError('Unsupported file system entity type: $type');
    }
    copySync(_getReal(file).path);
  }

  void clear() {
    _getReal(this).writeAsStringSync('', flush: true);
  }

  void write(String s, {bool clearFirst = false}) {
    _getReal(this).writeAsStringSync(
      s,
      mode: clearFirst ? FileMode.write : FileMode.append,
      flush: true,
    );
  }

  void writeln(String s, {String? newLine, bool clearFirst = false}) {
    _getReal(this).writeAsStringSync(
      '$s${newLine ?? _lineTerminator}',
      mode: clearFirst ? FileMode.write : FileMode.append,
      flush: true,
    );
  }
}

void _copyDirectory(
  Directory srcDir,
  Directory destDir,
  Directory root, {
  bool keepLinks = true,
}) {
  if (!destDir.existsSync()) {
    destDir.createSync(recursive: true);
  }

  srcDir.listSync(recursive: false).forEach((entity) {
    final newPath = join(destDir.path, basename(entity.path));
    if (entity is File) {
      entity.copySync(newPath);
    } else if (entity is Link) {
      final target = File(entity.resolveSymbolicLinksSync());
      if (!isWithin(root.path, target.path) && !keepLinks) {
        if (target.existsSync()) {
          target.copySync(newPath);
          return;
        }
      }
      var link = entity.targetSync();
      if (isAbsolute(link) && isWithin(root.path, link)) {
        link = absolute(join(destDir.path, relative(link, from: srcDir.path)));
      }
      Link(newPath).createSync(link);
    } else if (entity is Directory) {
      _copyDirectory(entity, Directory(newPath), root);
    }
  });
}

extension DirectoryExt on Directory {
  void copyTo(Directory directory, {bool keepLinks = true}) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('Directory not found', path);
    } else if (type == FileSystemEntityType.file ||
        type == FileSystemEntityType.link) {
      throw FileSystemException('Is a file', path);
    } else if (type != FileSystemEntityType.directory) {
      throw UnimplementedError('Unsupported file system entity type: $type');
    }
    if (!FileSystemEntity.isDirectorySync(directory.path)) {
      throw FileSystemException('Is not a directory', directory.path);
    }
    _copyDirectory(this, directory, this, keepLinks: keepLinks);
  }

  void clear() {
    listSync().forEach((entity) {
      // [deleteSync] works on all [FileSystemEntity] types when [recursive] is true.
      entity.deleteSync(recursive: true);
    });
  }

  List<FileSystemEntity> find(String glob) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('Directory not found', path);
    } else if (type != FileSystemEntityType.directory) {
      throw FileSystemException('Is not a directory', path);
    }
    final r = <FileSystemEntity>[];
    final g = Glob(glob);
    for (final e in listSync(recursive: true)) {
      final s = relative(e.path, from: path);
      if (g.matches(s)) {
        r.add(e);
      }
    }
    return r;
  }
}

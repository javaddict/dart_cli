import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart';

import 'process.dart';

// In MSYS2, we use '\n' as the line terminator.
final _lineTerminator = Platform.isWindows && env['SHELL'] != null
    ? '\n'
    : Platform.lineTerminator;

(FileSystemEntity?, FileSystemEntityType) _resolve(Link link) {
  final target = link.resolveSymbolicLinksSync();
  final type = FileSystemEntity.typeSync(target);
  if (type == FileSystemEntityType.file ||
      type == FileSystemEntityType.notFound) {
    return (File(target), type);
  } else if (type == FileSystemEntityType.directory) {
    return (Directory(target), type);
  } else {
    return (null, type);
  }
}

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
        File(this).copyTo(File(path), checked: true);
      case FileSystemEntityType.link:
        final (target, type) = _resolve(Link(this));
        if (target is File && type != FileSystemEntityType.notFound) {
          target.copyTo(File(path), checked: true);
        } else if (target is Directory) {
          target.copyTo(Directory(path), checked: true);
        }
      case FileSystemEntityType.directory:
        Directory(this).copyTo(Directory(path), checked: true);
      case FileSystemEntityType.notFound:
        throw FileSystemException('File or directory not found', this);
      default:
        throw UnsupportedError('Unsupported file system entity type: $type');
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
        throw UnsupportedError('Unsupported file system entity type: $type');
    }
  }

  void clear() {
    final type = FileSystemEntity.typeSync(this);
    switch (type) {
      case FileSystemEntityType.file:
      case FileSystemEntityType.link:
      case FileSystemEntityType.notFound:
        File(this).clear();
      case FileSystemEntityType.directory:
        Directory(this).clear();
      default:
        throw UnsupportedError('Unsupported file system entity type: $type');
    }
  }

  void write(String s, {bool clearFirst = false, bool flush = false}) =>
      File(this).write(s, clearFirst: clearFirst, flush: flush);

  void writeln(String s, {bool clearFirst = false, bool flush = false}) =>
      File(this).writeln(s, clearFirst: clearFirst, flush: flush);

  void flush() => File(this).flush();

  List<String> find(String glob) =>
      Directory(this).find(glob).map((e) => e.path).toList();

  IOSink get async => File(this).async;

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

final Map<String, File> _realFileCache = {};

File _getReal(File file) {
  final cacheKey = file.path;
  final cached = _realFileCache[cacheKey];
  if (cached != null) {
    return cached;
  }

  final type = FileSystemEntity.typeSync(file.path);
  final File real;
  switch (type) {
    case FileSystemEntityType.directory:
      throw FileSystemException('Is a directory', file.path);
    case FileSystemEntityType.link:
      final (resolved, type) = _resolve(Link(file.path));
      if (resolved is File) {
        real = resolved;
      } else if (resolved is Directory) {
        throw FileSystemException('Is a directory', file.path);
      } else {
        throw UnsupportedError('Unsupported file system entity type: $type');
      }
    case FileSystemEntityType.notFound || FileSystemEntityType.file:
      real = file;
    default:
      throw UnsupportedError('Unsupported file system entity type: $type');
  }
  real.parent.createSync(recursive: true);
  _realFileCache[cacheKey] = real;
  return real;
}

final Map<String, IOSink> _sinks = {};
final Map<String, bool> _sinksClosed = {};

extension FileExt on File {
  void copyTo(File file, {bool checked = false}) {
    if (!checked) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.notFound) {
        throw FileSystemException('File not found', path);
      } else if (type == FileSystemEntityType.directory) {
        throw FileSystemException('Is a directory', path);
      } else if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.link) {
        throw UnsupportedError('Unsupported file system entity type: $type');
      }
    }
    copySync(_getReal(file).path);
  }

  void clear() {
    _getReal(this).writeAsStringSync('', flush: true);
  }

  void write(String s, {bool clearFirst = false, bool flush = false}) {
    _getReal(this).writeAsStringSync(
      s,
      mode: clearFirst ? FileMode.write : FileMode.append,
      flush: flush,
    );
  }

  void writeln(String s, {bool clearFirst = false, bool flush = false}) {
    _getReal(this).writeAsStringSync(
      '$s$_lineTerminator',
      mode: clearFirst ? FileMode.write : FileMode.append,
      flush: flush,
    );
  }

  void flush() {
    _getReal(this).writeAsStringSync('', mode: FileMode.append, flush: true);
  }

  IOSink get async {
    final file = _getReal(this);
    final path = absolute(file.path);
    var sink = _sinks[path];
    final isClosed = _sinksClosed[path] ?? false;

    if (sink == null || isClosed) {
      sink = file.openWrite(mode: FileMode.append);
      _sinks[path] = sink;
      _sinksClosed[path] = false;

      // Track when sink is closed
      sink.done.then((_) => _sinksClosed[path] = true);
    }

    return sink;
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
      final resolved = entity.resolveSymbolicLinksSync();
      final type = FileSystemEntity.typeSync(resolved);
      if (!isWithin(root.path, resolved) && !keepLinks) {
        if (type == FileSystemEntityType.file) {
          File(resolved).copySync(newPath);
        } else if (type == FileSystemEntityType.directory) {
          _copyDirectory(
            Directory(resolved),
            Directory(newPath),
            root,
            keepLinks: keepLinks,
          );
        }
        return;
      }
      var target = entity.targetSync();
      if (isAbsolute(target) && isWithin(root.path, target)) {
        target = absolute(
          join(destDir.path, relative(target, from: srcDir.path)),
        );
      }
      Link(newPath).createSync(target);
    } else if (entity is Directory) {
      _copyDirectory(entity, Directory(newPath), root, keepLinks: keepLinks);
    }
  });
}

extension DirectoryExt on Directory {
  void copyTo(
    Directory directory, {
    bool keepLinks = true,
    bool checked = false,
  }) {
    if (!checked) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.notFound) {
        throw FileSystemException('Directory not found', path);
      } else if (type == FileSystemEntityType.file ||
          type == FileSystemEntityType.link) {
        throw FileSystemException('Is a file', path);
      } else if (type != FileSystemEntityType.directory) {
        throw UnsupportedError('Unsupported file system entity type: $type');
      }
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';

bool forceSilent = false;

class _EnvironmentVariables {
  final Map<String, String> _map0 = Platform.environment;
  Map<String, String> _map1 = {};

  String? operator [](String key) => _map1[key] ?? _map0[key];

  void operator []=(String key, String value) {
    if (_map0[key] != value) {
      _map1[key] = value;
    } else {
      _map1.remove(key);
    }
  }

  void unset(String key) {
    _map1.remove(key);
  }

  final pathSeparator = Platform.isWindows ? ';' : ':';

  void prependToPATH(String path) {
    env['PATH'] = '$path${env.pathSeparator}${env['PATH']}';
  }
}

final env = _EnvironmentVariables();

// Not thread-safe.
void set(Map<String, String> overrides, Function() toDo) {
  final saved = <String, String>{...env._map1};
  for (final MapEntry(:key, :value) in overrides.entries) {
    env[key] = value;
  }
  toDo();
  env._map1 = saved;
}

String? _workingDirectory;

// Not thread-safe.
void cd(String path, Function() toDo) {
  final saved = _workingDirectory;
  _workingDirectory = path;
  toDo();
  _workingDirectory = saved;
}

Stream<List<int>> _stdin = stdin.asBroadcastStream();

extension CommandParts on List<String> {
  ProcessResult run({
    String? at,
    bool showCommand = true,
    bool showMessages = true,
    bool runInShell = false,
  }) {
    if (isEmpty) {
      throw ArgumentError('The command can not be empty.');
    }
    if (!forceSilent && showCommand) {
      stdout.writeln(concatenate());
    }
    final r = Process.runSync(
      this[0],
      getRange(1, length).toList(),
      workingDirectory: at ?? _workingDirectory,
      environment: env._map1,
      runInShell: runInShell,
    );
    if (!forceSilent) {
      if (showMessages && r.stdout != '') {
        stdout.writeln(r.stdout);
      }
      if (showMessages && r.stderr != '') {
        stderr.writeln(r.stderr);
      }
    }
    return r;
  }

  /// Use of [interactive] with true must explicitly terminate itself at the end
  /// of [main]. (https://github.com/dart-lang/sdk/issues/45098)
  Future<ProcessResult> running({
    String? at,
    bool showCommand = true,
    bool showMessages = true,
    bool saveMessages = false,
    (StreamConsumer<String>?, StreamConsumer<String>?) redirectMessages = (
      null,
      null,
    ),
    bool runInShell = false,
    List<String> input = const [],
    bool interactive = false,
  }) async {
    if (isEmpty) {
      throw ArgumentError('The command can not be empty.');
    }
    if (!forceSilent && showCommand) {
      stdout.writeln(concatenate());
    }
    final p = await Process.start(
      this[0],
      getRange(1, length).toList(),
      workingDirectory: at ?? _workingDirectory,
      environment: env._map1,
      runInShell: runInShell,
    );
    for (final s in input) {
      p.stdin.writeln(s);
    }
    final outBuf = StringBuffer();
    final errBuf = StringBuffer();
    for (final e in [
      (p.stdout, stdout, redirectMessages.$1, outBuf),
      (p.stderr, stderr, redirectMessages.$2, errBuf),
    ]) {
      final (src, std, redirect, buf) = e;
      final decodedSrc = src
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter());
      if (redirect == null && !saveMessages) {
        if (!forceSilent && showMessages) {
          decodedSrc.listen((line) {
            std.writeln(line);
          });
        } else {
          decodedSrc.drain();
        }
      } else {
        var s0 = decodedSrc;
        if (!forceSilent && showMessages) {
          final [s00, s01] = StreamSplitter.splitFrom(s0);
          s00.listen((line) {
            std.writeln(line);
          });
          s0 = s01;
        }
        final s1 = s0;
        if (redirect != null && saveMessages) {
          final [s10, s11] = StreamSplitter.splitFrom(s1);
          s10.pipe(redirect);
          s11.listen((line) {
            buf.writeln(line);
          });
        } else if (redirect != null) {
          s1.pipe(redirect);
        } else {
          s1.listen((line) {
            buf.writeln(line);
          });
        }
      }
    }
    int exitCode;
    if (interactive) {
      final scription = _stdin.listen((List<int> data) {
        if (data.isNotEmpty) {
          p.stdin.add(data);
        }
      });
      exitCode = await p.exitCode;
      await scription.cancel();
    } else {
      exitCode = await p.exitCode;
    }
    return ProcessResult(p.pid, exitCode, outBuf.toString(), errBuf.toString());
  }

  String concatenate() {
    String quoteIfNecessary(String part) =>
        part.contains(' ') ? '"${part.replaceAll('"', '\\"')}"' : part;

    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      if (i > 0) {
        sb.write(' ');
      }
      sb.write(quoteIfNecessary(this[i]));
    }
    return sb.toString();
  }
}

extension Command on String {
  ProcessResult run({
    String? at,
    bool showCommand = true,
    bool showMessages = true,
  }) {
    if (!forceSilent && showCommand) {
      stdout.writeln(this);
    }
    return [
      // We don't use cmd.exe in MSYS2.
      env['SHELL'] ?? 'cmd.exe',
      env['SHELL'] != null ? '-c' : '/c',
      this,
    ].run(
      at: at,
      showCommand: false,
      showMessages: showMessages,
      runInShell: false,
    );
  }

  /// Use of [interactive] with true must explicitly terminate itself at the end
  /// of [main]. (https://github.com/dart-lang/sdk/issues/45098)
  Future<ProcessResult> running({
    String? at,
    bool showCommand = true,
    bool showMessages = true,
    bool saveMessages = false,
    (StreamConsumer<String>?, StreamConsumer<String>?) redirectMessages = (
      null,
      null,
    ),
    List<String> input = const [],
    bool interactive = false,
  }) {
    if (!forceSilent && showCommand) {
      stdout.writeln(this);
    }
    return [
      // We don't use cmd.exe in MSYS2.
      env['SHELL'] ?? 'cmd.exe',
      env['SHELL'] != null ? '-c' : '/c',
      this,
    ].running(
      at: at,
      showCommand: false,
      showMessages: showMessages,
      saveMessages: saveMessages,
      redirectMessages: redirectMessages,
      runInShell: false,
      input: input,
      interactive: interactive,
    );
  }

  List<String> separate() {
    final list = <String>[];
    String? quote;
    var i = 0;
    int j;
    for (j = 0; j < length; j++) {
      final c = this[j];
      if (c == '\\') {
        j++;
      } else if (quote == null && (c == '\'' || c == '"')) {
        quote = c;
      } else if (c == quote) {
        quote = null;
      } else if (c == ' ') {
        if (quote == null) {
          list.add(substring(i, j));
          i = j + 1;
        }
      }
    }
    list.add(substring(i, j));
    list.retainWhere((s) => s.isNotEmpty);
    return list;
  }
}

final _lineTerminatorRegExp = RegExp('(?:\n|\r\n)');

extension ProcessResultExt on ProcessResult {
  List<String> get outputs {
    if (this.stdout == null) {
      return [];
    }
    final s = this.stdout as String;
    return s.isEmpty ? [] : s.split(_lineTerminatorRegExp)
      ..removeLast();
  }

  List<String> get errors {
    final s = this.stderr as String;
    return s.isEmpty ? [] : s.split(_lineTerminatorRegExp)
      ..removeLast();
  }

  String get output {
    final list = outputs;
    return list.isEmpty ? '' : list[0];
  }

  String get error {
    final list = errors;
    return list.isEmpty ? '' : list[0];
  }

  bool get ok => this.exitCode == 0;
}

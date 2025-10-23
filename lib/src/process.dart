import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:process_run/process_run.dart';

bool defaultShowCommand = true;
bool defaultShowMessages = true;
bool defaultRunInShell = false;

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
    bool? showCommand,
    bool? showMessages,
    bool? runInShell,
  }) {
    showCommand ??= defaultShowCommand;
    showMessages ??= defaultShowMessages;
    runInShell ??= defaultRunInShell;
    if (isEmpty) {
      throw ArgumentError('The command can not be empty.');
    }
    if (showCommand) {
      stdout.writeln(concatenate());
    }
    final List<String> cmd;
    if (runInShell) {
      // due to the bug of [runInShell] in [Process.runSync]
      cmd = [env['SHELL'] ?? env['COMSPEC'] ?? '/bin/sh'];
      if (cmd[0].contains('cmd.exe')) {
        cmd.add('/c');
        cmd.add(concatenate());
      } else {
        cmd.add('-c');
        cmd.add(map((s) => "'${s.replaceAll("'", "'\"'\"'")}'").join(' '));
      }
    } else {
      cmd = this;
    }
    final r = Process.runSync(
      cmd[0],
      cmd.getRange(1, cmd.length).toList(),
      workingDirectory: at ?? _workingDirectory,
      environment: env._map1,
      runInShell: false,
      stdoutEncoding: runInShell ? systemEncoding : utf8,
      stderrEncoding: runInShell ? systemEncoding : utf8,
    );
    if (showMessages && r.stdout != '') {
      stdout.writeln(r.stdout);
    }
    if (showMessages && r.stderr != '') {
      stderr.writeln(r.stderr);
    }
    return r;
  }

  /// Use of [interactive] with true must explicitly terminate itself at the end
  /// of [main]. (https://github.com/dart-lang/sdk/issues/45098)
  Future<ProcessResult> running({
    String? at,
    bool? showCommand,
    bool? showMessages,
    bool saveMessages = false,
    (StreamConsumer<String>?, StreamConsumer<String>?) redirectMessages = (
      null,
      null,
    ),
    List<String> input = const [],
    bool interactive = false,
    bool? runInShell,
  }) async {
    showCommand ??= defaultShowCommand;
    showMessages ??= defaultShowMessages;
    runInShell ??= defaultRunInShell;
    if (isEmpty) {
      throw ArgumentError('The command can not be empty.');
    }
    if (showCommand) {
      stdout.writeln(concatenate());
    }
    final List<String> cmd;
    if (runInShell) {
      // due to the bug of [runInShell] in [Process.runSync]
      cmd = [env['SHELL'] ?? env['COMSPEC'] ?? '/bin/sh'];
      if (cmd[0].contains('cmd.exe')) {
        cmd.add('/c');
        cmd.add(concatenate());
      } else {
        cmd.add('-c');
        cmd.add(map((s) => "'${s.replaceAll("'", "'\"'\"'")}'").join(' '));
      }
    } else {
      cmd = this;
    }
    final p = await Process.start(
      cmd[0],
      cmd.getRange(1, cmd.length).toList(),
      workingDirectory: at ?? _workingDirectory,
      environment: env._map1,
      runInShell: false,
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
      final decodedSrc = src.transform(
        runInShell ? systemEncoding.decoder : utf8.decoder,
      );
      if (redirect == null && !saveMessages) {
        if (showMessages) {
          decodedSrc.listen((s) {
            std.write(s);
          });
        } else {
          decodedSrc.drain();
        }
      } else {
        var s0 = decodedSrc;
        if (showMessages) {
          final [s00, s01] = StreamSplitter.splitFrom(s0);
          s00.listen((s) {
            std.write(s);
          });
          s0 = s01;
        }
        final s1 = s0;
        if (redirect != null && saveMessages) {
          final [s10, s11] = StreamSplitter.splitFrom(s1);
          s10.pipe(redirect);
          s11.listen((s) {
            buf.write(s);
          });
        } else if (redirect != null) {
          s1.pipe(redirect);
        } else {
          s1.listen((s) {
            buf.write(s);
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

  String concatenate() => argumentsToString(this);
}

extension Command on String {
  ProcessResult run({
    String? at,
    bool? showCommand,
    bool? showMessages,
    bool? runInShell,
  }) {
    showCommand ??= defaultShowCommand;
    showMessages ??= defaultShowMessages;
    runInShell ??= defaultRunInShell;
    if (showCommand) {
      stdout.writeln(this);
    }
    final List<String> cmd;
    if (runInShell) {
      // due to the bug of [runInShell] in [Process.runSync]
      cmd = [env['SHELL'] ?? env['COMSPEC'] ?? '/bin/sh'];
      if (cmd[0].contains('cmd.exe')) {
        cmd.add('/c');
      } else {
        cmd.add('-c');
      }
      cmd.add(this);
    } else {
      cmd = separate();
    }
    return cmd.run(
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
    bool? showCommand,
    bool? showMessages,
    bool saveMessages = false,
    (StreamConsumer<String>?, StreamConsumer<String>?) redirectMessages = (
      null,
      null,
    ),
    List<String> input = const [],
    bool interactive = false,
    bool? runInShell,
  }) {
    showCommand ??= defaultShowCommand;
    showMessages ??= defaultShowMessages;
    runInShell ??= defaultRunInShell;
    if (showCommand) {
      stdout.writeln(this);
    }
    final List<String> cmd;
    if (runInShell) {
      // due to the bug of [runInShell] in [Process.runSync]
      cmd = [env['SHELL'] ?? env['COMSPEC'] ?? '/bin/sh'];
      if (cmd[0].contains('cmd.exe')) {
        cmd.add('/c');
      } else {
        cmd.add('-c');
      }
      cmd.add(this);
    } else {
      cmd = separate();
    }
    return cmd.running(
      at: at,
      showCommand: false,
      showMessages: showMessages,
      saveMessages: saveMessages,
      redirectMessages: redirectMessages,
      input: input,
      interactive: interactive,
      runInShell: false,
    );
  }

  List<String> separate() => stringToArguments(this);
}

final _lineTerminatorRegExp = RegExp('(?:\n|\r\n)');

extension ProcessResultExt on ProcessResult {
  List<String> get outputs {
    if (this.stdout == null) {
      return [];
    }
    var s = this.stdout as String;
    if (s.endsWith(Platform.isWindows ? '\r\n' : '\n')) {
      s = s.substring(0, s.length - (Platform.isWindows ? 2 : 1));
    }
    return s.isEmpty ? [] : (s.split(_lineTerminatorRegExp));
  }

  List<String> get errors {
    var s = this.stderr as String;
    if (s.endsWith(Platform.isWindows ? '\r\n' : '\n')) {
      s = s.substring(0, s.length - (Platform.isWindows ? 2 : 1));
    }
    return s.isEmpty ? [] : (s.split(_lineTerminatorRegExp));
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

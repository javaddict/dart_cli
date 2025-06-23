import 'dart:async';
import 'dart:io';

import 'package:dart_console/dart_console.dart';

class AnsiSpinner {
  final _console = Console();
  int _ticks = 0;
  Timer? _timer;
  final List<String> _animation;

  AnsiSpinner()
    : _animation = Platform.isWindows
          ? <String>[r'-', r'\', r'|', r'/']
          : <String>['⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷'];

  void start() {
    _console.hideCursor();
    stdout.write(' ');
    _timer = Timer.periodic(const Duration(milliseconds: 100), _advance);
    _advance(_timer!);
  }

  void print() {
    stdout.write('\x1b[38;5;1m${_animation[_ticks]}\x1b[0m');
  }

  void _advance(Timer timer) {
    _console.cursorLeft();
    print();
    _ticks = (_ticks + 1) % _animation.length;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _console.cursorLeft();
    _console
        .eraseCursorToEnd(); // Erase from the cursor position to the end of the line.
    _console.showCursor();
  }
}

String ask(
  String question, {
  List<String> options = const [],
  List<String> descriptions = const [],
  String? defaultAnswer,
  bool Function(String)? check,
}) {
  assert(descriptions.isEmpty || descriptions.length == options.length);
  assert(
    options.isEmpty || defaultAnswer == null || options.contains(defaultAnswer),
  );
  while (true) {
    final detailedOptions = <String>[];
    if (options.isNotEmpty) {
      for (var i = 0; i < options.length; i++) {
        detailedOptions.add(
          '(\u001B[1m${options[i]}\u001B[0m)${i < descriptions.length ? descriptions[i] : ''}',
        );
      }
    }
    stdout.write(
      '$question '
      '${options.isNotEmpty ? '[${detailedOptions.join('/')}] ' : ''}'
      '${defaultAnswer != null ? '($defaultAnswer) ' : ''}',
    );
    String? answer = stdin.readLineSync();
    if (answer == null || answer.isEmpty) {
      if (defaultAnswer != null) {
        return defaultAnswer;
      }
    } else {
      if (options.isEmpty) {
        if (check == null || check(answer)) {
          return answer.trim();
        }
      } else {
        if (options.any((o) => o.toLowerCase() == answer.toLowerCase())) {
          return answer.trim();
        }
      }
    }
  }
}

import 'package:test/test.dart';
import 'package:dart_cli/src/process.dart';

void main() {
  group('separate() function', () {
    test('simple command without quotes', () {
      expect('ls -la'.separate(), equals(['ls', '-la']));
    });

    test('command with multiple spaces', () {
      expect('ls  -la   /tmp'.separate(), equals(['ls', '-la', '/tmp']));
    });

    test('command with single quotes', () {
      expect("echo 'hello world'".separate(), equals(['echo', 'hello world']));
    });

    test('command with double quotes', () {
      expect('echo "hello world"'.separate(), equals(['echo', 'hello world']));
    });

    test('command with mixed quotes', () {
      expect(
        'cmd "arg1" \'arg2\' arg3'.separate(),
        equals(['cmd', 'arg1', 'arg2', 'arg3']),
      );
    });

    test('escaped double quote inside double quotes', () {
      expect(
        r'echo "hello \"world\""'.separate(),
        equals(['echo', 'hello "world"']),
      );
    });

    test('double backslash outside quotes', () {
      expect(r'cmd \\ arg'.separate(), equals(['cmd', r'\', 'arg']));
    });

    test('single backslash for line continuation (ignored)', () {
      expect(r'cmd \a\rg'.separate(), equals(['cmd', 'arg']));
    });

    test('empty string', () {
      expect(''.separate(), equals([]));
    });

    test('only spaces', () {
      expect('   '.separate(), equals([]));
    });

    test('single word', () {
      expect('word'.separate(), equals(['word']));
    });

    test('quoted empty string', () {
      expect('cmd "" arg'.separate(), equals(['cmd', '', 'arg']));
    });

    test('unclosed quote', () {
      expect('cmd "unclosed'.separate(), equals(['cmd', 'unclosed']));
    });

    test('nested quotes (different types)', () {
      expect(
        'echo "it\'s working"'.separate(),
        equals(['echo', "it's working"]),
      );
    });

    test('multiple arguments with quotes', () {
      expect(
        'git commit -m "Initial commit" --author "John Doe"'.separate(),
        equals([
          'git',
          'commit',
          '-m',
          'Initial commit',
          '--author',
          'John Doe',
        ]),
      );
    });

    test('path with spaces in quotes', () {
      expect(
        'cp "file with spaces.txt" "/destination/path/"'.separate(),
        equals(['cp', 'file with spaces.txt', '/destination/path/']),
      );
    });

    test('backslash in single quotes (not escaped)', () {
      expect(r"echo 'C:\path'".separate(), equals(['echo', r'C:\path']));
    });

    test('command starting with quote', () {
      expect(
        '"program with space" arg'.separate(),
        equals(['program with space', 'arg']),
      );
    });

    test('consecutive quotes', () {
      expect('cmd ""'.separate(), equals(['cmd', '']));
    });

    test('single character arguments', () {
      expect('a b c d'.separate(), equals(['a', 'b', 'c', 'd']));
    });

    test('special characters without quotes', () {
      expect(
        'cmd arg1@test arg2#value'.separate(),
        equals(['cmd', 'arg1@test', 'arg2#value']),
      );
    });

    test('trailing spaces', () {
      expect('cmd arg  '.separate(), equals(['cmd', 'arg']));
    });

    test('leading spaces', () {
      expect('  cmd arg'.separate(), equals(['cmd', 'arg']));
    });

    test('complex real-world command', () {
      expect(
        'docker run -v "/host/path:/container/path" --name "my container" image:tag'
            .separate(),
        equals([
          'docker',
          'run',
          '-v',
          '/host/path:/container/path',
          '--name',
          'my container',
          'image:tag',
        ]),
      );
    });
  });
}

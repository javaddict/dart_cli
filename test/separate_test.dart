import 'package:test/test.dart';
import 'package:dart_cli/src/process.dart';

void main() {
  group('separate() function', () {
    test('empty string', () {
      expect(''.separate(), equals([]));
    });

    test('only spaces', () {
      expect('   '.separate(), equals([]));
    });

    test('no spaces', () {
      expect('word'.separate(), equals(['word']));
    });

    test('single space without quotes', () {
      expect(' ls -la '.separate(), equals(['ls', '-la']));
    });

    test('multiple spaces without quotes', () {
      expect('  ls  -la  /tmp  '.separate(), equals(['ls', '-la', '/tmp']));
    });

    test('single quotes', () {
      expect(
        " ' program  with ' space 'arg1 arg2' ".separate(),
        equals([' program  with ', 'space', 'arg1 arg2']),
      );
    });

    test('double quotes', () {
      expect(
        ' " program  with " space "arg1 arg2" '.separate(),
        equals([' program  with ', 'space', 'arg1 arg2']),
      );
    });

    test('explicit empty', () {
      expect(
        "\"\" cmd '' arg \"\"".separate(),
        equals(['', 'cmd', '', 'arg', '']),
      );
    });

    test('double quotes inside single quotes', () {
      expect(
        "echo 'hello \"world\"'".separate(),
        equals(['echo', 'hello "world"']),
      );
    });

    test('single quotes inside double quotes', () {
      expect(
        'echo "hello \'world\'"'.separate(),
        equals(['echo', "hello 'world'"]),
      );
    });

    test('escaped double quote inside double quotes', () {
      expect(
        r'echo "hello \"world\""'.separate(),
        equals(['echo', 'hello "world"']),
      );
    });

    test('single backslash inside single quotes', () {
      expect(
        "echo 'hello world\\n'".separate(),
        equals(['echo', r'hello world\n']),
      );
    });

    test('single backslash inside double quotes', () {
      expect(
        r'echo "hello world\n"'.separate(),
        equals(['echo', r'hello world\n']),
      );
    });

    test('double backslash outside quotes', () {
      expect(r'cmd \\n arg'.separate(), equals(['cmd', r'\n', 'arg']));
    });

    test('single backslash for line continuation (ignored)', () {
      expect(r'cmd \a\rg'.separate(), equals(['cmd', 'arg']));
    });

    test('unclosed quote', () {
      expect('cmd "unclosed'.separate(), equals(['cmd', 'unclosed']));
    });

    test('quotes in words', () {
      expect(
        'echo hello" world"\' \''.separate(),
        equals(['echo', 'hello world ']),
      );
    });
  });
}

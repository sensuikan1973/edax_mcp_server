import 'package:dart_boilerplate/main.dart';
import 'package:test/test.dart';

void main() {
  test('hello', () {
    final sample = Sample();
    expect(sample.hello('bob'), 'hello bob');
  });
}

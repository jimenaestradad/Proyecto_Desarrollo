import 'package:flutter_test/flutter_test.dart';
import 'package:nori/utils/validators.dart';

void main() {
  test('usernames: letters, digits, underscore, 3-20 chars', () {
    expect(validateUsername('alex_habits'), isNull);
    expect(validateUsername('ab'), isNotNull);
    expect(validateUsername('a' * 21), isNotNull);
    expect(validateUsername('a/b'), isNotNull);
    expect(validateUsername("x'; DROP TABLE users;--"), isNotNull);
    expect(validateUsername('has space'), isNotNull);
  });

  test('emails need a local part, an @ and a dotted domain', () {
    expect(validateEmail('alex@example.com'), isNull);
    expect(validateEmail('a.b+tag@sub.example.co'), isNull);
    expect(validateEmail('alex'), isNotNull);
    expect(validateEmail('alex@example'), isNotNull);
    expect(validateEmail('a b@example.com'), isNotNull);
    expect(validateEmail('@example.com'), isNotNull);
  });

  test('passwords need 8+ characters with a letter and a number', () {
    expect(validateNewPassword('hunter22'), isNull);
    expect(validateNewPassword('short1'), isNotNull);
    expect(validateNewPassword('onlyletters'), isNotNull);
    expect(validateNewPassword('12345678'), isNotNull);
  });

  test('passwordChecks reports each rule on its own', () {
    var c = passwordChecks('');
    expect((c.longEnough, c.hasLetter, c.hasNumber), (false, false, false));
    c = passwordChecks('abc');
    expect((c.longEnough, c.hasLetter, c.hasNumber), (false, true, false));
    c = passwordChecks('12345678');
    expect((c.longEnough, c.hasLetter, c.hasNumber), (true, false, true));
    c = passwordChecks('hunter22');
    expect((c.longEnough, c.hasLetter, c.hasNumber), (true, true, true));
  });

  test('names reject markup and control characters', () {
    expect(validateName('Alex Human'), isNull);
    expect(validateName('  '), isNotNull);
    expect(validateName('<script>alert(1)</script>'), isNotNull);
    expect(validateName('a' * 51), isNotNull);
  });

  test('pet names: 1-20 characters, no markup', () {
    expect(validatePetName('Nori'), isNull);
    expect(validatePetName('   '), isNotNull);
    expect(validatePetName('a' * 21), isNotNull);
    expect(validatePetName('<b>x</b>'), isNotNull);
  });
}

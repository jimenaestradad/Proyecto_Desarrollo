import 'package:flutter/services.dart';

/// Form validators return a user-facing error or null for valid input.
/// Check document-id/profile text shape locally; server rules remain the real guard.

const usernameMinLength = 3;
const usernameMaxLength = 20;
const nameMaxLength = 50;
const passwordMinLength = 8;
const petNameMaxLength = 20;

final _usernamePattern = RegExp(r'^[A-Za-z0-9_]+$');
final _emailPattern = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$",
);
final _controlChars = RegExp(r'[\u0000-\u001F\u007F]');

String? validateName(String value) {
  final name = value.trim();
  if (name.isEmpty) return 'Enter your name.';
  if (name.length > nameMaxLength) {
    return 'Name must be $nameMaxLength characters or fewer.';
  }
  if (_controlChars.hasMatch(name) || name.contains(RegExp(r'[<>]'))) {
    return 'Name can\'t contain < > or control characters.';
  }
  return null;
}

String? validatePetName(String value) {
  final name = value.trim();
  if (name.isEmpty) return 'Give your pet a name.';
  if (name.length > petNameMaxLength) {
    return 'Pet names are $petNameMaxLength characters or fewer.';
  }
  if (_controlChars.hasMatch(name) || name.contains(RegExp(r'[<>]'))) {
    return 'Pet names can\'t contain < > or control characters.';
  }
  return null;
}

String? validateUsername(String value) {
  final username = value.trim();
  if (username.length < usernameMinLength) {
    return 'Username must be at least $usernameMinLength characters.';
  }
  if (username.length > usernameMaxLength) {
    return 'Username must be $usernameMaxLength characters or fewer.';
  }
  if (!_usernamePattern.hasMatch(username)) {
    return 'Username can only use letters, numbers and underscores.';
  }
  return null;
}

String? validateEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Enter your email.';
  if (email.length > 254 || !_emailPattern.hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

/// Which of the password rules [value] meets. The live checklist
/// (`PasswordRules`) and [validateNewPassword] both read this, so they can't
/// disagree about what is allowed.
({bool longEnough, bool hasLetter, bool hasNumber}) passwordChecks(
  String value,
) => (
  longEnough: value.length >= passwordMinLength,
  hasLetter: value.contains(RegExp(r'[A-Za-z]')),
  hasNumber: value.contains(RegExp(r'\d')),
);

String? validateNewPassword(String value) {
  final checks = passwordChecks(value);
  if (!checks.longEnough) {
    return 'Password must be at least $passwordMinLength characters.';
  }
  if (!checks.hasLetter || !checks.hasNumber) {
    return 'Password needs at least one letter and one number.';
  }
  return null;
}

/// Stops disallowed characters and over-long input at the keyboard, so the
/// username field can't hold anything [validateUsername] would reject.
final usernameInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
  LengthLimitingTextInputFormatter(usernameMaxLength),
];

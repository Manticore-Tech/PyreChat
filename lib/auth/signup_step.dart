enum SignupStep {
  displayName,
  username,
  birthday,
  password,
  terms,
}

extension SignupStepLabels on SignupStep {
  String get title {
    switch (this) {
      case SignupStep.displayName:
        return "What's your name?";
      case SignupStep.username:
        return 'Pick a username';
      case SignupStep.birthday:
        return 'When were you born?';
      case SignupStep.password:
        return 'Create a password';
      case SignupStep.terms:
        return 'Agree before joining';
    }
  }

  String? get subtitle {
    switch (this) {
      case SignupStep.displayName:
        return 'This is how friends will see you.';
      case SignupStep.username:
        return '3–24 letters, numbers, dots, or underscores.';
      case SignupStep.birthday:
        return 'You must be at least 13.';
      case SignupStep.password:
        return 'At least 8 characters.';
      case SignupStep.terms:
        return 'Review the Terms, Privacy Policy, and safety rules.';
    }
  }

  SignupStep? get next {
    switch (this) {
      case SignupStep.displayName:
        return SignupStep.username;
      case SignupStep.username:
        return SignupStep.birthday;
      case SignupStep.birthday:
        return SignupStep.password;
      case SignupStep.password:
        return SignupStep.terms;
      case SignupStep.terms:
        return null;
    }
  }

  SignupStep? get previous {
    switch (this) {
      case SignupStep.displayName:
        return null;
      case SignupStep.username:
        return SignupStep.displayName;
      case SignupStep.birthday:
        return SignupStep.username;
      case SignupStep.password:
        return SignupStep.birthday;
      case SignupStep.terms:
        return SignupStep.password;
    }
  }
}

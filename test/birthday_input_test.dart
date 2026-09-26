import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/auth/birthday_input.dart';

TextEditingValue _value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

void main() {
  const formatter = BirthdayInputFormatter();

  test('inserts birthday separators automatically', () {
    expect(
      formatter.formatEditUpdate(_value(''), _value('2001')).text,
      '2001-',
    );
    expect(
      formatter.formatEditUpdate(_value('2001-'), _value('2001-01')).text,
      '2001-01-',
    );
    expect(
      formatter.formatEditUpdate(_value('2001-01-'), _value('2001-01-30')).text,
      '2001-01-30',
    );
  });

  test('formats eight raw digits without user punctuation', () {
    expect(
      formatter.formatEditUpdate(_value(''), _value('20010130')).text,
      '2001-01-30',
    );
  });

  test('normalizes common pasted or autofilled birthday formats', () {
    expect(normalizeBirthdayInput('01/30/2001'), '2001-01-30');
    expect(normalizeBirthdayInput('2001/1/30'), '2001-01-30');
    expect(normalizeBirthdayInput('01302001'), '2001-01-30');
  });

  test('backspace over generated separator removes prior digit', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '2001-',
        selection: TextSelection.collapsed(offset: 5),
      ),
      const TextEditingValue(
        text: '2001',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );

    expect(result.text, '200');
    expect(result.selection.baseOffset, 3);
  });

  test('caps birthday input at eight digits', () {
    expect(
      formatter.formatEditUpdate(_value(''), _value('2001013099')).text,
      '2001-01-30',
    );
  });
}

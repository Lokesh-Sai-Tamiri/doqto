import 'package:doqto_app/core/utils/datetime_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en_US'));

  test('today renders 12-hour with meridiem, not 24-hour', () {
    final now = DateTime.now();
    // 00:22 local — the case that regressed: Hm() rendered "00:22".
    final justAfterMidnight =
        DateTime(now.year, now.month, now.day, 0, 22);
    final out = formatChatListTime(justAfterMidnight);
    // intl separates the meridiem with U+202F, so match parts not the literal.
    expect(out, startsWith('12:22'));
    expect(out, endsWith('AM'));
    expect(out, isNot('00:22'));
  });

  test('yesterday and older keep their labels', () {
    final now = DateTime.now();
    expect(formatChatListTime(now.subtract(const Duration(days: 1))), 'Yesterday');
    expect(formatChatListTime(null), '');
  });
}

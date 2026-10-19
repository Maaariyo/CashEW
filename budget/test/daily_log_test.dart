import 'package:budget/struct/dailyLog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting("en"));

  test('formats a day exactly as the template', () {
    List<DailyLogDay> days = buildDailyLogDays([
      DailyLogEntry(
          date: DateTime(2026, 10, 1, 9),
          amount: 10000,
          name: "Opening balance",
          isActivity: false),
      DailyLogEntry(
          date: DateTime(2026, 10, 16, 8, 30),
          amount: -250,
          name: "Taxi to airport",
          isActivity: true),
      DailyLogEntry(
          date: DateTime(2026, 10, 16, 21),
          amount: -1200.5,
          name: "Hotel",
          isActivity: true),
    ]);
    expect(
      formatDailyLog(days, locale: "en"),
      "16 ..... October .... Friday\n"
      ".\n"
      ".\n"
      ".\n"
      "250 ..... Taxi to airport\n"
      "1200.50 ..... Hotel\n"
      "\n"
      "Balance ..... 8549.50",
    );
  });

  test('balance is the end of day balance, including non activity entries',
      () {
    List<DailyLogDay> days = buildDailyLogDays([
      DailyLogEntry(
          date: DateTime(2026, 10, 17, 12),
          amount: -100,
          name: "Lunch",
          isActivity: true),
      DailyLogEntry(
          date: DateTime(2026, 10, 16, 12),
          amount: 500,
          name: "Top up",
          isActivity: false),
      DailyLogEntry(
          date: DateTime(2026, 10, 17, 18),
          amount: -50,
          name: "Transfer out",
          isActivity: false),
      // Spending on a day only counts once it happened
      DailyLogEntry(
          date: DateTime(2026, 10, 18, 9),
          amount: -20,
          name: "Coffee",
          isActivity: true),
    ]);
    expect(days.length, 2);
    expect(days[0].day, DateTime(2026, 10, 17));
    expect(days[0].activities.map((a) => a.name), ["Lunch"]);
    expect(days[0].balance, 350);
    expect(days[1].balance, 330);
  });

  test('days without activities are skipped', () {
    List<DailyLogDay> days = buildDailyLogDays([
      DailyLogEntry(
          date: DateTime(2026, 10, 15),
          amount: 100,
          name: "Salary",
          isActivity: false),
    ]);
    expect(days, isEmpty);
  });

  test('activities keep their order within a day', () {
    DateTime t = DateTime(2026, 10, 16, 10);
    List<DailyLogDay> days = buildDailyLogDays([
      DailyLogEntry(date: t, amount: -1, name: "A", isActivity: true),
      DailyLogEntry(date: t, amount: -2, name: "B", isActivity: true),
      DailyLogEntry(date: t, amount: -3, name: "C", isActivity: true),
    ]);
    expect(days.single.activities.map((a) => a.name), ["A", "B", "C"]);
  });

  test('amounts are plain numbers', () {
    expect(formatDailyLogAmount(250), "250");
    expect(formatDailyLogAmount(12.5), "12.50");
    expect(formatDailyLogAmount(1234567.891), "1234567.89");
    expect(formatDailyLogAmount(0.1 + 0.2), "0.30");
    expect(formatDailyLogAmount(-0.001), "0");
    expect(formatDailyLogAmount(-32.1), "-32.10");
    expect(formatDailyLogAmount(0.005, decimals: 0), "0");
  });
}

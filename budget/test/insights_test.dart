import 'package:budget/struct/insights.dart';
import 'package:flutter_test/flutter_test.dart';

InsightTransaction expense(DateTime date, double amount,
        {String title = "",
        String category = "food",
        bool tracked = false,
        bool transfer = false}) =>
    InsightTransaction(
      date: date,
      amount: -amount,
      title: title,
      categoryPk: category,
      categoryName: category,
      isTracked: tracked,
      isTransfer: transfer,
    );

void main() {
  DateTime now = DateTime(2026, 11, 17, 12);

  test('month to date compared with the same point last month', () {
    InsightsReport report = buildInsights([
      expense(DateTime(2026, 11, 2), 100),
      expense(DateTime(2026, 11, 15), 200),
      expense(DateTime(2026, 11, 20), 999), // future
      expense(DateTime(2026, 10, 5), 150),
      expense(DateTime(2026, 10, 17, 11), 50),
      expense(DateTime(2026, 10, 25), 400), // after the same point
      expense(DateTime(2026, 11, 3), 500, transfer: true),
      InsightTransaction(
          date: DateTime(2026, 11, 1),
          amount: 5000,
          title: "Salary",
          categoryPk: "income",
          categoryName: "Income"),
    ], now: now);
    expect(report.month.spentThisPeriod, 300);
    expect(report.month.spentLastPeriod, 200);
    expect(report.month.spentLastMonth, 600);
    expect(report.month.changePercent, 50);
    expect(report.month.projectedMonthTotal, closeTo(300 / 17 * 30, 0.001));
  });

  test('no comparison without last month', () {
    InsightsReport report =
        buildInsights([expense(DateTime(2026, 11, 2), 100)], now: now);
    expect(report.month.changePercent, null);
  });

  test('the same point last month is clamped to its length', () {
    DateTime march31 = DateTime(2026, 3, 31, 12);
    InsightsReport report = buildInsights([
      expense(DateTime(2026, 2, 28), 70),
    ], now: march31);
    expect(report.month.spentLastPeriod, 70);
  });

  test('categories that changed most come first', () {
    InsightsReport report = buildInsights([
      expense(DateTime(2026, 11, 2), 100, category: "food"),
      expense(DateTime(2026, 10, 2), 90, category: "food"),
      expense(DateTime(2026, 11, 3), 10, category: "fun"),
      expense(DateTime(2026, 10, 3), 300, category: "fun"),
      expense(DateTime(2026, 11, 4), 50, category: "same"),
      expense(DateTime(2026, 10, 4), 50, category: "same"),
    ], now: now);
    expect(report.categoryChanges.map((c) => c.categoryPk), ["fun", "food"]);
    expect(report.categoryChanges.first.change, -290);
  });

  test('top payees by title this month', () {
    InsightsReport report = buildInsights([
      expense(DateTime(2026, 11, 2), 30, title: "Uber"),
      expense(DateTime(2026, 11, 5), 40, title: "uber "),
      expense(DateTime(2026, 11, 6), 50, title: "Cafe"),
      expense(DateTime(2026, 11, 7), 999),
    ], now: now);
    expect(report.topPayees.map((p) => p.name), ["Uber", "Cafe"]);
    expect(report.topPayees.first.total, 70);
    expect(report.topPayees.first.count, 2);
  });

  group('recurring payments', () {
    test('monthly payment that is not tracked', () {
      List<RecurringCandidate> found = findRecurring([
        expense(DateTime(2026, 8, 3), 199, title: "Netflix"),
        expense(DateTime(2026, 9, 3), 199, title: "Netflix"),
        expense(DateTime(2026, 10, 2), 199, title: "netflix"),
        expense(DateTime(2026, 11, 3), 209, title: "Netflix"),
      ], now: now);
      expect(found.length, 1);
      expect(found.first.cadence, RecurringCadence.monthly);
      expect(found.first.occurrences, 4);
      expect(found.first.nextExpected, DateTime(2026, 12, 3));
      // The latest price, not the average
      expect(found.first.lastAmount, 209);
    });

    test('weekly payment', () {
      List<RecurringCandidate> found = findRecurring([
        for (int week = 0; week < 5; week++)
          expense(DateTime(2026, 10, 20).add(Duration(days: 7 * week)), 60,
              title: "Gym class"),
      ], now: now);
      expect(found.single.cadence, RecurringCadence.weekly);
    });

    test('ignored when already tracked, irregular, varying or stopped', () {
      List<RecurringCandidate> found = findRecurring([
        // Tracked as a subscription
        expense(DateTime(2026, 8, 3), 99, title: "Spotify", tracked: true),
        expense(DateTime(2026, 9, 3), 99, title: "Spotify"),
        expense(DateTime(2026, 10, 3), 99, title: "Spotify"),
        expense(DateTime(2026, 11, 3), 99, title: "Spotify"),
        // Irregular
        expense(DateTime(2026, 9, 1), 20, title: "Coffee"),
        expense(DateTime(2026, 9, 4), 20, title: "Coffee"),
        expense(DateTime(2026, 10, 20), 20, title: "Coffee"),
        expense(DateTime(2026, 11, 9), 20, title: "Coffee"),
        // Amount varies a lot
        expense(DateTime(2026, 8, 10), 100, title: "Electricity"),
        expense(DateTime(2026, 9, 10), 300, title: "Electricity"),
        expense(DateTime(2026, 10, 10), 120, title: "Electricity"),
        expense(DateTime(2026, 11, 10), 500, title: "Electricity"),
        // Stopped months ago
        expense(DateTime(2026, 4, 1), 50, title: "Old app"),
        expense(DateTime(2026, 5, 1), 50, title: "Old app"),
        expense(DateTime(2026, 6, 1), 50, title: "Old app"),
      ], now: now);
      expect(found, isEmpty);
    });
  });

  test('weekday averages over the last 8 weeks', () {
    InsightsReport report = buildInsights([
      // Mondays
      expense(DateTime(2026, 11, 16), 80),
      expense(DateTime(2026, 11, 9), 80),
      // Too old
      expense(DateTime(2026, 9, 1), 1000),
      // Today is excluded until the day is over
      expense(DateTime(2026, 11, 17, 9), 500),
    ], now: now);
    expect(report.weekdayAverages[0], 20);
    expect(report.weekdayAverages[1], 0);
  });

  test('adding months clamps the day', () {
    expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(addMonthsClamped(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
  });
}

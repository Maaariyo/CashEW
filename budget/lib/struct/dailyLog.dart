// Copyable per-day expense logs, one per account (fund). Each day reads:
//
// 16 ..... October .... Friday
// .
// .
// .
// 250 ..... Taxi to airport
// 1200.50 ..... Hotel
//
// Balance ..... 8549.50
//
// Amounts are plain numbers with no currency sign or grouping separators.
import 'package:intl/intl.dart';

// One paid transaction of an account
class DailyLogEntry {
  DailyLogEntry({
    required this.date,
    required this.amount,
    required this.name,
    required this.isActivity,
  });
  final DateTime date;
  // Signed, as stored: expenses are negative
  final double amount;
  final String name;
  // Whether this entry is listed as a line of the day. All entries count
  // towards the balance, including income and transfers
  final bool isActivity;
}

class DailyLogActivity {
  DailyLogActivity({required this.amount, required this.name});
  // Amount spent, positive
  final double amount;
  final String name;
}

class DailyLogDay {
  DailyLogDay({
    required this.day,
    required this.activities,
    required this.balance,
  });
  final DateTime day;
  final List<DailyLogActivity> activities;
  // Balance of the account at the end of this day
  final double balance;
}

// Groups an account's entries into days that have at least one activity,
// oldest first, with the account's running balance at the end of each day
List<DailyLogDay> buildDailyLogDays(List<DailyLogEntry> entries) {
  List<DailyLogEntry> sorted = List.of(entries);
  // Stable sort keeps the input order for transactions at the same time
  _stableSort(sorted, (a, b) => a.date.compareTo(b.date));

  List<DailyLogDay> days = [];
  double balance = 0;
  int index = 0;
  while (index < sorted.length) {
    DateTime day = DateTime(
        sorted[index].date.year, sorted[index].date.month, sorted[index].date.day);
    List<DailyLogActivity> activities = [];
    while (index < sorted.length && _sameDay(sorted[index].date, day)) {
      DailyLogEntry entry = sorted[index];
      balance += entry.amount;
      if (entry.isActivity)
        activities.add(
            DailyLogActivity(amount: entry.amount.abs(), name: entry.name));
      index++;
    }
    if (activities.isNotEmpty)
      days.add(DailyLogDay(day: day, activities: activities, balance: balance));
  }
  return days;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// 250, 1200.50, -32.10. Whole amounts have no decimals
String formatDailyLogAmount(double amount, {int decimals = 2}) {
  // Avoid "-0" and floating point noise such as 0.1 + 0.2
  double rounded = double.parse(amount.toStringAsFixed(decimals));
  if (rounded == 0) rounded = 0;
  if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
  return rounded.toStringAsFixed(decimals);
}

String formatDailyLogDay(DailyLogDay day, {String? locale, int decimals = 2}) {
  List<String> lines = [
    "${day.day.day} ..... ${DateFormat.MMMM(locale).format(day.day)} .... ${DateFormat.EEEE(locale).format(day.day)}",
    ".",
    ".",
    ".",
    for (DailyLogActivity activity in day.activities)
      "${formatDailyLogAmount(activity.amount, decimals: decimals)} ..... ${activity.name}",
    "",
    "Balance ..... ${formatDailyLogAmount(day.balance, decimals: decimals)}",
  ];
  return lines.join("\n");
}

// Several days, separated by a blank line
String formatDailyLog(List<DailyLogDay> days,
    {String? locale, int decimals = 2}) {
  return days
      .map((day) => formatDailyLogDay(day, locale: locale, decimals: decimals))
      .join("\n\n");
}

// Merge sort, List.sort is not guaranteed to be stable
void _stableSort<T>(List<T> list, int Function(T a, T b) compare) {
  if (list.length < 2) return;
  List<T> left = list.sublist(0, list.length ~/ 2);
  List<T> right = list.sublist(list.length ~/ 2);
  _stableSort(left, compare);
  _stableSort(right, compare);
  int i = 0, j = 0, k = 0;
  while (i < left.length && j < right.length) {
    list[k++] = compare(left[i], right[j]) <= 0 ? left[i++] : right[j++];
  }
  while (i < left.length) list[k++] = left[i++];
  while (j < right.length) list[k++] = right[j++];
}

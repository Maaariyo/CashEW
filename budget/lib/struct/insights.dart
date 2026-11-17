// Spending insights, inspired by Copilot, Monarch and Rocket Money:
// month to date compared with the same point last month, a month end
// projection, the categories that changed most, top payees, recurring
// payments that aren't tracked as subscriptions, and spending by weekday.
//
// Pure Dart so it can be unit tested; amounts are already converted to the
// primary currency by the caller.

class InsightTransaction {
  InsightTransaction({
    required this.date,
    required this.amount,
    required this.title,
    required this.categoryPk,
    required this.categoryName,
    this.isTransfer = false,
    this.isTracked = false,
    this.walletPk = "",
    double? walletAmount,
  }) : walletAmount = walletAmount ?? amount;
  final DateTime date;
  // Signed, expenses are negative, in the primary currency
  final double amount;
  // The wallet it belongs to, and the amount in that wallet's currency
  final String walletPk;
  final double walletAmount;
  final String title;
  final String categoryPk;
  final String categoryName;
  // Transfers and balance corrections are not spending
  final bool isTransfer;
  // Already a subscription, repeating or upcoming transaction
  final bool isTracked;

  bool get isExpense => amount < 0 && isTransfer == false;
  double get spent => isExpense ? -amount : 0;
}

class MonthComparison {
  MonthComparison({
    required this.spentThisPeriod,
    required this.spentLastPeriod,
    required this.spentLastMonth,
    required this.daysElapsed,
    required this.daysInMonth,
  });
  // This month so far, and last month up to the same day
  final double spentThisPeriod;
  final double spentLastPeriod;
  final double spentLastMonth;
  final int daysElapsed;
  final int daysInMonth;

  // Null when there is nothing to compare with
  double? get changePercent => spentLastPeriod <= 0
      ? null
      : (spentThisPeriod - spentLastPeriod) / spentLastPeriod * 100;

  double get projectedMonthTotal =>
      daysElapsed <= 0 ? 0 : spentThisPeriod / daysElapsed * daysInMonth;
}

class CategoryChange {
  CategoryChange({
    required this.categoryPk,
    required this.name,
    required this.spentThisPeriod,
    required this.spentLastPeriod,
  });
  final String categoryPk;
  final String name;
  final double spentThisPeriod;
  final double spentLastPeriod;
  double get change => spentThisPeriod - spentLastPeriod;
}

class PayeeTotal {
  PayeeTotal({required this.name, required this.total, required this.count});
  final String name;
  final double total;
  final int count;
}

enum RecurringCadence { weekly, fortnightly, monthly }

class RecurringCandidate {
  RecurringCandidate({
    required this.title,
    required this.categoryPk,
    required this.averageAmount,
    required this.lastAmount,
    required this.occurrences,
    required this.cadence,
    required this.lastDate,
    required this.walletPk,
    required this.lastWalletAmount,
  });
  final String title;
  final String categoryPk;
  final double averageAmount;
  // What the next payment will most likely be, prices change
  final double lastAmount;
  // Where the payments are made, so a subscription is linked to the same
  // wallet, with the amount in that wallet's currency
  final String walletPk;
  final double lastWalletAmount;
  final int occurrences;
  final RecurringCadence cadence;
  final DateTime lastDate;

  int get cadenceDays => cadence == RecurringCadence.weekly
      ? 7
      : cadence == RecurringCadence.fortnightly
          ? 14
          : 30;

  DateTime get nextExpected => cadence == RecurringCadence.monthly
      ? addMonthsClamped(lastDate, 1)
      : lastDate.add(Duration(days: cadenceDays));
}

class InsightsReport {
  InsightsReport({
    required this.month,
    required this.categoryChanges,
    required this.topPayees,
    required this.recurring,
    required this.weekdayAverages,
  });
  final MonthComparison month;
  // Largest absolute change first
  final List<CategoryChange> categoryChanges;
  final List<PayeeTotal> topPayees;
  final List<RecurringCandidate> recurring;
  // Average spent per weekday over the last 8 weeks, Monday first
  final List<double> weekdayAverages;
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

// Same day in a later month, clamped to that month's length (Jan 31 -> Feb 28)
DateTime addMonthsClamped(DateTime date, int months) {
  int monthIndex = date.month - 1 + months;
  int year = date.year + (monthIndex / 12).floor();
  int month = monthIndex % 12 + 1;
  int day = date.day.clamp(1, daysInMonth(year, month));
  return DateTime(year, month, day, date.hour, date.minute, date.second);
}

String normalizeTitle(String title) =>
    title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

// The most used spelling of a title, preferring a capitalised one on ties
String displayTitle(List<InsightTransaction> transactions) {
  Map<String, int> counts = {};
  for (InsightTransaction t in transactions) {
    String title = t.title.trim();
    counts[title] = (counts[title] ?? 0) + 1;
  }
  bool capitalised(String s) => s.isNotEmpty && s[0] != s[0].toLowerCase();
  return counts.entries.reduce((best, next) {
    if (next.value != best.value) return next.value > best.value ? next : best;
    return capitalised(next.key) && !capitalised(best.key) ? next : best;
  }).key;
}

InsightsReport buildInsights(List<InsightTransaction> transactions,
    {required DateTime now}) {
  DateTime monthStart = DateTime(now.year, now.month);
  DateTime lastMonthStart = DateTime(now.year, now.month - 1);
  int lastMonthLength = daysInMonth(lastMonthStart.year, lastMonthStart.month);
  // Same point in last month, clamped for shorter months
  DateTime lastPeriodEnd = DateTime(
    lastMonthStart.year,
    lastMonthStart.month,
    now.day.clamp(1, lastMonthLength),
    now.hour,
    now.minute,
    now.second,
  );

  bool inRange(DateTime d, DateTime from, DateTime to) =>
      d.isBefore(from) == false && d.isAfter(to) == false;

  List<InsightTransaction> expenses =
      transactions.where((t) => t.isExpense).toList();
  List<InsightTransaction> thisPeriod =
      expenses.where((t) => inRange(t.date, monthStart, now)).toList();
  List<InsightTransaction> lastPeriod = expenses
      .where((t) => inRange(t.date, lastMonthStart, lastPeriodEnd))
      .toList();
  double sum(Iterable<InsightTransaction> list) =>
      list.fold(0, (total, t) => total + t.spent);

  MonthComparison month = MonthComparison(
    spentThisPeriod: sum(thisPeriod),
    spentLastPeriod: sum(lastPeriod),
    spentLastMonth: sum(expenses.where((t) =>
        t.date.isBefore(monthStart) && !t.date.isBefore(lastMonthStart))),
    daysElapsed: now.day,
    daysInMonth: daysInMonth(now.year, now.month),
  );

  // Category changes
  Map<String, CategoryChange> categories = {};
  void addTo(InsightTransaction t, bool current) {
    CategoryChange? existing = categories[t.categoryPk];
    categories[t.categoryPk] = CategoryChange(
      categoryPk: t.categoryPk,
      name: t.categoryName,
      spentThisPeriod:
          (existing?.spentThisPeriod ?? 0) + (current ? t.spent : 0),
      spentLastPeriod:
          (existing?.spentLastPeriod ?? 0) + (current ? 0 : t.spent),
    );
  }

  for (InsightTransaction t in thisPeriod) addTo(t, true);
  for (InsightTransaction t in lastPeriod) addTo(t, false);
  List<CategoryChange> categoryChanges = categories.values
      .where((c) => c.change.abs() >= 0.01)
      .toList()
    ..sort((a, b) => b.change.abs().compareTo(a.change.abs()));

  // Top payees this month, by title
  Map<String, List<InsightTransaction>> byTitle = {};
  for (InsightTransaction t in thisPeriod) {
    String key = normalizeTitle(t.title);
    if (key == "") continue;
    byTitle.putIfAbsent(key, () => []).add(t);
  }
  List<PayeeTotal> topPayees = byTitle.values
      .map((list) => PayeeTotal(
            name: displayTitle(list),
            total: sum(list),
            count: list.length,
          ))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return InsightsReport(
    month: month,
    categoryChanges: categoryChanges,
    topPayees: topPayees,
    recurring: findRecurring(transactions, now: now),
    weekdayAverages: weekdayAverages(expenses, now: now),
  );
}

// Expenses with the same title, a steady amount and a regular interval
// that aren't tracked as subscriptions yet (like Rocket Money)
List<RecurringCandidate> findRecurring(List<InsightTransaction> transactions,
    {required DateTime now}) {
  DateTime from = now.subtract(Duration(days: 200));
  Set<String> trackedTitles = transactions
      .where((t) => t.isTracked)
      .map((t) => normalizeTitle(t.title))
      .toSet();
  Map<String, List<InsightTransaction>> byTitle = {};
  for (InsightTransaction t in transactions) {
    if (t.isExpense == false || t.isTracked || t.date.isBefore(from)) continue;
    String key = normalizeTitle(t.title);
    if (key == "" || trackedTitles.contains(key)) continue;
    byTitle.putIfAbsent(key, () => []).add(t);
  }

  List<RecurringCandidate> candidates = [];
  for (List<InsightTransaction> list in byTitle.values) {
    list.sort((a, b) => a.date.compareTo(b.date));
    // One payment per day at most
    List<InsightTransaction> payments = [];
    for (InsightTransaction t in list) {
      if (payments.isEmpty ||
          startOfDay(payments.last.date) != startOfDay(t.date)) payments.add(t);
    }
    if (payments.length < 3) continue;

    List<int> gaps = [
      for (int i = 1; i < payments.length; i++)
        startOfDay(payments[i].date)
            .difference(startOfDay(payments[i - 1].date))
            .inDays
    ];
    List<int> sortedGaps = List.of(gaps)..sort();
    int medianGap = sortedGaps[sortedGaps.length ~/ 2];
    RecurringCadence? cadence = medianGap >= 6 && medianGap <= 8
        ? RecurringCadence.weekly
        : medianGap >= 13 && medianGap <= 16
            ? RecurringCadence.fortnightly
            : medianGap >= 27 && medianGap <= 33
                ? RecurringCadence.monthly
                : null;
    if (cadence == null) continue;
    int tolerance = cadence == RecurringCadence.monthly ? 4 : 2;
    int regular = gaps.where((g) => (g - medianGap).abs() <= tolerance).length;
    if (regular < gaps.length * 0.75) continue;

    List<double> amounts = payments.map((t) => t.spent).toList()..sort();
    double medianAmount = amounts[amounts.length ~/ 2];
    if (amounts.any((a) => (a - medianAmount).abs() > medianAmount * 0.2))
      continue;

    // Still active: the last payment is not long overdue
    DateTime last = payments.last.date;
    if (now.difference(last).inDays > medianGap * 1.5) continue;

    candidates.add(RecurringCandidate(
      title: displayTitle(payments),
      categoryPk: payments.last.categoryPk,
      averageAmount:
          amounts.fold<double>(0, (total, a) => total + a) / amounts.length,
      lastAmount: payments.last.spent,
      occurrences: payments.length,
      cadence: cadence,
      lastDate: last,
      walletPk: payments.last.walletPk,
      lastWalletAmount: payments.last.walletAmount.abs(),
    ));
  }
  candidates.sort((a, b) => b.averageAmount.compareTo(a.averageAmount));
  return candidates;
}

// Average spent on each weekday over the last 8 full weeks, Monday first
List<double> weekdayAverages(List<InsightTransaction> expenses,
    {required DateTime now}) {
  DateTime to = startOfDay(now);
  DateTime from = to.subtract(Duration(days: 56));
  List<double> totals = List.filled(7, 0);
  for (InsightTransaction t in expenses) {
    if (t.date.isBefore(from) || !t.date.isBefore(to)) continue;
    totals[t.date.weekday - 1] += t.spent;
  }
  return totals.map((total) => total / 8).toList();
}

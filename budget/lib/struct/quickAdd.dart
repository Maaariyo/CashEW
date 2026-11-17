// Quick Add: log a transaction from one line of text, like Spendee, Monefy or
// Walnut. Examples:
//   250 taxi                   expense of 250, title "Taxi", today
//   +50000 salary              income
//   1.2k groceries yesterday   1200, yesterday
//   80 coffee #dining          category Dining
//   450 dinner on friday       the most recent Friday
//   1,299 shoes 12 nov         12 November (last year if that's in the future)
//   2 coffees 120              120: a number marked as money (₹, \$, k, decimals)
//                              wins, otherwise the largest one
//
// Pure Dart so it can be unit tested.

class QuickAddEntry {
  QuickAddEntry({
    required this.amount,
    required this.income,
    required this.title,
    required this.date,
    required this.category,
  });
  // Positive, null when no amount was found
  final double? amount;
  final bool income;
  final String title;
  // Null means now
  final DateTime? date;
  // From a #hashtag
  final String? category;

  // Signed as Cashew stores it
  double? get signedAmount =>
      amount == null ? null : (income ? amount! : -amount!);
}

const List<String> _incomeWords = [
  "salary",
  "income",
  "refund",
  "received",
  "cashback",
  "interest",
  "dividend",
  "bonus",
  "stipend",
];

const List<String> _fillerWords = ["for", "on", "at", "spent", "paid"];

const Map<String, int> _months = {
  "jan": 1,
  "january": 1,
  "feb": 2,
  "february": 2,
  "mar": 3,
  "march": 3,
  "apr": 4,
  "april": 4,
  "may": 5,
  "jun": 6,
  "june": 6,
  "jul": 7,
  "july": 7,
  "aug": 8,
  "august": 8,
  "sep": 9,
  "sept": 9,
  "september": 9,
  "oct": 10,
  "october": 10,
  "nov": 11,
  "november": 11,
  "dec": 12,
  "december": 12,
};

const Map<String, int> _weekdays = {
  "mon": 1,
  "monday": 1,
  "tue": 2,
  "tues": 2,
  "tuesday": 2,
  "wed": 3,
  "wednesday": 3,
  "thu": 4,
  "thur": 4,
  "thurs": 4,
  "thursday": 4,
  "fri": 5,
  "friday": 5,
  "sat": 6,
  "saturday": 6,
  "sun": 7,
  "sunday": 7,
};

final RegExp _amountPattern = RegExp(
  r'^([+-])?(?:rs\.?|inr|₹|\$|€|£)?([+-])?(\d[\d,]*(?:\.\d+)?)(k)?(?:/-|rs\.?|inr|₹|\$|€|£)?$',
  caseSensitive: false,
);

final RegExp _dayOfMonthPattern =
    RegExp(r'^(\d{1,2})(?:st|nd|rd|th)?$', caseSensitive: false);

QuickAddEntry parseQuickAdd(String input, {required DateTime now}) {
  List<String> tokens = input
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
  DateTime today = DateTime(now.year, now.month, now.day);
  DateTime? date;
  String? category;

  String lower(int i) => tokens[i].toLowerCase().replaceAll(",", "");

  // Dates first, so a day number isn't taken as the amount
  for (int i = 0; i < tokens.length && date == null; i++) {
    String word = lower(i);
    int consumedFrom = i;
    int consumedTo = i;
    if (word == "today") {
      date = today;
    } else if (word == "yesterday" || word == "yday") {
      date = today.subtract(Duration(days: 1));
    } else if (_weekdays.containsKey(word) &&
        // Short forms only after "on" or "last", so "sun cream" stays a title
        (word.length > 4 ||
            (i > 0 && (lower(i - 1) == "on" || lower(i - 1) == "last")))) {
      int back = (today.weekday - _weekdays[word]! + 7) % 7;
      if (i > 0 && lower(i - 1) == "last") {
        if (back == 0) back = 7;
        consumedFrom = i - 1;
      }
      date = today.subtract(Duration(days: back));
    } else if (i + 2 < tokens.length &&
        RegExp(r'^\d{1,3}$').hasMatch(word) &&
        (lower(i + 1) == "days" || lower(i + 1) == "day") &&
        lower(i + 2) == "ago") {
      date = today.subtract(Duration(days: int.parse(word)));
      consumedTo = i + 2;
    } else if (_months.containsKey(word)) {
      // "nov 12" or "12 nov"
      int month = _months[word]!;
      Match? after = i + 1 < tokens.length
          ? _dayOfMonthPattern.firstMatch(lower(i + 1))
          : null;
      Match? before =
          i > 0 ? _dayOfMonthPattern.firstMatch(lower(i - 1)) : null;
      Match? day = after ?? before;
      if (day != null) {
        if (after != null) {
          consumedTo = i + 1;
        } else {
          consumedFrom = i - 1;
        }
        date = _pastDate(today, month, int.parse(day.group(1)!));
      }
    } else if (word == "on" &&
        i + 1 < tokens.length &&
        _dayOfMonthPattern.hasMatch(lower(i + 1)) &&
        // "on 12 oct" is handled by the month branch
        (i + 2 >= tokens.length || !_months.containsKey(lower(i + 2)))) {
      // "on 5th": that day this month, or last month if it's in the future
      int day =
          int.parse(_dayOfMonthPattern.firstMatch(lower(i + 1))!.group(1)!);
      DateTime candidate = _clampedDate(today.year, today.month, day);
      if (candidate.isAfter(today)) {
        candidate = _clampedDate(today.year, today.month - 1, day);
      }
      date = candidate;
      consumedTo = i + 1;
    }
    if (date != null) {
      // "on monday", "on 12 nov"
      if (consumedFrom > 0 && lower(consumedFrom - 1) == "on") consumedFrom--;
      tokens.removeRange(consumedFrom, consumedTo + 1);
    }
  }

  // Category hashtag
  for (int i = 0; i < tokens.length; i++) {
    if (tokens[i].startsWith("#") && tokens[i].length > 1) {
      category = tokens[i].substring(1).replaceAll("_", " ");
      tokens.removeAt(i);
      break;
    }
  }

  // Amount: the first number marked as money (sign, currency, k or
  // decimals), otherwise the largest number, since a quantity such as
  // "2 coffees 120" is smaller than its price
  double? amount;
  bool? explicitIncome;
  int? amountIndex;
  bool amountMarked = false;
  for (int i = 0; i < tokens.length; i++) {
    Match? match = _amountPattern.firstMatch(tokens[i]);
    if (match == null) continue;
    double? value = double.tryParse(match.group(3)!.replaceAll(",", ""));
    if (value == null) continue;
    if (match.group(4) != null) value *= 1000;
    bool marked = !RegExp(r'^\d+$').hasMatch(tokens[i]);
    bool better = amount == null ||
        (marked && !amountMarked) ||
        (marked == amountMarked && !amountMarked && value > amount);
    if (!better) continue;
    amount = value;
    amountIndex = i;
    amountMarked = marked;
    String? sign = match.group(1) ?? match.group(2);
    explicitIncome = sign == "+"
        ? true
        : sign == "-"
            ? false
            : null;
  }
  if (amountIndex != null) tokens.removeAt(amountIndex);

  while (tokens.isNotEmpty && _fillerWords.contains(tokens.first.toLowerCase()))
    tokens.removeAt(0);
  String title = tokens.join(" ").trim();
  if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);

  bool income = explicitIncome ??
      title
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .any((word) => _incomeWords.contains(word));

  return QuickAddEntry(
    amount: amount,
    income: income,
    title: title,
    date: date,
    category: category,
  );
}

DateTime _clampedDate(int year, int month, int day) {
  DateTime first = DateTime(year, month);
  int length = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, day.clamp(1, length));
}

// That day this year, or last year if it hasn't happened yet
DateTime _pastDate(DateTime today, int month, int day) {
  DateTime candidate = _clampedDate(today.year, month, day);
  if (candidate.isAfter(today))
    candidate = _clampedDate(today.year - 1, month, day);
  return candidate;
}

import 'package:budget/struct/quickAdd.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Tuesday
  DateTime now = DateTime(2026, 11, 17, 14, 30);
  QuickAddEntry parse(String input) => parseQuickAdd(input, now: now);

  test('amount and title', () {
    QuickAddEntry entry = parse("250 taxi to airport");
    expect(entry.amount, 250);
    expect(entry.income, false);
    expect(entry.signedAmount, -250);
    expect(entry.title, "Taxi to airport");
    expect(entry.date, null);
    expect(entry.category, null);
  });

  test('amount formats', () {
    expect(parse("1,299 shoes").amount, 1299);
    expect(parse("₹250 auto").amount, 250);
    expect(parse("rs250 auto").amount, 250);
    expect(parse("250/- auto").amount, 250);
    expect(parse(r"\$12.50 lunch").amount, null);
    expect(parse(r"$12.50 lunch").amount, 12.5);
    expect(parse("1.5k groceries").amount, 1500);
    expect(parse("taxi 250").amount, 250);
    expect(parse("taxi").amount, null);
  });

  test('income', () {
    expect(parse("+50000 salary").income, true);
    expect(parse("50000 salary").income, true);
    expect(parse("200 cashback").income, true);
    expect(parse("-200 refund").income, false);
    expect(parse("200 lunch").income, false);
  });

  test('dates', () {
    expect(parse("250 taxi today").date, DateTime(2026, 11, 17));
    expect(parse("250 taxi yesterday").date, DateTime(2026, 11, 16));
    expect(parse("250 taxi yesterday").title, "Taxi");
    expect(parse("3 days ago 300 cab").date, DateTime(2026, 11, 14));
    expect(parse("3 days ago 300 cab").amount, 300);
    // Weekdays are the most recent one, today included
    expect(parse("450 dinner on friday").date, DateTime(2026, 11, 13));
    expect(parse("450 dinner on friday").title, "Dinner");
    expect(parse("100 snacks tuesday").date, DateTime(2026, 11, 17));
    expect(parse("100 snacks last tuesday").date, DateTime(2026, 11, 10));
    expect(parse("1,299 shoes 12 nov").date, DateTime(2026, 11, 12));
    expect(parse("1,299 shoes nov 12").date, DateTime(2026, 11, 12));
    expect(parse("1,299 shoes nov 12").amount, 1299);
    // Future dates mean last year
    expect(parse("900 gift 25 dec").date, DateTime(2025, 12, 25));
    expect(parse("60 tea on 5th").date, DateTime(2026, 11, 5));
    expect(parse("60 tea on 30th").date, DateTime(2026, 10, 30));
    expect(parse("60 tea on 30th").title, "Tea");
  });

  test('review fixes', () {
    // "on 12 oct" is a date in October, not the 12th of this month
    expect(parse("250 lunch on 12 oct").date, DateTime(2026, 10, 12));
    expect(parse("250 lunch on 12 oct").title, "Lunch");
    // Short weekday names are words unless used as dates
    expect(parse("300 sun cream").date, null);
    expect(parse("300 sun cream").title, "Sun cream");
    expect(parse("200 gift on wed").date, DateTime(2026, 11, 11));
    expect(parse("200 gift last sun").date, DateTime(2026, 11, 15));
    // A quantity isn't the price
    expect(parse("2 coffees 120").amount, 120);
    expect(parse("2 coffees 120").title, "2 coffees");
    expect(parse("2 coffees ₹120").amount, 120);
    expect(parse("2 tickets 12.50").amount, 12.5);
    expect(parse("0 taxi").amount, 0);
  });

  test('category hashtag and filler words', () {
    QuickAddEntry entry = parse("spent 80 on coffee #dining");
    expect(entry.amount, 80);
    expect(entry.category, "dining");
    expect(entry.title, "Coffee");
    expect(parse("120 movie #eating_out").category, "eating out");
  });
}

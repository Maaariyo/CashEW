import 'dart:math';

import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/currencyFunctions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/insights.dart';
import 'package:budget/struct/trekTravel.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Loads what buildInsights needs, in the primary currency
Future<InsightsReport> loadInsights(AllWallets allWallets,
    {required DateTime now}) async {
  DateTime from = DateTime(now.year, now.month - 7);
  Map<String, String> categoryNames = {
    for (TransactionCategory category
        in await database.getAllCategories(includeSubCategories: true))
      category.categoryPk: category.name
  };
  // Paid transactions in range, and every subscription, repeating or
  // upcoming one so their titles count as tracked
  List<Transaction> transactions = await (database.select(database.transactions)
        ..where((t) =>
            (t.paid.equals(true) & t.dateCreated.isBiggerOrEqualValue(from)) |
            t.type.isNotNull()))
      .get();
  List<InsightTransaction> list = [
    for (Transaction t in transactions)
      InsightTransaction(
        date: t.dateCreated,
        amount: t.amount *
            amountRatioToPrimaryCurrencyGivenPk(allWallets, t.walletFk),
        title: t.name,
        categoryPk: t.categoryFk,
        categoryName: categoryNames[t.categoryFk] ?? "",
        // Not spending: transfers, corrections, loans and unpaid entries
        isTransfer: t.categoryFk == balanceCorrectionCategoryPk ||
            t.type == TransactionSpecialType.credit ||
            t.type == TransactionSpecialType.debt ||
            t.paid == false,
        isTracked: t.type != null,
        walletPk: t.walletFk,
        walletAmount: t.amount,
      ),
  ];
  return buildInsights(list, now: now);
}

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  Future<InsightsReport>? reportFuture;

  void load() {
    reportFuture = loadInsights(
      Provider.of<AllWallets>(context, listen: false),
      now: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (reportFuture == null) load();
    return PageFramework(
      horizontalPaddingConstrained: true,
      dragDownToDismiss: true,
      title: "Insights",
      listWidgets: [
        FutureBuilder<InsightsReport>(
          future: reportFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return SizedBox.shrink();
            InsightsReport? report = snapshot.data;
            if (report == null ||
                (report.month.spentThisPeriod == 0 &&
                    report.month.spentLastMonth == 0 &&
                    report.recurring.isEmpty))
              return NoResults(
                  message: "Add some expenses to see insights here");
            return Column(
              children: [
                MonthInsightCard(month: report.month),
                if (report.categoryChanges.isNotEmpty)
                  CategoryChangesCard(changes: report.categoryChanges),
                if (report.recurring.isNotEmpty)
                  RecurringCard(
                    recurring: report.recurring,
                    onTracked: () => setState(load),
                  ),
                if (report.topPayees.isNotEmpty)
                  TopPayeesCard(payees: report.topPayees),
                if (report.weekdayAverages.any((amount) => amount > 0))
                  WeekdayCard(averages: report.weekdayAverages),
                SizedBox(height: 40),
              ],
            );
          },
        ),
      ],
    );
  }
}

class InsightCard extends StatelessWidget {
  const InsightCard(
      {required this.title, required this.child, this.subtitle, super.key});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: getColor(context, "standardContainerColor"),
          borderRadius: BorderRadiusDirectional.circular(18),
          boxShadow: boxShadowCheck(boxShadowGeneral(context)),
        ),
        padding: const EdgeInsetsDirectional.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFont(text: title, fontSize: 20, fontWeight: FontWeight.bold),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 3),
                child: TextFont(
                  text: subtitle!,
                  fontSize: 13,
                  maxLines: 3,
                  textColor: getColor(context, "textLight"),
                ),
              ),
            SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

String money(BuildContext context, double amount) =>
    convertToMoney(Provider.of<AllWallets>(context), amount);

class MonthInsightCard extends StatelessWidget {
  const MonthInsightCard({required this.month, super.key});
  final MonthComparison month;

  @override
  Widget build(BuildContext context) {
    double? change = month.changePercent;
    bool up = (change ?? 0) > 0;
    Color changeColor = up
        ? getColor(context, "expenseAmount")
        : getColor(context, "incomeAmount");
    return InsightCard(
      title: "This month",
      subtitle: "Spent from the 1st until today",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFont(
            text: money(context, month.spentThisPeriod),
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(height: 6),
          if (change != null)
            Row(
              children: [
                Icon(
                  up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: changeColor,
                  size: 20,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: TextFont(
                    text: change.abs().toStringAsFixed(0) +
                        "% " +
                        (up ? "more" : "less") +
                        " than this point last month (" +
                        money(context, month.spentLastPeriod) +
                        ")",
                    fontSize: 14,
                    maxLines: 3,
                    textColor: changeColor,
                  ),
                ),
              ],
            ),
          SizedBox(height: 10),
          TextFont(
            text: "At this pace: about " +
                money(context, month.projectedMonthTotal) +
                " by the end of the month" +
                (month.spentLastMonth > 0
                    ? " (last month: " +
                        money(context, month.spentLastMonth) +
                        ")"
                    : ""),
            fontSize: 14,
            maxLines: 4,
            textColor: getColor(context, "textLight"),
          ),
        ],
      ),
    );
  }
}

class CategoryChangesCard extends StatelessWidget {
  const CategoryChangesCard({required this.changes, super.key});
  final List<CategoryChange> changes;

  @override
  Widget build(BuildContext context) {
    return InsightCard(
      title: "Biggest changes",
      subtitle: "By category, compared with this point last month",
      child: Column(
        children: [
          for (CategoryChange change in changes.take(5))
            InsightRow(
              label: change.name,
              detail: money(context, change.spentThisPeriod) + " this month",
              value: (change.change > 0 ? "+" : "−") +
                  money(context, change.change.abs()),
              valueColor: change.change > 0
                  ? getColor(context, "expenseAmount")
                  : getColor(context, "incomeAmount"),
            ),
        ],
      ),
    );
  }
}

class TopPayeesCard extends StatelessWidget {
  const TopPayeesCard({required this.payees, super.key});
  final List<PayeeTotal> payees;

  @override
  Widget build(BuildContext context) {
    return InsightCard(
      title: "Where it went",
      subtitle: "Top payees this month, by title",
      child: Column(
        children: [
          for (PayeeTotal payee in payees.take(5))
            InsightRow(
              label: payee.name,
              detail: payee.count == 1
                  ? "1 transaction"
                  : payee.count.toString() + " transactions",
              value: money(context, payee.total),
            ),
        ],
      ),
    );
  }
}

class RecurringCard extends StatelessWidget {
  const RecurringCard(
      {required this.recurring, required this.onTracked, super.key});
  final List<RecurringCandidate> recurring;
  final VoidCallback onTracked;

  String cadenceLabel(RecurringCadence cadence) =>
      cadence == RecurringCadence.weekly
          ? "every week"
          : cadence == RecurringCadence.fortnightly
              ? "every 2 weeks"
              : "every month";

  Future track(BuildContext context, RecurringCandidate candidate) async {
    TransactionCategory? category =
        await database.getCategoryInstanceOrNull(candidate.categoryPk);
    // The wallet the payments come from, with the amount in its currency
    TransactionWallet? wallet = Provider.of<AllWallets>(context, listen: false)
        .indexedByPk[candidate.walletPk];
    await pushRoute(
      context,
      AddTransactionPage(
        routesToPopAfterDelete: RoutesToPopAfterDelete.None,
        selectedType: TransactionSpecialType.subscription,
        selectedTitle: candidate.title,
        selectedAmount:
            wallet == null ? candidate.lastAmount : candidate.lastWalletAmount,
        selectedWallet: wallet,
        selectedIncome: false,
        selectedCategory: category,
        selectedDate: candidate.nextExpected,
        startInitialAddTransactionSequence: false,
      ),
    );
    onTracked();
  }

  @override
  Widget build(BuildContext context) {
    return InsightCard(
      title: "Looks recurring",
      subtitle:
          "Regular payments that aren't tracked as subscriptions yet. Track one to get reminders and see it in Subscriptions",
      child: Column(
        children: [
          for (RecurringCandidate candidate in recurring.take(5))
            InsightRow(
              label: candidate.title,
              detail: "~" +
                  money(context, candidate.lastAmount) +
                  " " +
                  cadenceLabel(candidate.cadence) +
                  " · next ~" +
                  DateFormat.MMMd(context.locale.toString())
                      .format(candidate.nextExpected),
              trailing: Button(
                label: "Track",
                fontSize: 13,
                padding: EdgeInsetsDirectional.symmetric(
                    horizontal: 14, vertical: 8),
                onTap: () => track(context, candidate),
              ),
            ),
        ],
      ),
    );
  }
}

class WeekdayCard extends StatelessWidget {
  const WeekdayCard({required this.averages, super.key});
  final List<double> averages;

  @override
  Widget build(BuildContext context) {
    double highest = averages.reduce(max);
    int busiest = averages.indexOf(highest);
    String locale = context.locale.toString();
    // 2023-01-02 was a Monday
    String dayName(int index, {bool short = true}) =>
        (short ? DateFormat.E(locale) : DateFormat.EEEE(locale))
            .format(DateTime(2023, 1, 2 + index));
    return InsightCard(
      title: "Spending by weekday",
      subtitle:
          "Average per day over the last 8 weeks. You spend the most on " +
              dayName(busiest, short: false) +
              "s (" +
              money(context, highest) +
              ")",
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (int i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: max(4, 90 * averages[i] / max(highest, 0.01)),
                        decoration: BoxDecoration(
                          color: i == busiest
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
                          borderRadius: BorderRadiusDirectional.circular(6),
                        ),
                      ),
                      SizedBox(height: 6),
                      TextFont(
                        text: dayName(i),
                        fontSize: 12,
                        textColor: getColor(context, "textLight"),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class InsightRow extends StatelessWidget {
  const InsightRow({
    required this.label,
    required this.detail,
    this.value,
    this.valueColor,
    this.trailing,
    super.key,
  });
  final String label;
  final String detail;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFont(text: label, fontSize: 16, maxLines: 1),
                TextFont(
                  text: detail,
                  fontSize: 13,
                  maxLines: 2,
                  textColor: getColor(context, "textLight"),
                ),
              ],
            ),
          ),
          if (value != null)
            TextFont(
              text: value!,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: valueColor,
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/dailyLog.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/trekTravel.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/selectChips.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/util/saveFile.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Copyable text logs of each day's expenses, one per account (fund).
// With a trip, only the trip's expenses are listed.
class DailyLogPage extends StatefulWidget {
  const DailyLogPage({this.trip, super.key});
  final Budget? trip;

  @override
  State<DailyLogPage> createState() => _DailyLogPageState();
}

class _DailyLogPageState extends State<DailyLogPage> {
  late Future<List<DailyLogAccount>> accountsFuture =
      loadDailyLogs(tripBudgetPk: widget.trip?.budgetPk);
  String? selectedWalletPk;

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      horizontalPaddingConstrained: true,
      dragDownToDismiss: true,
      title: widget.trip == null ? "Daily Log" : widget.trip!.name,
      listWidgets: [
        FutureBuilder<List<DailyLogAccount>>(
          future: accountsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return SizedBox.shrink();
            List<DailyLogAccount> accounts = snapshot.data ?? [];
            if (accounts.isEmpty)
              return NoResults(
                message: widget.trip == null
                    ? "No expenses logged yet"
                    : "No expenses added to this trip yet",
              );
            DailyLogAccount account = accounts.firstWhere(
              (account) => account.wallet.walletPk == selectedWalletPk,
              orElse: () => accounts.first,
            );
            return buildAccount(context, accounts, account);
          },
        ),
      ],
    );
  }

  Widget buildAccount(BuildContext context, List<DailyLogAccount> accounts,
      DailyLogAccount account) {
    String locale = context.locale.toString();
    int decimals = account.wallet.decimals;
    String allDays =
        formatDailyLog(account.days, locale: locale, decimals: decimals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (accounts.length > 1)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: SelectChips(
              allowMultipleSelected: false,
              items: accounts,
              getLabel: (DailyLogAccount item) => item.wallet.name,
              getSelected: (DailyLogAccount item) =>
                  item.wallet.walletPk == account.wallet.walletPk,
              onSelected: (DailyLogAccount item) {
                setState(() => selectedWalletPk = item.wallet.walletPk);
              },
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: TextFont(
            text: account.wallet.name +
                " • " +
                account.days.length.toString() +
                (account.days.length == 1 ? " day" : " days"),
            fontSize: 15,
            textColor: getColor(context, "textLight"),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 13, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Button(
                  label: "Copy all",
                  icon: appStateSettings["outlinedIcons"]
                      ? Icons.copy_all_outlined
                      : Icons.copy_all_rounded,
                  onTap: () => copyToClipboard(
                    allDays,
                    customSnackbarDescription: account.wallet.name,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Builder(builder: (boxContext) {
                  return Button(
                    label: "export".tr(),
                    icon: appStateSettings["outlinedIcons"]
                        ? Icons.ios_share_outlined
                        : Icons.ios_share_rounded,
                    onTap: () => saveFile(
                      boxContext: boxContext,
                      dataStore: null,
                      dataString: allDays,
                      fileName: dailyLogFileName(account.wallet),
                      successMessage: "Daily log exported",
                      errorMessage: "Could not export daily log",
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        // Newest first, copying all keeps the oldest first
        for (DailyLogDay day in account.days.reversed)
          DailyLogDayCard(
            text: formatDailyLogDay(day, locale: locale, decimals: decimals),
            label: DateFormat.MMMMd(locale).format(day.day),
          ),
      ],
    );
  }

  String dailyLogFileName(TransactionWallet wallet) {
    String name = (widget.trip?.name ?? "daily-log") + "-" + wallet.name;
    name = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), "-");
    return "cashew-ew-" + name + ".txt";
  }
}

class DailyLogDayCard extends StatelessWidget {
  const DailyLogDayCard({required this.text, required this.label, super.key});
  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          color: getColor(context, "standardContainerColor"),
          borderRadius: BorderRadiusDirectional.circular(18),
        ),
        padding: const EdgeInsetsDirectional.only(
            start: 16, top: 12, bottom: 12, end: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SelectableText(
                text,
                style: TextStyle(
                  fontFamily: "Inconsolata",
                  fontSize: 15,
                  height: 1.35,
                  color: getColor(context, "black"),
                ),
              ),
            ),
            IconButton(
              tooltip: "Copy",
              onPressed: () =>
                  copyToClipboard(text, customSnackbarDescription: label),
              icon: Icon(
                appStateSettings["outlinedIcons"]
                    ? Icons.copy_outlined
                    : Icons.copy_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

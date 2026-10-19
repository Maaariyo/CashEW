import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/dailyLogPage.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/trekTravel.dart';
import 'package:budget/widgets/budgetContainer.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/util/showDatePicker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class TrekTravelPage extends StatefulWidget {
  const TrekTravelPage({super.key});

  @override
  State<TrekTravelPage> createState() => _TrekTravelPageState();
}

class _TrekTravelPageState extends State<TrekTravelPage> {
  late Future<List<Budget>> tripsFuture = getTrips();
  late Future<List<Budget>> candidatesFuture = getTripCandidates();

  void refresh() {
    setState(() {
      tripsFuture = getTrips();
      candidatesFuture = getTripCandidates();
    });
  }

  Future openNewTrip() async {
    await pushRoute(context, NewTripPage());
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      horizontalPaddingConstrained: true,
      dragDownToDismiss: true,
      title: "Trek & Travel",
      actions: [
        IconButton(
          padding: EdgeInsetsDirectional.all(15),
          tooltip: "New trip",
          onPressed: openNewTrip,
          icon: Icon(appStateSettings["outlinedIcons"]
              ? Icons.add_outlined
              : Icons.add_rounded),
        ),
      ],
      listWidgets: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 20, vertical: 5),
          child: TextFont(
            text:
                "A trip keeps its own book of expenses. Everything you add to it also shows up in your accounts, transactions and other budgets. While a trip is active, new transactions are added to it automatically.",
            fontSize: 14,
            maxLines: 10,
            textColor: getColor(context, "textLight"),
          ),
        ),
        FutureBuilder<List<Budget>>(
          future: tripsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return SizedBox.shrink();
            List<Budget> trips = snapshot.data ?? [];
            String? activeTripPk = getActiveTripPk();
            return Column(
              children: [
                if (trips.isEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 13, vertical: 15),
                    child: Button(
                      label: "Plan a trip",
                      icon: appStateSettings["outlinedIcons"]
                          ? Icons.luggage_outlined
                          : Icons.luggage_rounded,
                      onTap: openNewTrip,
                    ),
                  ),
                for (Budget trip in trips)
                  TripEntry(
                    trip: trip,
                    isActive: trip.budgetPk == activeTripPk,
                    onChanged: refresh,
                  ),
              ],
            );
          },
        ),
        FutureBuilder<List<Budget>>(
          future: candidatesFuture,
          builder: (context, snapshot) {
            List<Budget> candidates = snapshot.data ?? [];
            if (candidates.isEmpty) return SizedBox.shrink();
            return Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 13, vertical: 10),
              child: Button(
                label: "Use an existing budget as a trip",
                expandedLayout: true,
                color: Theme.of(context).colorScheme.secondaryContainer,
                textColor: Theme.of(context).colorScheme.onSecondaryContainer,
                onTap: () async {
                  Budget? picked = await openPopup(
                    context,
                    title: "Use an existing budget",
                    description:
                        "Budgets that only include transactions added to them can become trips",
                    onCancelLabel: "cancel".tr(),
                    onCancel: () => popRoute(context),
                    beforeDescriptionWidget: Column(
                      children: [
                        for (Budget candidate in candidates)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(top: 8),
                            child: Button(
                              label: candidate.name,
                              expandedLayout: true,
                              onTap: () => popRoute(context, candidate),
                            ),
                          ),
                      ],
                    ),
                  );
                  if (picked != null) {
                    await addTrip(picked);
                    refresh();
                  }
                },
              ),
            );
          },
        ),
        SizedBox(height: 50),
      ],
    );
  }
}

class TripEntry extends StatelessWidget {
  const TripEntry({
    required this.trip,
    required this.isActive,
    required this.onChanged,
    super.key,
  });
  final Budget trip;
  final bool isActive;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    bool over = tripIsOver(trip);
    String status = isActive
        ? "Active • new transactions are added here"
        : over
            ? "Ended"
            : "Not active";
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: TextFont(
              text: status,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              textColor: isActive
                  ? Theme.of(context).colorScheme.primary
                  : getColor(context, "textLight"),
            ),
          ),
          SizedBox(height: 6),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 13),
            child: BudgetContainer(budget: trip),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 13, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Button(
                    label: "Daily log",
                    fontSize: 14,
                    icon: appStateSettings["outlinedIcons"]
                        ? Icons.receipt_long_outlined
                        : Icons.receipt_long_rounded,
                    onTap: () => pushRoute(context, DailyLogPage(trip: trip)),
                  ),
                ),
                SizedBox(width: 8),
                if (over == false)
                  Expanded(
                    child: Button(
                      label: isActive ? "Pause" : "Make active",
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      onTap: () async {
                        await setActiveTripPk(isActive ? null : trip.budgetPk);
                        onChanged();
                      },
                    ),
                  ),
                if (over == false) SizedBox(width: 8),
                IconButton(
                  tooltip: "Remove from Trek & Travel",
                  onPressed: () async {
                    dynamic result = await openPopup(
                      context,
                      title: "Remove " + trip.name + "?",
                      description:
                          "The trip's budget and transactions are kept. It just stops being listed here.",
                      onSubmitLabel: "Remove",
                      onSubmit: () => popRoute(context, true),
                      onCancelLabel: "cancel".tr(),
                      onCancel: () => popRoute(context),
                    );
                    if (result == true) {
                      await removeTrip(trip.budgetPk);
                      onChanged();
                    }
                  },
                  icon: Icon(
                    appStateSettings["outlinedIcons"]
                        ? Icons.close_outlined
                        : Icons.close_rounded,
                    color: getColor(context, "textLight"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewTripPage extends StatefulWidget {
  const NewTripPage({super.key});

  @override
  State<NewTripPage> createState() => _NewTripPageState();
}

class _NewTripPageState extends State<NewTripPage> {
  String name = "";
  double? amount;
  DateTimeRange dates = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now().add(Duration(days: 6)),
  );

  bool get canSave => name.trim() != "" && (amount ?? 0) > 0;

  Future pickDates() async {
    DateTimeRangeOrAllTime picked = await showCustomDateRangePicker(
      context,
      DateTimeRangeOrAllTime(allTime: false, dateTimeRange: dates),
    );
    if (picked.dateTimeRange != null)
      setState(() => dates = picked.dateTimeRange!);
  }

  @override
  Widget build(BuildContext context) {
    String locale = context.locale.toString();
    return PageFramework(
      horizontalPaddingConstrained: true,
      dragDownToDismiss: true,
      title: "New trip",
      listWidgets: [
        SizedBox(height: 5),
        TextInput(
          labelText: "Where are you going?",
          icon: appStateSettings["outlinedIcons"]
              ? Icons.hiking_outlined
              : Icons.hiking_rounded,
          autoFocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (value) => setState(() => name = value),
        ),
        SizedBox(height: 12),
        TextInput(
          labelText: "Trip budget",
          icon: appStateSettings["outlinedIcons"]
              ? Icons.account_balance_wallet_outlined
              : Icons.account_balance_wallet_rounded,
          numbersOnly: true,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) =>
              setState(() => amount = double.tryParse(value.trim())),
        ),
        SizedBox(height: 12),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 13),
          child: Button(
            label: DateFormat.yMMMd(locale).format(dates.start) +
                " – " +
                DateFormat.yMMMd(locale).format(dates.end),
            expandedLayout: true,
            icon: appStateSettings["outlinedIcons"]
                ? Icons.date_range_outlined
                : Icons.date_range_rounded,
            color: Theme.of(context).colorScheme.secondaryContainer,
            textColor: Theme.of(context).colorScheme.onSecondaryContainer,
            onTap: pickDates,
          ),
        ),
        SizedBox(height: 25),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 13),
          child: Opacity(
            opacity: canSave ? 1 : 0.5,
            child: Button(
              label: "Start planning",
              expandedLayout: true,
              onTap: () async {
                if (canSave == false) return;
                await createTrip(
                  name: name.trim(),
                  startDate: dates.start,
                  endDate: dates.end,
                  amount: amount!,
                );
                popRoute(context);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 20, vertical: 15),
          child: TextFont(
            text:
                "The trip is created as a budget that only counts transactions added to it, so you can also find it under Budgets.",
            fontSize: 13,
            maxLines: 5,
            textColor: getColor(context, "textLight"),
          ),
        ),
      ],
    );
  }
}

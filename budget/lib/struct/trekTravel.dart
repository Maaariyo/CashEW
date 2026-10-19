// Trek & Travel: a trip is an "added transactions only" budget over the trip
// dates. Its transactions stay in the main ledger, accounts and other budgets,
// and the trip groups them so it works like its own book.
//
// Which budgets are trips, and which trip is active, is stored in settings
// ("trekTravelTrips", "trekTravelActiveTrip"), which are saved in the database
// and included in backups. No schema change is needed.
import 'package:budget/database/tables.dart';
import 'package:budget/struct/dailyLog.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:drift/drift.dart' hide Column;

// Categories with this key are balance corrections and transfers
const String balanceCorrectionCategoryPk = "0";

List<String> getTripPks() =>
    List<String>.from(appStateSettings["trekTravelTrips"] ?? []);

String? getActiveTripPk() => appStateSettings["trekTravelActiveTrip"];

Future setTripPks(List<String> tripPks) =>
    updateSettings("trekTravelTrips", List<String>.from(tripPks),
        updateGlobalState: false);

Future setActiveTripPk(String? tripPk) =>
    updateSettings("trekTravelActiveTrip", tripPk, updateGlobalState: false);

bool isTrip(String budgetPk) => getTripPks().contains(budgetPk);

// Trips that still exist, newest first. Deleted budgets are forgotten.
Future<List<Budget>> getTrips() async {
  List<String> tripPks = getTripPks();
  List<Budget> trips = (await database.getAllBudgets())
      .where((budget) => tripPks.contains(budget.budgetPk))
      .toList();
  if (trips.length != tripPks.length) {
    await setTripPks(trips.map((trip) => trip.budgetPk).toList());
    if (trips.any((trip) => trip.budgetPk == getActiveTripPk()) == false)
      await setActiveTripPk(null);
  }
  trips.sort((a, b) => b.startDate.compareTo(a.startDate));
  return trips;
}

// Added only budgets that could be turned into trips
Future<List<Budget>> getTripCandidates() async {
  List<String> tripPks = getTripPks();
  return (await database.getAllBudgetsAddedTransactionsOnly())
      .where((budget) => tripPks.contains(budget.budgetPk) == false)
      .toList();
}

DateTime endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59);

bool tripIsOver(Budget trip) => DateTime.now().isAfter(endOfDay(trip.endDate));

Future<Budget> createTrip({
  required String name,
  required DateTime startDate,
  required DateTime endDate,
  required double amount,
  String? colour,
}) async {
  Budget trip = Budget(
    budgetPk: uuid.v4(),
    name: name,
    amount: amount,
    colour: colour,
    startDate: DateTime(startDate.year, startDate.month, startDate.day),
    endDate: endOfDay(endDate),
    walletFks: null,
    categoryFks: null,
    categoryFksExclude: null,
    income: false,
    archived: false,
    addedTransactionsOnly: true,
    periodLength: 1,
    reoccurrence: BudgetReoccurence.custom,
    dateCreated: DateTime.now(),
    dateTimeModified: null,
    pinned: true,
    order: await database.getAmountOfBudgets(),
    walletFk: appStateSettings["selectedWalletPk"] ?? "0",
    budgetTransactionFilters: [],
    memberTransactionFilters: null,
    isAbsoluteSpendingLimit: false,
  );
  await database.createOrUpdateBudget(trip, updateSharedEntry: false);
  await addTrip(trip);
  return trip;
}

Future addTrip(Budget budget) async {
  await setTripPks([...getTripPks(), budget.budgetPk]);
  if (tripIsOver(budget) == false) await setActiveTripPk(budget.budgetPk);
}

// The budget stays, it just stops being listed as a trip
Future removeTrip(String budgetPk) async {
  await setTripPks(getTripPks()..remove(budgetPk));
  if (getActiveTripPk() == budgetPk) await setActiveTripPk(null);
}

// New transactions are added to the active trip until it ends
Future<Budget?> getActiveTripForNewTransaction() async {
  String? activeTripPk = getActiveTripPk();
  if (activeTripPk == null || isTrip(activeTripPk) == false) return null;
  try {
    Budget trip = await database.getBudgetInstance(activeTripPk);
    if (trip.archived || tripIsOver(trip)) return null;
    return trip;
  } catch (e) {
    return null;
  }
}

class DailyLogAccount {
  DailyLogAccount({required this.wallet, required this.days});
  final TransactionWallet wallet;
  // Oldest first
  final List<DailyLogDay> days;
}

// Daily logs for every account that has logged expenses. With a trip, only
// the trip's expenses are listed, but the balance is still the account's.
Future<List<DailyLogAccount>> loadDailyLogs({String? tripBudgetPk}) async {
  Map<String, String> categoryNames = {
    for (TransactionCategory category
        in await database.getAllCategories(includeSubCategories: true))
      category.categoryPk: category.name
  };
  List<DailyLogAccount> accounts = [];
  for (TransactionWallet wallet in await database.getAllWallets()) {
    List<Transaction> transactions = await (database.select(
            database.transactions)
          ..where((t) =>
              t.walletFk.equals(wallet.walletPk) & t.paid.equals(true)))
        .get();
    List<DailyLogEntry> entries = [
      for (Transaction transaction in transactions)
        DailyLogEntry(
          date: transaction.dateCreated,
          amount: transaction.amount,
          name: transaction.name.trim() != ""
              ? transaction.name.trim()
              : (categoryNames[transaction.categoryFk] ?? ""),
          isActivity: transaction.income == false &&
              transaction.amount < 0 &&
              transaction.categoryFk != balanceCorrectionCategoryPk &&
              (tripBudgetPk == null ||
                  transaction.sharedReferenceBudgetPk == tripBudgetPk),
        ),
    ];
    List<DailyLogDay> days = buildDailyLogDays(entries);
    if (days.isNotEmpty) accounts.add(DailyLogAccount(wallet: wallet, days: days));
  }
  return accounts;
}

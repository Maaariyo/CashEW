import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/quickAdd.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/trekTravel.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/util/appLinks.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const List<String> quickAddExamples = [
  "250 taxi",
  "1.2k groceries yesterday",
  "80 coffee #dining",
  "+50000 salary",
  "450 dinner on friday",
];

// Log a transaction from one line of text. The category comes from a
// #hashtag or from titles used before; otherwise it is asked for on save.
class QuickAddPage extends StatefulWidget {
  const QuickAddPage({super.key});

  @override
  State<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends State<QuickAddPage> {
  TextEditingController controller = TextEditingController();
  FocusNode focusNode = FocusNode();
  QuickAddEntry? entry;
  String? guessedCategory;
  Budget? activeTrip;
  List<Transaction> added = [];
  bool saving = false;

  @override
  void initState() {
    super.initState();
    getActiveTripForNewTransaction().then((trip) {
      if (mounted) setState(() => activeTrip = trip);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void onChanged(String text) {
    QuickAddEntry parsed = parseQuickAdd(text, now: DateTime.now());
    setState(() => entry = text.trim() == "" ? null : parsed);
    guessCategory(parsed);
  }

  // Shows which category will be used, like processAddTransactionFromParams
  // picks it
  Future guessCategory(QuickAddEntry parsed) async {
    String? name;
    if (parsed.category != null) {
      name = (await database.getRelatingCategory(parsed.category!))?.name;
    } else if (parsed.title != "") {
      name = (await database.getSimilarAssociatedTitles(
              title: parsed.title, limit: 1))
          .firstOrNull
          ?.category
          .name;
    }
    if (mounted && entry == parsed) setState(() => guessedCategory = name);
  }

  Future add() async {
    QuickAddEntry? current = entry;
    if (current == null || current.amount == null || saving) return;
    setState(() => saving = true);
    DateTime now = DateTime.now();
    DateTime? date = current.date == null
        ? null
        : DateTime(current.date!.year, current.date!.month, current.date!.day,
            now.hour, now.minute, now.second);
    Transaction? transaction = await processAddTransactionFromParams(context, {
      "amount": current.signedAmount.toString(),
      if (current.title != "") "title": current.title,
      if (date != null) "date": date.toIso8601String(),
      if (current.category != null) "category": current.category,
    });
    // Trek & Travel: also add it to the active trip
    if (transaction != null && activeTrip != null && current.income == false) {
      Transaction withTrip = transaction.copyWith(
          sharedReferenceBudgetPk: Value(activeTrip!.budgetPk));
      await database.createOrUpdateTransaction(withTrip,
          originalTransaction: transaction);
      transaction = withTrip;
    }
    if (!mounted) return;
    setState(() {
      saving = false;
      if (transaction != null) {
        added.insert(0, transaction);
        controller.clear();
        entry = null;
        guessedCategory = null;
      }
    });
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    TransactionWallet? wallet =
        allWallets.indexedByPk[appStateSettings["selectedWalletPk"]];
    QuickAddEntry? current = entry;
    return PageFramework(
      horizontalPaddingConstrained: true,
      dragDownToDismiss: true,
      title: "Quick Add",
      listWidgets: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 20, vertical: 4),
          child: TextFont(
            text:
                "Type an amount and what it was for. Add a date like \"yesterday\" or \"on friday\", a #category, or + for income.",
            fontSize: 14,
            maxLines: 5,
            textColor: getColor(context, "textLight"),
          ),
        ),
        SizedBox(height: 10),
        TextInput(
          labelText: "250 taxi yesterday",
          controller: controller,
          focusNode: focusNode,
          autoFocus: true,
          onChanged: onChanged,
          onSubmitted: (_) => add(),
          textInputAction: TextInputAction.done,
          icon: appStateSettings["outlinedIcons"]
              ? Icons.bolt_outlined
              : Icons.bolt_rounded,
        ),
        if (current == null)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 13, vertical: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (String example in quickAddExamples)
                  ActionChip(
                    label: TextFont(text: example, fontSize: 14),
                    onPressed: () {
                      controller.text = example;
                      onChanged(example);
                    },
                  ),
              ],
            ),
          ),
        if (current != null)
          QuickAddPreview(
            entry: current,
            category: guessedCategory,
            walletName: wallet?.name,
            tripName: current.income ? null : activeTrip?.name,
          ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 13, vertical: 8),
          child: Opacity(
            opacity: current?.amount != null && !saving ? 1 : 0.5,
            child: Button(
              label: current?.amount == null && current != null
                  ? "Add an amount"
                  : "Add",
              expandedLayout: true,
              onTap: add,
            ),
          ),
        ),
        if (added.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(
                start: 20, end: 20, top: 18, bottom: 4),
            child: TextFont(
              text: "Added just now",
              fontSize: 15,
              fontWeight: FontWeight.bold,
              textColor: getColor(context, "textLight"),
            ),
          ),
        for (Transaction transaction in added)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: getColor(context, "incomeAmount"),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextFont(
                    text: transaction.name == "" ? "—" : transaction.name,
                    fontSize: 15,
                  ),
                ),
                TextFont(
                  text: convertToMoney(allWallets, transaction.amount,
                      currencyKey: allWallets
                          .indexedByPk[transaction.walletFk]?.currency),
                  fontSize: 15,
                  textColor: transaction.amount > 0
                      ? getColor(context, "incomeAmount")
                      : getColor(context, "expenseAmount"),
                ),
              ],
            ),
          ),
        SizedBox(height: 40),
      ],
    );
  }
}

class QuickAddPreview extends StatelessWidget {
  const QuickAddPreview({
    required this.entry,
    required this.category,
    required this.walletName,
    required this.tripName,
    super.key,
  });
  final QuickAddEntry entry;
  final String? category;
  final String? walletName;
  final String? tripName;

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: TextFont(
                  text: label,
                  fontSize: 14,
                  textColor: getColor(context, "textLight"),
                ),
              ),
              Expanded(
                child: TextFont(
                  text: value,
                  fontSize: 15,
                  maxLines: 2,
                  textColor: color,
                ),
              ),
            ],
          ),
        );
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: getColor(context, "standardContainerColor"),
          borderRadius: BorderRadiusDirectional.circular(18),
        ),
        padding:
            const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          children: [
            row(
              entry.income ? "Income" : "Expense",
              entry.amount == null
                  ? "No amount yet"
                  : convertToMoney(allWallets, entry.amount!),
              color: entry.amount == null
                  ? getColor(context, "textLight")
                  : entry.income
                      ? getColor(context, "incomeAmount")
                      : getColor(context, "expenseAmount"),
            ),
            row("Title", entry.title == "" ? "—" : entry.title),
            row("Date", getWordedDate(entry.date ?? DateTime.now())),
            row(
              "Category",
              category ??
                  (entry.category != null
                      ? "No \"" +
                          entry.category! +
                          "\" category, asked when you add it"
                      : "Asked when you add it"),
            ),
            if (walletName != null) row("Wallet", walletName!),
            if (tripName != null) row("Trip", tripName!),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Provider.of<AllWallets>(context).list
// Provider.of<AllWallets>(context).indexedByPk

// Examples: Get the current selected wallets decimals
// Provider.of<AllWallets>(context).indexedByPk[appStateSettings["selectedWalletPk"]]?.decimals

class WatchAllWallets extends StatelessWidget {
  const WatchAllWallets({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamProvider<AllWallets>.value(
      initialData: AllWallets(list: [], indexedByPk: {}),
      value: database.watchAllWalletsIndexed(),
      child: child,
    );
  }
}

// Broadcast, so the provider below can subscribe again whenever it is
// remounted (for example after RestartApp). A single-subscription controller
// throws on the second listen, after which no widget can read the selected
// wallet and wallets disappear until the app is restarted. New subscribers
// start from initialData, which reads the current selection from settings.
final selectedWalletPkController =
    StreamController<SelectedWalletPk>.broadcast();

class WatchSelectedWalletPk extends StatelessWidget {
  const WatchSelectedWalletPk({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamProvider<SelectedWalletPk>.value(
      initialData: SelectedWalletPk(
          selectedWalletPk: appStateSettings["selectedWalletPk"] ?? "0"),
      value: selectedWalletPkController.stream,
      child: child,
    );
  }
}

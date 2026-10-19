// CashEW: every "Cashew Pro" feature is unlocked for everyone.
//
// Upstream gates these features behind an in-app purchase:
//   - more than one budget              (premiumPopupBudgets)
//   - more than one goal / long term loan (premiumPopupObjectives)
//   - past budget periods / history     (premiumPopupPastBudgets)
//   - all-time spending history graph   (FadeOutAndLockFeature)
//   - custom colour picker              (LockedFeature)
// plus a nag screen after adding transactions (premiumPopupAddTransaction).
//
// The store integration (in_app_purchase) has been removed entirely. The
// function and widget names are kept so upstream call sites merge cleanly.
import 'package:budget/database/tables.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:flutter/material.dart';

bool hidePremiumPopup() => true;

Future<bool> premiumPopupPushRoute(BuildContext context) async => true;

Future<bool> premiumPopupBudgets(BuildContext context) async => true;

Future<bool> premiumPopupObjectives(BuildContext context,
        {required ObjectiveType objectiveType}) async =>
    true;

Future<bool> premiumPopupPastBudgets(BuildContext context) async => true;

Future<bool> premiumPopupAddTransaction(BuildContext context) async => true;

// Previously opened the paywall before running actionAfter
class LockedFeature extends StatelessWidget {
  const LockedFeature(
      {required this.child, this.actionAfter, this.showLock = false, Key? key})
      : super(key: key);
  final Widget child;
  final Function? actionAfter;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: () {
        if (actionAfter != null) actionAfter!();
      },
      borderRadius: 20,
      color: Colors.transparent,
      child: IgnorePointer(child: child),
    );
  }
}

// Previously faded the child out behind an "Unlock with Cashew Pro" overlay
class FadeOutAndLockFeature extends StatelessWidget {
  const FadeOutAndLockFeature({
    required this.child,
    this.actionAfter,
    this.hasInitiallyDismissed = false,
    this.fadeOutQuick = false,
    super.key,
  });
  final Widget child;
  final VoidCallback? actionAfter;
  final bool hasInitiallyDismissed;
  final bool fadeOutQuick;

  @override
  Widget build(BuildContext context) => child;
}

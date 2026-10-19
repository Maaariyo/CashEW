# How Cashew Pro is gated

Analysis of upstream Cashew 5.4.3+416 (commit `9cfbe50c`, March 2026). Cashew is open source under
GPL-3.0, so this was done by reading the source, not by decompiling the APK.

## The single switch

All Pro gating lives in `budget/lib/pages/premiumPage.dart`:

```dart
bool hidePremiumPopup() {
  return premiumPopupEnabled == false ||
      appStateSettings["purchaseID"] != null ||
      appStateSettings["previewDemo"] == true;
}
```

A feature is unlocked when any of these is true:

| Condition | When it happens |
|---|---|
| `premiumPopupEnabled == false` | Running on the web, **or** the app could not reach Google Play / the App Store at startup (`initializeStoreAndPurchases` sets it to false), **or** a debug build (`tryStoreEnabled` is false in debug mode) |
| `purchaseID != null` | The store reported a purchased or restored product (`cashew.pro.monthly`, `cashew.pro.yearly`, `cashew.pro.lifetime` / `cashew.pro.life` on iOS) |
| `previewDemo == true` | The user opened the demo from onboarding |

There is no server-side receipt check. The purchase id is a value in local settings
(SharedPreferences), reset and re-read from the store on each launch. In practice the paywall only
applies to users who installed from Google Play or the App Store; the PWA, de-Googled phones and
GitHub APKs on devices without Play Services already get every feature.

## What is gated

| Gate | Call site | Behaviour when locked |
|---|---|---|
| `premiumPopupBudgets` | `addBudgetPage.dart` | Paywall when creating a budget and one already exists. First budget is free. |
| `premiumPopupObjectives` | `addObjectivePage.dart` | Paywall when creating a goal (or long term loan) and one of that type already exists. |
| `premiumPopupPastBudgets` | `budgetPage.dart` | Paywall when navigating to a previous budget period. |
| `FadeOutAndLockFeature` | `walletDetailsPage.dart` | All-time spending history graph fades out behind an "Unlock with Cashew Pro" overlay. |
| `LockedFeature` | `selectColor.dart` | The custom colour (colour wheel) option opens the paywall. Preset colours are free. |
| `premiumPopupAddTransaction` | `addTransactionPage.dart` | Not a lock. After more than 5 new transactions, at most once a day, shows the Pro screen as a dismissible nag. |
| `PremiumBanner` | `settingsPage.dart` | Upgrade banner at the top of settings. |

Everything else (Drive backup, sync, multiple currencies and accounts, subscriptions, CSV import,
widgets, notifications, biometric lock) was never gated.

## What CashEW changes

- `premiumPage.dart` is replaced with shims: all `premiumPopup*` functions return `true`,
  `LockedFeature` runs its action directly and `FadeOutAndLockFeature` renders its child.
- `in_app_purchase` is removed from `pubspec.yaml`, so the app no longer talks to Play Billing or
  StoreKit and does not declare the billing permission.
- The store initialisation call (`navigationFramework.dart`), the `ProductsState` key and the
  settings banner are removed.

Function names are kept so upstream call sites do not change, which keeps `git merge upstream/main`
conflicts confined to `premiumPage.dart`.

## Upstream monetisation, for context

Cashew's model is freemium with a deliberately soft paywall: the core use case (logging
transactions against one budget) is free, Pro targets heavier users (several budgets, history,
goals), and the store check fails open. The author has chosen GPL-3.0, which explicitly permits
redistributing modified versions, including ones without the paywall. What the GPL does not grant is
the Cashew name and icon, which is why distribution through an app store should use different
branding.

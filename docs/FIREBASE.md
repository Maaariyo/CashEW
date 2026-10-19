# Cloud features: Google Drive and Firebase

CashEW ships without any cloud credentials. Upstream Cashew used the developer's own Firebase
project (`budget-app-flutter`) and Google OAuth clients; those are tied to the `com.budget.tracker_app`
package and signing key, so they would not work for this fork and should not be used by it anyway.

Without configuration the app is fully functional offline. You only need this page for:

1. **Google Drive backup and sync** (Google sign-in)
2. **Shared budgets and in-app feedback** (Firestore)

## 1. Google Drive backup and sync

Drive access uses `google_sign_in` and the Drive API directly; it does not need Firebase. On
Android, Google only issues tokens to an app whose package name and signing certificate are
registered with an OAuth client.

1. Create a project in the [Google Cloud console](https://console.cloud.google.com/).
2. Enable the **Google Drive API** (and the **Gmail API** if you use email-based auto transactions).
3. Configure the OAuth consent screen. While in *Testing* mode, add your Google account as a test user.
   The app requests the `drive.appdata` scope, plus `drive.file` for attachments.
4. Create an OAuth client of type **Android**:
   - Package name: `io.github.maaariyo.cashewew`
   - SHA-1: from the key that signs your APK, e.g.
     `keytool -list -v -keystore release.jks -alias <alias>`

A CI build signed with a throwaway debug key has a different SHA-1 every run, so set up the
`KEYSTORE_*` secrets (see the README) before registering the SHA-1.

For iOS, create an **iOS** OAuth client for bundle id `io.github.maaariyo.cashewew`, put its client id
in `GOOGLE_IOS_CLIENT_ID`, and replace `YOUR-IOS-CLIENT-ID` in `budget/ios/Runner/Info.plist` with
the reversed client id.

## 2. Firebase (shared budgets, feedback)

1. Create a Firebase project and add an Android app with package `io.github.maaariyo.cashewew`
   (and iOS / web apps if you build those).
2. Enable **Authentication** with the **Google** and **Anonymous** providers.
3. Create a **Cloud Firestore** database. Example rules that only let signed-in users touch budgets
   they own or are members of are your responsibility; do not leave the database in test mode.
4. Copy `budget/firebase.env.example.json` to `budget/firebase.env.json` and fill in the values from
   *Project settings → Your apps*. The file is git-ignored.
5. Build with the config:

   ```bash
   flutter build apk --release --dart-define-from-file=firebase.env.json
   ```

   In CI, paste the JSON into the `FIREBASE_ENV_JSON` repository secret.

Firebase is only initialised when `FIREBASE_PROJECT_ID` and the current platform's app id are set
(`DefaultFirebaseOptions.isConfigured`). Otherwise Firestore helpers return `null` and the features
that depend on them report that they could not connect.

You may also drop a `google-services.json` into `budget/android/app/`; the Gradle plugin is applied
only when that file exists. It is not required, since options are passed in code.

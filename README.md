 # Golden Crust Bakery

A SwiftUI bakery app for iOS 27, backed by Firebase. Browse baked goods, add them to a cart that follows you across devices, and read recipes.

## Features

- **Sign in / sign up** with email and password, or **Continue with Google** (Firebase Authentication)
- **Shop** — 14 SKUs across Bread, Pastry, Cake, Cookies and Drinks, with category filter and search
- **Cart** — add, change quantities, see the total; saved to Cloud Firestore per user
- **Recipes** — 6 recipes with ingredients and step-by-step method
- **Profile** — sign out, or permanently delete your account and saved cart

## Tech stack

| | |
|---|---|
| UI | SwiftUI, Swift 6, iOS 27 |
| Auth | Firebase Authentication (Email/Password, Google via GoogleSignIn-iOS) |
| Data | Cloud Firestore (Enterprise edition, database `bakery`, `asia-south1`) |
| Protection | Firebase App Check (App Attest on device, debug provider on simulator), Firestore Security Rules |
| Packages | firebase-ios-sdk 12.19.2, GoogleSignIn-iOS 10.0.0 (Swift Package Manager) |

## Project structure

```
Bakery/
├── BakeryApp.swift        App entry, Firebase + App Check setup, colour theme
├── AuthView.swift         Sign in / sign up / Google, AuthModel
├── MainTabView.swift      Shop, product detail, recipes, cart, profile screens
├── Catalog.swift          Products, recipes, Firestore-backed Cart
├── Assets.xcassets
└── GoogleService-Info.plist
firestore.rules            Security rules for carts/{uid}
firestore.rules.test.mjs   Rules tests against the local emulator
firebase.json              Auth providers + Firestore config
```

## Getting started

Requires Xcode 27 and the iOS 27 simulator.

1. Clone the repo and open `Bakery.xcodeproj`. Xcode resolves the Swift packages on first open.
2. **App Check debug token** — Firestore rejects requests without a valid App Check token, including from the simulator. Create one and register it with your Firebase app:

   ```bash
   npx -y firebase-tools@latest appcheck:debugtokens:create --app <your-ios-app-id> --display-name "Simulator"
   ```

   Then in Xcode: **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**, add `AppCheckDebugToken` with the token as its value. Keep the scheme unshared (the default) so the token stays in `xcuserdata/`, which is gitignored.
3. Run on an iPhone simulator **from Xcode** (the environment variable only reaches the app when Xcode launches it).

### Using your own Firebase project

The included `GoogleService-Info.plist` points at the original project, and its API key only works for bundle ID `com.prajyot.Bakery`. To run your own copy:

1. Create a Firebase project, register an iOS app with your bundle ID, and replace `Bakery/GoogleService-Info.plist` with its config.
2. Change `PRODUCT_BUNDLE_IDENTIFIER` in the project, and the URL scheme in `Info.plist` to your `REVERSED_CLIENT_ID`.
3. Update `.firebaserc` and the `supportEmail` in `firebase.json`, then enable sign-in and deploy the rules:

   ```bash
   npx -y firebase-tools@latest deploy --only auth,firestore
   ```

4. Enable the **Firebase App Check API** in Google Cloud before turning on App Check enforcement — otherwise the app can't get tokens and every Firestore call fails with "Missing or insufficient permissions".

## Firestore data model and rules

Each user's cart is one document:

```
carts/{uid}
  items:     map<SKU, int>   quantities 1–99, SKUs must be in the catalog
  updatedAt: timestamp       server time of the write
```

Users can only read, write and delete their own cart, and the rules reject unknown SKUs, out-of-range quantities and extra fields. **Adding a product means adding its SKU to `validSkus()` in `firestore.rules` too.**

Run the rules tests against the local emulator (needs Java):

```bash
npx -y firebase-tools@latest emulators:exec --only firestore --project demo-bakery "node firestore.rules.test.mjs"
```

## Security notes

- The API key in `GoogleService-Info.plist` is not a secret — it ships inside every copy of the app. It is restricted to this bundle ID and to the five Google APIs the app uses; App Check and the Security Rules are what actually protect the data.
- Never commit an App Check debug token.
- Before shipping to a real device or TestFlight: set your Apple Team ID on the Firebase iOS app and register App Attest, change `Bakery.entitlements` to `production`, and delete any debug tokens.

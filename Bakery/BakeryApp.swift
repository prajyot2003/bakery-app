import SwiftUI
import FirebaseCore
import GoogleSignIn
import FirebaseAuth
import FirebaseAppCheck

/// Proves requests come from this genuine app. Simulator uses a debug token set as the
/// `AppCheckDebugToken` environment variable in your (gitignored) Xcode scheme.
final class BakeryAppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        AppCheckDebugProvider(app: app)
        #else
        AppAttestProvider(app: app)
        #endif
    }
}

@main
struct BakeryApp: App {
    @State private var auth: AuthModel
    @State private var cart = Cart()

    init() {
        // Must be set before configure(), or App Check uses no provider.
        AppCheck.setAppCheckProviderFactory(BakeryAppCheckFactory())
        FirebaseApp.configure()
        _auth = State(initialValue: AuthModel())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.email == nil {
                    AuthView()
                } else {
                    MainTabView()
                }
            }
            .environment(auth)
            .environment(cart)
            .tint(Theme.cocoa)
            .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
            .task(id: auth.email) { await cart.load(uid: Auth.auth().currentUser?.uid) }
        }
    }
}

enum Theme {
    static let sand = Color(hex: 0xF0D7A7)
    static let terracotta = Color(hex: 0xC37960)
    static let cocoa = Color(hex: 0x894E3F)
    static let cream = Color(hex: 0xEEE1BA)
    static let mocha = Color(hex: 0x9C634F)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

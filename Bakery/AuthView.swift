import SwiftUI
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

struct AuthMessage: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

@MainActor @Observable
final class AuthModel {
    static let minPasswordLength = 8   // keep in sync with the Firebase password policy

    private(set) var email: String? = Auth.auth().currentUser?.email
    @ObservationIgnored private var handle: AuthStateDidChangeListenerHandle?

    init() {
        // Single source of truth for signed-in state. Also fires when Firebase ends the
        // session server-side (account disabled/deleted, refresh token revoked).
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            MainActor.assumeIsolated { self?.email = user?.email }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signUp(name: String, email: String, password: String) async throws {
        guard password.count >= Self.minPasswordLength else {
            throw AuthMessage("Password must be at least \(Self.minPasswordLength) characters.")
        }
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let change = result.user.createProfileChangeRequest()
        change.displayName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
        try await change.commitChanges()
        try? await result.user.sendEmailVerification()   // best effort; sign-up still succeeds
    }

    /// Deletes the Firebase account. Callers delete the user's Firestore data first,
    /// since rules deny access once the account is gone.
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await user.delete()
        } catch let e as NSError where e.code == AuthErrorCode.requiresRecentLogin.rawValue {
            throw AuthMessage("For your security, sign out and sign back in, then delete your account.")
        }
        GIDSignIn.sharedInstance.signOut()
    }

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID,
              let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController
        else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let google = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
        guard let idToken = google.user.idToken?.tokenString else { return }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                       accessToken: google.user.accessToken.tokenString)
        try await Auth.auth().signIn(with: credential)
    }

    var displayName: String { Auth.auth().currentUser?.displayName ?? "Baker" }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
    }
}

struct AuthView: View {
    @Environment(AuthModel.self) private var auth
    @State private var isSignUp = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("🥐").font(.system(size: 80)).padding(.top, 60)
                Text("Golden Crust Bakery")
                    .font(.largeTitle.bold()).foregroundStyle(Theme.cocoa)
                Text(isSignUp ? "Create your account" : "Welcome back")
                    .foregroundStyle(Theme.mocha)

                VStack(spacing: 12) {
                    if isSignUp {
                        field("Name", text: $name).textContentType(.name)
                    }
                    field("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField(isSignUp ? "Password (\(AuthModel.minPasswordLength)+ characters)" : "Password",
                                text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding().background(Theme.sand, in: .rect(cornerRadius: 12))
                }

                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }

                Button(action: submit) {
                    Group {
                        if loading { ProgressView().tint(.white) } else { Text(isSignUp ? "Sign Up" : "Sign In").bold() }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Theme.cocoa, in: .rect(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(loading || email.isEmpty || password.isEmpty || (isSignUp && name.isEmpty))

                HStack {
                    Rectangle().frame(height: 1)
                    Text("or").font(.footnote)
                    Rectangle().frame(height: 1)
                }
                .foregroundStyle(Theme.mocha.opacity(0.6))

                Button { run { try await auth.signInWithGoogle() } } label: {
                    HStack(spacing: 10) {
                        Image(.googleLogo).resizable().frame(width: 20, height: 20)
                        Text("Continue with Google").bold().foregroundStyle(Color(hex: 0x1F1F1F))
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(.white, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.mocha.opacity(0.4)))
                }
                .disabled(loading)

                Button(isSignUp ? "Already have an account? Sign In" : "New here? Create an account") {
                    isSignUp.toggle(); error = nil
                }
                .foregroundStyle(Theme.terracotta)
            }
            .padding(24)
        }
        .background(Theme.cream.ignoresSafeArea())
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .autocorrectionDisabled()
            .padding().background(Theme.sand, in: .rect(cornerRadius: 12))
    }

    private func submit() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        run {
            if isSignUp {
                try await auth.signUp(name: name, email: trimmed, password: password)
            } else {
                try await auth.signIn(email: trimmed, password: password)
            }
        }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        loading = true; error = nil
        Task {
            do {
                try await action()
            } catch let e as GIDSignInError where e.code == .canceled {
                // user dismissed the Google sheet — not an error
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}

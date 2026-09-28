import SwiftUI

struct MainTabView: View {
    @Environment(Cart.self) private var cart

    var body: some View {
        TabView {
            Tab("Shop", systemImage: "storefront") { ShopView() }
            Tab("Recipes", systemImage: "book") { RecipesView() }
            Tab("Cart", systemImage: "cart") { CartView() }
                .badge(cart.count)
            Tab("Profile", systemImage: "person") { ProfileView() }
        }
    }
}

// MARK: - Shop

struct ShopView: View {
    @State private var category = "All"
    @State private var search = ""

    private var filtered: [Product] {
        Catalog.products.filter {
            (category == "All" || $0.category == category) &&
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(["All"] + Catalog.categories, id: \.self) { c in
                            Button(c) { category = c }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(category == c ? Theme.cocoa : Theme.sand, in: .capsule)
                                .foregroundStyle(category == c ? .white : Theme.cocoa)
                        }
                    }
                    .padding(.horizontal)
                }
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 14) {
                    ForEach(filtered) { p in
                        NavigationLink(value: p) { ProductCard(product: p) }
                            .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Theme.cream)
            .navigationTitle("Golden Crust")
            .searchable(text: $search, prompt: "Search baked goods")
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
        }
    }
}

struct ProductCard: View {
    @Environment(Cart.self) private var cart
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(product.emoji).font(.system(size: 56)).frame(maxWidth: .infinity)
                .padding(.vertical, 12).background(Theme.cream, in: .rect(cornerRadius: 12))
            Text(product.name).font(.headline).foregroundStyle(Theme.cocoa).lineLimit(1)
            Text(product.id).font(.caption2).foregroundStyle(Theme.mocha)
            HStack {
                Text(product.price, format: .currency(code: "USD")).bold().foregroundStyle(Theme.cocoa)
                Spacer()
                Button { cart.add(product) } label: {
                    Image(systemName: "plus").bold().padding(8)
                        .background(Theme.terracotta, in: .circle).foregroundStyle(.white)
                }
                .accessibilityLabel("Add \(product.name) to cart")
            }
        }
        .padding(10)
        .background(Theme.sand, in: .rect(cornerRadius: 16))
    }
}

struct ProductDetailView: View {
    @Environment(Cart.self) private var cart
    let product: Product

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(product.emoji).font(.system(size: 120)).frame(maxWidth: .infinity)
                    .padding(.vertical, 30).background(Theme.sand, in: .rect(cornerRadius: 24))
                Text(product.name).font(.largeTitle.bold()).foregroundStyle(Theme.cocoa)
                Text("SKU \(product.id) · \(product.category)").foregroundStyle(Theme.mocha)
                Text(product.price, format: .currency(code: "USD")).font(.title2.bold()).foregroundStyle(Theme.terracotta)
                Text(product.detail).foregroundStyle(Theme.cocoa)
                Button { cart.add(product) } label: {
                    Label("Add to Cart", systemImage: "cart.badge.plus").bold()
                        .frame(maxWidth: .infinity).padding()
                        .background(Theme.cocoa, in: .rect(cornerRadius: 12)).foregroundStyle(.white)
                }
                if let qty = cart.items[product] {
                    Text("\(qty) in cart").font(.footnote).foregroundStyle(Theme.mocha).frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .background(Theme.cream)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Recipes

struct RecipesView: View {
    var body: some View {
        NavigationStack {
            List(Catalog.recipes) { r in
                NavigationLink {
                    RecipeDetailView(recipe: r)
                } label: {
                    HStack(spacing: 14) {
                        Text(r.emoji).font(.largeTitle)
                        VStack(alignment: .leading) {
                            Text(r.name).font(.headline).foregroundStyle(Theme.cocoa)
                            Label(r.time, systemImage: "clock").font(.caption).foregroundStyle(Theme.mocha)
                        }
                    }
                }
                .listRowBackground(Theme.sand)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .navigationTitle("Recipes")
        }
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe

    var body: some View {
        List {
            Section {
                HStack { Text(recipe.emoji).font(.system(size: 60)); Spacer(); Label(recipe.time, systemImage: "clock") }
                    .foregroundStyle(Theme.mocha)
            }
            Section("Ingredients") {
                ForEach(recipe.ingredients, id: \.self) { Label($0, systemImage: "circle.fill").labelStyle(Bullet()) }
            }
            Section("Method") {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top) {
                        Text("\(i + 1)").bold().foregroundStyle(.white).frame(width: 26, height: 26)
                            .background(Theme.terracotta, in: .circle)
                        Text(step)
                    }
                }
            }
        }
        .foregroundStyle(Theme.cocoa)
        .listRowBackground(Theme.sand)
        .scrollContentBackground(.hidden)
        .background(Theme.cream)
        .navigationTitle(recipe.name)
    }

    struct Bullet: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack { configuration.icon.font(.system(size: 6)).foregroundStyle(Theme.terracotta); configuration.title }
        }
    }
}

// MARK: - Cart

struct CartView: View {
    @Environment(Cart.self) private var cart
    @State private var ordered = false

    var body: some View {
        NavigationStack {
            Group {
                if cart.lines.isEmpty {
                    ContentUnavailableView("Your cart is empty", systemImage: "cart",
                                           description: Text("Add something delicious from the Shop."))
                } else {
                    List {
                        ForEach(cart.lines, id: \.product.id) { line in
                            HStack {
                                Text(line.product.emoji).font(.title)
                                VStack(alignment: .leading) {
                                    Text(line.product.name).foregroundStyle(Theme.cocoa)
                                    Text(line.product.price * Decimal(line.qty), format: .currency(code: "USD"))
                                        .font(.caption).foregroundStyle(Theme.mocha)
                                }
                                Spacer()
                                Stepper("\(line.qty)", onIncrement: { cart.add(line.product) },
                                        onDecrement: { cart.remove(line.product) })
                                    .fixedSize()
                            }
                            .listRowBackground(Theme.sand)
                        }
                        Section {
                            HStack {
                                Text("Total").bold()
                                Spacer()
                                Text(cart.total, format: .currency(code: "USD")).bold()
                            }
                            .foregroundStyle(Theme.cocoa)
                            Button("Place Order") { ordered = true }
                                .bold().frame(maxWidth: .infinity)
                                .listRowBackground(Theme.cocoa).foregroundStyle(.white)
                        }
                        .listRowBackground(Theme.sand)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.cream)
            .navigationTitle("Cart")
            .alert("Order placed! 🥐", isPresented: $ordered) {
                Button("OK") { cart.clear() }
            } message: {
                Text("Your order will be ready for pickup in 20 minutes.")
            }
        }
    }
}

// MARK: - Profile

struct ProfileView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(Cart.self) private var cart
    @State private var confirmDelete = false
    @State private var deleteError: String?

    private func deleteAccount() {
        Task {
            do {
                try await cart.deleteSaved()
                try await auth.deleteAccount()
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 50)).foregroundStyle(Theme.terracotta)
                        VStack(alignment: .leading) {
                            Text(auth.displayName).font(.headline)
                            Text(auth.email ?? "").font(.subheadline).foregroundStyle(Theme.mocha)
                        }
                    }
                }
                Section {
                    Button("Sign Out", role: .destructive) { auth.signOut() }
                }
                Section {
                    Button("Delete Account", role: .destructive) { confirmDelete = true }
                } footer: {
                    Text("Permanently deletes your account and saved cart.")
                }
            }
            .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive, action: deleteAccount)
            } message: {
                Text("This can't be undone.")
            }
            .alert("Couldn't delete account", isPresented: .init(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("OK") {}
            } message: {
                Text(deleteError ?? "")
            }
            .foregroundStyle(Theme.cocoa)
            .listRowBackground(Theme.sand)
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .navigationTitle("Profile")
        }
    }
}

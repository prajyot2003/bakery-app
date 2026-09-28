import Foundation
import FirebaseFirestore

struct Product: Identifiable, Hashable {
    let id: String   // SKU
    let name: String
    let emoji: String
    let category: String
    let price: Decimal
    let detail: String
}

struct Recipe: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let time: String
    let ingredients: [String]
    let steps: [String]
}

/// Mirrors the signed-in user's cart to Firestore at `carts/{uid}` in the `bakery` database.
@MainActor @Observable
final class Cart {
    private(set) var items: [Product: Int] = [:] { didSet { save() } }
    @ObservationIgnored private var uid: String?
    @ObservationIgnored private var loading = false
    // A method, not a stored property: Cart is created before FirebaseApp.configure() runs.
    private func doc(_ uid: String) -> DocumentReference {
        Firestore.firestore(database: "bakery").collection("carts").document(uid)
    }

    /// Call whenever the signed-in user changes; nil clears the local cart.
    func load(uid: String?) async {
        self.uid = nil          // no saves while swapping users
        loading = true
        defer { loading = false }
        items = [:]
        guard let uid else { return }
        do {
            let saved = try await doc(uid).getDocument().data()?["items"] as? [String: Int] ?? [:]
            items = Dictionary(uniqueKeysWithValues: Catalog.products.compactMap { p in
                saved[p.id].map { (p, $0) }
            })
        } catch {
            print("Cart load failed: \(error)")  // ponytail: silent; surface in UI if it matters
        }
        self.uid = uid
    }

    /// Removes the saved cart (used before account deletion).
    func deleteSaved() async throws {
        guard let uid else { return }
        try await doc(uid).delete()   // on failure, leave the cart untouched
        self.uid = nil                // stop save() from re-creating the doc
        items = [:]
    }

    private func save() {
        guard let uid, !loading else { return }
        let data: [String: Any] = [
            "items": Dictionary(uniqueKeysWithValues: items.map { ($0.key.id, $0.value) }),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        doc(uid).setData(data) { error in
            if let error { print("Cart save failed: \(error)") }
        }
    }

    var count: Int { items.values.reduce(0, +) }
    var total: Decimal { items.reduce(0) { $0 + $1.key.price * Decimal($1.value) } }
    var lines: [(product: Product, qty: Int)] {
        items.map { ($0.key, $0.value) }.sorted { $0.product.id < $1.product.id }
    }

    func add(_ p: Product) { items[p] = min(items[p, default: 0] + 1, 99) }  // rules cap at 99
    func remove(_ p: Product) {
        guard let q = items[p] else { return }
        items[p] = q > 1 ? q - 1 : nil
    }
    func clear() { items.removeAll() }
}

enum Catalog {
    static let products: [Product] = [
        .init(id: "BRD-001", name: "Sourdough Loaf", emoji: "🍞", category: "Bread", price: 7.50, detail: "Naturally leavened, 24-hour fermented country loaf with a crackling crust."),
        .init(id: "BRD-002", name: "French Baguette", emoji: "🥖", category: "Bread", price: 3.75, detail: "Classic thin baguette, crisp outside and airy inside."),
        .init(id: "BRD-003", name: "Everything Bagel", emoji: "🥯", category: "Bread", price: 2.25, detail: "Kettle-boiled bagel topped with sesame, poppy, garlic and onion."),
        .init(id: "PAS-001", name: "Butter Croissant", emoji: "🥐", category: "Pastry", price: 3.50, detail: "Laminated with French butter for 27 flaky layers."),
        .init(id: "PAS-002", name: "Cinnamon Roll", emoji: "🌀", category: "Pastry", price: 4.25, detail: "Soft brioche swirl with brown-sugar cinnamon and cream cheese glaze."),
        .init(id: "PAS-003", name: "Glazed Doughnut", emoji: "🍩", category: "Pastry", price: 2.00, detail: "Yeast-raised doughnut dipped in vanilla glaze."),
        .init(id: "PAS-004", name: "Blueberry Muffin", emoji: "🧁", category: "Pastry", price: 3.25, detail: "Bursting with wild blueberries and a crumble top."),
        .init(id: "CAK-001", name: "Chocolate Fudge Cake", emoji: "🎂", category: "Cake", price: 32.00, detail: "Three layers of dark chocolate sponge with fudge frosting. Serves 8."),
        .init(id: "CAK-002", name: "Strawberry Shortcake", emoji: "🍰", category: "Cake", price: 5.50, detail: "Light sponge, fresh strawberries and whipped cream. Per slice."),
        .init(id: "CAK-003", name: "New York Cheesecake", emoji: "🥧", category: "Cake", price: 6.00, detail: "Dense, creamy cheesecake on a graham cracker crust. Per slice."),
        .init(id: "CKE-001", name: "Chocolate Chip Cookie", emoji: "🍪", category: "Cookies", price: 1.75, detail: "Brown-butter cookie loaded with dark chocolate chunks."),
        .init(id: "CKE-002", name: "Oatmeal Raisin Cookie", emoji: "🥠", category: "Cookies", price: 1.75, detail: "Chewy oats, plump raisins and a hint of cinnamon."),
        .init(id: "CKE-003", name: "Pretzel Twist", emoji: "🥨", category: "Cookies", price: 2.50, detail: "Soft Bavarian pretzel with coarse salt."),
        .init(id: "DRK-001", name: "Latte", emoji: "☕️", category: "Drinks", price: 4.50, detail: "Double espresso with steamed milk."),
    ]

    static var categories: [String] {
        var seen = Set<String>()
        return products.map(\.category).filter { seen.insert($0).inserted }
    }

    static let recipes: [Recipe] = [
        .init(name: "Classic Sourdough", emoji: "🍞", time: "24 h",
              ingredients: ["500 g bread flour", "350 g water", "100 g active starter", "10 g salt"],
              steps: ["Mix flour and water; rest 1 hour (autolyse).", "Add starter and salt; squeeze to combine.", "Stretch and fold every 30 min for 2 hours.", "Bulk ferment until 50% risen, 4–6 hours.", "Shape, place in a floured banneton and refrigerate overnight.", "Bake in a preheated Dutch oven at 250°C: 20 min lid on, 25 min lid off."]),
        .init(name: "Butter Croissants", emoji: "🥐", time: "2 days",
              ingredients: ["500 g flour", "10 g salt", "55 g sugar", "11 g instant yeast", "300 ml cold milk", "280 g cold butter"],
              steps: ["Make dough from flour, salt, sugar, yeast and milk; chill overnight.", "Pound butter into a 20 cm square; chill.", "Enclose butter in dough and do three letter folds, chilling 30 min between.", "Roll to 4 mm, cut triangles and roll up.", "Proof 2 hours until jiggly, brush with egg wash.", "Bake at 200°C for 18–20 minutes."]),
        .init(name: "Chocolate Chip Cookies", emoji: "🍪", time: "45 min",
              ingredients: ["225 g browned butter", "200 g brown sugar", "100 g white sugar", "2 eggs", "300 g flour", "1 tsp baking soda", "1 tsp salt", "300 g dark chocolate chunks"],
              steps: ["Brown the butter and let it cool slightly.", "Whisk in sugars, then eggs.", "Fold in flour, soda and salt.", "Stir in chocolate chunks; chill 30 min.", "Scoop and bake at 180°C for 10–12 minutes."]),
        .init(name: "Cinnamon Rolls", emoji: "🌀", time: "3 h",
              ingredients: ["500 g flour", "240 ml warm milk", "7 g yeast", "60 g sugar", "1 egg", "75 g butter", "Filling: 150 g brown sugar, 2 tbsp cinnamon, 75 g butter", "Glaze: 120 g cream cheese, 60 g icing sugar"],
              steps: ["Knead dough until smooth; rise 1 hour.", "Roll into a rectangle, spread filling.", "Roll up tightly and cut 12 pieces.", "Rise 45 minutes in a greased pan.", "Bake at 180°C for 22–25 minutes.", "Spread glaze while warm."]),
        .init(name: "Blueberry Muffins", emoji: "🧁", time: "35 min",
              ingredients: ["280 g flour", "150 g sugar", "2 tsp baking powder", "120 ml oil", "1 egg", "240 ml buttermilk", "200 g blueberries"],
              steps: ["Whisk dry ingredients in one bowl, wet in another.", "Combine gently — lumps are fine.", "Fold in blueberries.", "Fill muffin cups and add crumble topping.", "Bake at 200°C for 20 minutes."]),
        .init(name: "Strawberry Shortcake", emoji: "🍰", time: "1 h",
              ingredients: ["4 eggs", "120 g sugar", "120 g flour", "30 g melted butter", "400 ml whipping cream", "400 g strawberries"],
              steps: ["Whip eggs and sugar until tripled in volume.", "Fold in flour, then butter.", "Bake in a 20 cm tin at 170°C for 25 minutes; cool.", "Slice into two layers.", "Fill and cover with whipped cream and sliced strawberries."]),
    ]
}

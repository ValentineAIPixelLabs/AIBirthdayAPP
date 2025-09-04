import Foundation
import StoreKit

// MARK: - Server Pricing Models
struct ServerPricing {
    let textGeneration: Int
    let promptGeneration: Int
    let imageGeneration: ImageGenerationPricing
}

struct ImageGenerationPricing {
    let baseCosts: BaseCosts
    let referenceImageCost: Int
    let cardFixed: Int
}

struct BaseCosts {
    let low: Int
    let medium: Int
    let high: Int
}

@MainActor
final class StoreKitManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedTokenCount: Int = 0 {
        didSet { UserDefaults.standard.set(purchasedTokenCount, forKey: Self.tokensKey) }
    }
    @Published var hasPremium: Bool = false
    
    // Listener task for StoreKit transaction updates
    private var transactionUpdatesTask: Task<Void, Never>?

    private static let tokensKey = "StoreKitManager.purchasedTokenCount"

    init() {
        if let saved = UserDefaults.standard.object(forKey: Self.tokensKey) as? Int {
            self.purchasedTokenCount = saved
        }
    }
    
    // Укажи тут свои productIDs (из .storekit-файла или App Store)
    let consumableIDs: Set<String> = [
        "com.aibirthday.tokens100",
        "com.aibirthday.tokens300",
        "com.aibirthday.tokens1200"
    ]
    let subscriptionIDs: Set<String> = [
        "com.aibirthday.premium_week",
        "com.aibirthday.premium_month",
        "com.aibirthday.premium_year"
    ]

    // MARK: - Backend wiring
    private let baseURL = URL(string: "https://aibirthday-backend.up.railway.app")!

    private func currentJWT() -> String? {
        // JWT, полученный и сохраненный AppleSignInManager после регистрации/логина
        return AppleSignInManager.shared.currentJWTToken
    }

    private func tokensForProductID(_ productId: String) -> Int {
        switch productId {
        case "com.aibirthday.tokens100": return 100
        case "com.aibirthday.tokens300": return 300
        case "com.aibirthday.tokens1200": return 1200
        default: return 0
        }
    }

    // Main-thread safe balance updates
    private func setBalance(_ value: Int) {
        if Thread.isMainThread {
            self.purchasedTokenCount = value
        } else {
            DispatchQueue.main.async { self.purchasedTokenCount = value }
        }
    }

    private func addBalance(_ delta: Int) {
        if Thread.isMainThread {
            self.purchasedTokenCount += delta
        } else {
            DispatchQueue.main.async { self.purchasedTokenCount += delta }
        }
    }

    private func periodFor(productId: String) -> String? {
        if productId.contains("premium_week") { return "week" }
        if productId.contains("premium_month") { return "month" }
        if productId.contains("premium_year") { return "year" }
        return nil
    }

    private func approxExpiry(for productId: String, from start: Date = Date()) -> Date {
        if productId.contains("premium_week") {
            return Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        } else if productId.contains("premium_month") {
            return Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
        } else if productId.contains("premium_year") {
            return Calendar.current.date(byAdding: .year, value: 1, to: start) ?? start
        }
        return start
    }

    private func iso8601String(_ date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.string(from: date)
    }

    private struct TokensResponse: Decodable { let tokens_left: Int? }
    private struct ConfirmResponse: Decodable {
        let success: Bool?
        let credited: Bool?
        let added: Int?
        let tokens_left: Int?
        let idempotent: Bool?
    }

    private struct SubscriptionStatus: Decodable {
        let active: Bool?
        let product_id: String?
        let period: String?
        let allowance: Int?
        let expires_at: String?
        let next_reset_at: String?
        let tokens_left: Int?
    }

    private func syncSubscriptionToServer(productId: String, period: String, expiresAt: Date, isActive: Bool) async {
        guard let token = currentJWT() else { return }
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/subscriptions/sync"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "product_id": productId,
            "period": period,
            "expires_at": iso8601String(expiresAt),
            "is_active": isActive
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                if let decoded = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) {
                    if let left = decoded.tokens_left { self.setBalance(left) }
                    if let active = decoded.active { self.hasPremium = active }
                }
            }
        } catch { /* ignore network blips */ }
    }

    /// Optionally fetch server-side subscription/tokens snapshot
    func fetchSubscriptionStatus() async {
        guard let token = currentJWT() else { return }
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/subscriptions/status"))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                if let decoded = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) {
                    if let left = decoded.tokens_left { self.setBalance(left) }
                    if let active = decoded.active { self.hasPremium = active }
                }
            }
        } catch { /* ignore */ }
    }

    /// Подтянуть баланс токенов с сервера (если есть JWT)
    func fetchServerTokens() async {
        guard let token = currentJWT() else {
            // Нет JWT — пропускаем серверный вызов
            return
        }
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/tokens"))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                let decoded = try? JSONDecoder().decode(TokensResponse.self, from: data)
                if let left = decoded?.tokens_left {
                    self.setBalance(left)
                }
            } else {
                // print("GET /api/tokens failed: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            // print("GET /api/tokens error: \(error)")
        }
        
        // Also fetch pricing when fetching tokens
        await fetchServerPricing()
    }

    /// Подтверждение покупки токенов на сервере (идемпотентно по transaction_id)
    private func confirmTokensPurchase(productId: String, transaction: Transaction, quantity: Int = 1) async {
        guard let token = currentJWT() else {
            // Нет JWT — fallback: локально инкрементируем, чтобы не ломать UX на деве
            let add = tokensForProductID(productId)
            if add > 0 { self.addBalance(add) }
            return
        }
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/purchases/confirm"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "product_id": productId,
            "transaction_id": String(transaction.id),
            "quantity": quantity
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                let decoded = try? JSONDecoder().decode(ConfirmResponse.self, from: data)
                if let left = decoded?.tokens_left {
                    self.setBalance(left)
                } else {
                    // Если сервер не вернул tokens_left, локально прибавим как fallback
                    let add = tokensForProductID(productId)
                    if add > 0 { self.addBalance(add) }
                }
            } else {
                // Server rejected confirm; do not locally credit to keep server authoritative
            }
        } catch {
            // Network error; do not locally credit to avoid desync
        }
    }
    
    /// Start listening for StoreKit transaction updates to avoid missing purchases
    func startTransactionListener() {
        // prevent multiple listeners
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task(priority: .background) { [weak self] in
            guard let self else { return }
            for await update in Transaction.updates {
                do {
                    let transaction = try Self.verify(update)
                    // Handle (credit tokens / set premium) and finish
                    await self.handlePurchase(transaction: transaction)
                    await transaction.finish()
                } catch {
                    // Failed verification; ignore but keep listening
                }
            }
        }
    }

    /// Refresh current subscription status based on current entitlements
    func refreshSubscriptionStatus() async {
        var premium = false
        for await entitlement in Transaction.currentEntitlements {
            switch entitlement {
            case .verified(let t):
                if subscriptionIDs.contains(t.productID) { premium = true }
            case .unverified:
                continue
            }
        }
        if hasPremium != premium { hasPremium = premium }
    }

    /// Helper to unwrap verified transactions
    private struct FailedVerification: Error {}
    /// Helper to unwrap verified transactions (no actor isolation; pure)
    nonisolated private static func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified:
            throw FailedVerification()
        }
    }
    
    // Загрузка всех продуктов (вызывай при запуске)
    func loadProducts() async {
        do {
            let ids = consumableIDs.union(subscriptionIDs)
            products = try await Product.products(for: ids)
            await refreshSubscriptionStatus()
            await fetchServerTokens()
            await fetchSubscriptionStatus()
        } catch {
            print("Ошибка загрузки продуктов: \(error)")
        }
    }
    
    // Покупка продукта
    func purchase(product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await handlePurchase(transaction: transaction)
                    await transaction.finish()
                case .unverified(_, let error):
                    print("Покупка НЕ подтверждена: \(error.localizedDescription)")
                }
            case .userCancelled:
                print("Покупка отменена пользователем")
            case .pending:
                print("Покупка в ожидании")
            @unknown default:
                print("Неизвестный результат покупки")
            }
        } catch {
            print("Ошибка во время покупки: \(error)")
        }
    }
    
    // Обработка успешной покупки (MVP)
    private func handlePurchase(transaction: Transaction) async {
        let productId = transaction.productID
        let transactionId = String(transaction.id)
        print("➡️ purchase tx:", transactionId)
        if consumableIDs.contains(productId) {
            // Подтверждаем покупку токенов на сервере (идемпотентно)
            await confirmTokensPurchase(productId: productId, transaction: transaction, quantity: 1)
            print("[Store] Tokens updated, current balance: \(purchasedTokenCount)")
        } else if subscriptionIDs.contains(productId) {
            hasPremium = true
            print("Premium подписка активирована!")
            let period = periodFor(productId: productId) ?? "month"
            // Try to use StoreKit expiration if available; fall back to approx
            let exp = transaction.expirationDate ?? approxExpiry(for: productId, from: transaction.purchaseDate)
            await syncSubscriptionToServer(productId: productId, period: period, expiresAt: exp, isActive: true)
            await fetchSubscriptionStatus()
        }
    }
    
    // Восстановление покупок
    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                await handlePurchase(transaction: transaction)
            case .unverified(_, _):
                // Обычно игнорируется для восстановления
                break
            }
        }
        await fetchSubscriptionStatus()
    }
    
    // MARK: - Pricing from server
    @Published var serverPricing: ServerPricing?
    
    func fetchServerPricing() async {
        guard let jwt = currentJWT(),
              let url = URL(string: "\(baseURL)/api/pricing") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let pricingData = json["pricing"] as? [String: Any] {
                
                let textGeneration = pricingData["text_generation"] as? Int ?? 1
                let promptGeneration = pricingData["prompt_generation"] as? Int ?? 1
                
                var imageGeneration = ImageGenerationPricing(baseCosts: BaseCosts(low: 1, medium: 4, high: 17), referenceImageCost: 1, cardFixed: 4)
                
                if let imgData = pricingData["image_generation"] as? [String: Any] {
                    let baseCosts = imgData["base_costs"] as? [String: Any]
                    let low = baseCosts?["low"] as? Int ?? 1
                    let medium = baseCosts?["medium"] as? Int ?? 4
                    let high = baseCosts?["high"] as? Int ?? 17
                    let refCost = imgData["reference_image_cost"] as? Int ?? 1
                    let cardFixed = imgData["card_fixed"] as? Int ?? 4
                    
                    imageGeneration = ImageGenerationPricing(
                        baseCosts: BaseCosts(low: low, medium: medium, high: high),
                        referenceImageCost: refCost,
                        cardFixed: cardFixed
                    )
                }
                
                await MainActor.run {
                    self.serverPricing = ServerPricing(
                        textGeneration: textGeneration,
                        promptGeneration: promptGeneration,
                        imageGeneration: imageGeneration
                    )
                }
            }
        } catch {
            print("Failed to fetch server pricing: \(error)")
        }
    }
    
    // Удобный геттер для UI
    func productDisplayName(_ product: Product) -> String {
        product.displayName
    }
    
    func productPrice(_ product: Product) -> String {
        product.displayPrice
    }
    
    // MARK: - Token Price Calculations with Server Data
    func textGenerationPrice() -> Int {
        return serverPricing?.textGeneration ?? 1
    }
    
    func promptGenerationPrice() -> Int {
        return serverPricing?.promptGeneration ?? 1
    }
    
    func imageGenerationPrice(quality: String, size: String, hasReferenceImage: Bool = false) -> Int {
        guard let pricing = serverPricing?.imageGeneration else {
            // Fallback to local calculation if server pricing not available
            let base: Int
            switch quality.lowercased() {
            case "low": base = 1
            case "medium": base = 4
            case "high": base = 17
            default: base = 4
            }
            
            // Parse size like "1024x1536"
            let comps = size.split(separator: "x")
            var multiplier: Double = 1
            if comps.count == 2, let w = Double(comps[0]), let h = Double(comps[1]) {
                let area = w * h
                let tile = 1024.0 * 1024.0
                let rawMul = area / tile
                multiplier = max(1, ceil(rawMul * 100) / 100)
            }
            var cost = Int(ceil(Double(base) * multiplier))
            if hasReferenceImage { cost += 1 }
            return max(1, cost)
        }
        
        // Use server pricing
        let base: Int
        switch quality.lowercased() {
        case "low": base = pricing.baseCosts.low
        case "medium": base = pricing.baseCosts.medium
        case "high": base = pricing.baseCosts.high
        default: base = pricing.baseCosts.medium
        }
        
        // Parse size like "1024x1536"
        let comps = size.split(separator: "x")
        var multiplier: Double = 1
        if comps.count == 2, let w = Double(comps[0]), let h = Double(comps[1]) {
            let area = w * h
            let tile = 1024.0 * 1024.0
            let rawMul = area / tile
            multiplier = max(1, ceil(rawMul * 100) / 100)
        }
        var cost = Int(ceil(Double(base) * multiplier))
        if hasReferenceImage { 
            cost += pricing.referenceImageCost 
        }
        return max(1, cost)
    }
    
    func cardGenerationPrice() -> Int {
        return serverPricing?.imageGeneration.cardFixed ?? 4
    }
}

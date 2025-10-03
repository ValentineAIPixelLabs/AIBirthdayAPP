import Foundation
import os.log
import StoreKit
import UIKit

@MainActor
final class StoreKitManager: ObservableObject {
    private let logger = Logger(subsystem: "com.aibirthday.aibirthdayreminderapp", category: "StoreKitManager")
    @Published var products: [Product] = []
    @Published var purchasedTokenCount: Int = 0 {
        didSet { UserDefaults.standard.set(purchasedTokenCount, forKey: Self.tokensKey) }
    }
    @Published var hasPremium: Bool = false
    @Published var activeSubscriptionProductId: String? = nil
    @Published private(set) var subscriptionAllowances: [String: Int] = [:]
    @Published var pendingSubscriptionProductId: String? = nil
    @Published var pendingSubscriptionEffectiveDate: Date? = nil
    @Published var subscriptionExpiresAt: Date? = nil
    @Published var nextSubscriptionResetAt: Date? = nil
    @Published var autoRenewStatus: Bool? = nil
    @Published var autoRenewProductId: String? = nil

    // Listener task for StoreKit transaction updates
    private var transactionUpdatesTask: Task<Void, Never>?
    private var pendingPurchaseProductId: String?
    private var handledTransactionIds: Set<String> = []
    private var handledTransactionsOrder: [String] = []
    private let handledTransactionsLimit = 128

    private static let tokensKey = "StoreKitManager.purchasedTokenCount"
    private let defaultSubscriptionAllowances: [String: Int] = [
        "week": 60,
        "month": 300,
        "year": 4000
    ]
    private lazy var isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init() {
        logger.debug("StoreKitManager init")
        if let saved = UserDefaults.standard.object(forKey: Self.tokensKey) as? Int {
            self.purchasedTokenCount = saved
        }
        self.subscriptionAllowances = defaultSubscriptionAllowances

        startTransactionListener()
    }
    
    // Укажи тут свои productIDs (из .storekit-файла или App Store)
    let consumableIDs: Set<String> = [
        "com.aibirthday.tokens100",
        "com.aibirthday.tokens300",
        "com.aibirthday.tokens1200"
    ]
    let subscriptionIDs: Set<String> = [
        "com.aibirthday.weekly",
        "com.aibirthday.monthly",
        "com.aibirthday.yearly"
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

    private func hasProcessedTransaction(_ id: String) -> Bool {
        handledTransactionIds.contains(id)
    }

    private func rememberHandledTransaction(_ id: String) {
        // keep ordering to cull old entries without unbounded growth
        if let existingIndex = handledTransactionsOrder.firstIndex(of: id) {
            handledTransactionsOrder.remove(at: existingIndex)
        }
        handledTransactionIds.insert(id)
        handledTransactionsOrder.append(id)
        if handledTransactionsOrder.count > handledTransactionsLimit, let oldest = handledTransactionsOrder.first {
            handledTransactionsOrder.removeFirst()
            handledTransactionIds.remove(oldest)
        }
    }

    private func forgetHandledTransaction(_ id: String) {
        handledTransactionIds.remove(id)
        if let index = handledTransactionsOrder.firstIndex(of: id) {
            handledTransactionsOrder.remove(at: index)
        }
    }

    private func periodFor(productId: String) -> String? {
        if productId.contains("weekly") { return "week" }
        if productId.contains("monthly") { return "month" }
        if productId.contains("yearly") { return "year" }
        return nil
    }

    private func isActiveSubscriptionTransaction(_ transaction: Transaction) -> Bool {
        guard subscriptionIDs.contains(transaction.productID) else { return false }
        if transaction.isUpgraded { return false }
        if let revokedAt = transaction.revocationDate, revokedAt <= Date() { return false }
        return true
    }

    private func approxExpiry(for productId: String, from start: Date = Date()) -> Date {
        if productId.contains("weekly") {
            return Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        } else if productId.contains("monthly") {
            return Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
        } else if productId.contains("yearly") {
            return Calendar.current.date(byAdding: .year, value: 1, to: start) ?? start
        }
        return start
    }

    private func iso8601String(_ date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.string(from: date)
    }

    private func parseISODate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        if let date = isoFormatter.date(from: string) {
            return date
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: string)
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
        let transaction_id: String?
        let original_transaction_id: String?
        let auto_renew_status: Bool?
        let auto_renew_product_id: String?
        let pending_product_id: String?
        let pending_period: String?
        let pending_allowance: Int?
        let pending_effective_at: String?
        let revocation_at: String?
    }

    private struct SubscriptionConfigResponse: Decodable {
        let allowances: [String: Int]?
    }

    private func applySubscriptionStatus(_ status: SubscriptionStatus) {
        if let left = status.tokens_left { self.setBalance(left) }
        if let active = status.active {
            self.hasPremium = active
            if !active {
                self.activeSubscriptionProductId = nil
            }
        }
        if let productId = status.product_id, (status.active ?? true) {
            self.activeSubscriptionProductId = productId
        }
        if let period = status.period, let allowance = status.allowance {
            subscriptionAllowances[period] = allowance
        }
        subscriptionExpiresAt = parseISODate(status.expires_at)
        nextSubscriptionResetAt = parseISODate(status.next_reset_at)
        pendingSubscriptionProductId = status.pending_product_id
        pendingSubscriptionEffectiveDate = parseISODate(status.pending_effective_at)
        autoRenewStatus = status.auto_renew_status
        autoRenewProductId = status.auto_renew_product_id
    }

    private func syncSubscriptionToServer(transaction: Transaction?, productId: String, period: String, expiresAt: Date, isActive: Bool) async {
        guard let token = currentJWT() else {
            logger.debug("syncSubscriptionToServer skipped — no JWT")
            return
        }
        logger.log("syncSubscriptionToServer start product=\(productId, privacy: .public) tx=\(transaction?.id ?? 0, privacy: .public)")
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/subscriptions/sync"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = [
            "product_id": productId,
            "period": period,
            "expires_at": iso8601String(expiresAt),
            "is_active": isActive
        ]
        if let txn = transaction {
            body["transaction_id"] = String(txn.id)
            body["original_transaction_id"] = String(txn.originalID)
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                logger.log("syncSubscriptionToServer status=\(http.statusCode)")
                if (200..<300).contains(http.statusCode) {
                    if let decoded = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) {
                        self.applySubscriptionStatus(decoded)
                    }
                } else {
                    let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                    logger.error("syncSubscriptionToServer unexpected status=\(http.statusCode) body=\(bodyString, privacy: .public)")
                }
            }
        } catch {
            logger.error("syncSubscriptionToServer error: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Optionally fetch server-side subscription/tokens snapshot
    func fetchSubscriptionStatus() async {
        guard let token = currentJWT() else {
            logger.debug("fetchSubscriptionStatus skipped — no JWT")
            return
        }
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/subscriptions/status"))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                logger.log("fetchSubscriptionStatus status=\(http.statusCode)")
                if let decoded = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) {
                    self.applySubscriptionStatus(decoded)
                }
            } else if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                logger.log("fetchSubscriptionStatus status=404")
                hasPremium = false
                activeSubscriptionProductId = nil
                pendingSubscriptionProductId = nil
                pendingSubscriptionEffectiveDate = nil
                subscriptionExpiresAt = nil
                nextSubscriptionResetAt = nil
                autoRenewStatus = nil
                autoRenewProductId = nil
            } else if let http = response as? HTTPURLResponse {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                logger.error("fetchSubscriptionStatus unexpected status=\(http.statusCode) body=\(body, privacy: .public)")
            }
        } catch {
            logger.error("fetchSubscriptionStatus error: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Подтянуть баланс токенов с сервера (если есть JWT)
    func fetchServerTokens() async {
        guard let token = currentJWT() else {
            logger.debug("fetchServerTokens skipped — no JWT")
            return
        }
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/tokens"))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                logger.log("fetchServerTokens status=\(http.statusCode)")
                let decoded = try? JSONDecoder().decode(TokensResponse.self, from: data)
                if let left = decoded?.tokens_left {
                    self.setBalance(left)
                }
            } else {
                if let http = response as? HTTPURLResponse {
                    let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                    logger.error("fetchServerTokens unexpected status=\(http.statusCode) body=\(body, privacy: .public)")
                }
                // print("GET /api/tokens failed: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            logger.error("fetchServerTokens error: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Подтверждение покупки токенов на сервере (идемпотентно по transaction_id)
    private func confirmTokensPurchase(productId: String, transaction: Transaction, quantity: Int = 1) async {
        guard let token = currentJWT() else {
            logger.debug("confirmTokensPurchase no JWT – local fallback")
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
            if let http = response as? HTTPURLResponse {
                if (200..<300).contains(http.statusCode) {
                    logger.log("confirmTokensPurchase status=\(http.statusCode)")
                    let decoded = try? JSONDecoder().decode(ConfirmResponse.self, from: data)
                    if let left = decoded?.tokens_left {
                        self.setBalance(left)
                    } else {
                        logger.log("confirmTokensPurchase missing tokens_left; applying fallback")
                        let add = tokensForProductID(productId)
                        if add > 0 { self.addBalance(add) }
                    }
                } else {
                    let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                    logger.error("confirmTokensPurchase unexpected status=\(http.statusCode) body=\(body, privacy: .public)")
                }
            }
        } catch {
            logger.error("confirmTokensPurchase error: \(error.localizedDescription, privacy: .public)")
            // Network error; do not locally credit to avoid desync
        }
    }
    
    /// Start listening for StoreKit transaction updates to avoid missing purchases
    @discardableResult
    func startTransactionListener() -> Bool {
        if let existingTask = transactionUpdatesTask {
            if existingTask.isCancelled {
                transactionUpdatesTask = nil
            } else {
                return false
            }
        }

        transactionUpdatesTask = Task(priority: .background) { [weak self] in
            guard let self else { return }
            for await update in Transaction.updates {
                do {
                    let transaction = try Self.verify(update)
                    logger.log("Transaction.update id=\(transaction.id, privacy: .public) product=\(transaction.productID, privacy: .public)")
                    await transaction.finish()
                    await self.handlePurchase(transaction: transaction)
                } catch {
                    logger.error("Transaction.update verification failed: \(error.localizedDescription, privacy: .public)")
                    // Failed verification; ignore but keep listening
                }
            }

            await MainActor.run { [weak self] in
                self?.transactionUpdatesTask = nil
            }
        }

        return true
    }

    /// Perform a lightweight entitlement sync flow for cold app launches.
    func syncEntitlementsOnAppLaunch() async {
        let expectedIds = consumableIDs.union(subscriptionIDs)
        let knownIds = Set(products.map { $0.id })

        if !expectedIds.isSubset(of: knownIds) {
            do {
                let fetched = try await Task.detached(priority: .userInitiated) {
                    try await Product.products(for: expectedIds)
                }.value
                await MainActor.run {
                    self.products = fetched
                }
            } catch {
                logger.error("syncEntitlementsOnAppLaunch preload error: \(error.localizedDescription, privacy: .public)")
            }
        }

        var activeTransaction: Transaction?
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  isActiveSubscriptionTransaction(transaction) else { continue }

            if let current = activeTransaction {
                let currentExpiry = current.expirationDate ?? approxExpiry(for: current.productID, from: current.purchaseDate)
                let candidateExpiry = transaction.expirationDate ?? approxExpiry(for: transaction.productID, from: transaction.purchaseDate)
                if candidateExpiry > currentExpiry {
                    activeTransaction = transaction
                }
            } else {
                activeTransaction = transaction
            }
        }

        guard currentJWT() != nil else {
            await MainActor.run {
                if let transaction = activeTransaction {
                    let expires = transaction.expirationDate ?? self.approxExpiry(for: transaction.productID, from: transaction.purchaseDate)
                    self.hasPremium = true
                    self.activeSubscriptionProductId = transaction.productID
                    self.subscriptionExpiresAt = expires
                    self.nextSubscriptionResetAt = nil
                    self.pendingSubscriptionProductId = nil
                    self.pendingSubscriptionEffectiveDate = nil
                    self.autoRenewStatus = nil
                    self.autoRenewProductId = nil
                } else {
                    self.hasPremium = false
                    self.activeSubscriptionProductId = nil
                    self.subscriptionExpiresAt = nil
                    self.nextSubscriptionResetAt = nil
                    self.pendingSubscriptionProductId = nil
                    self.pendingSubscriptionEffectiveDate = nil
                    self.autoRenewStatus = nil
                    self.autoRenewProductId = nil
                }
            }
            return
        }

        if let transaction = activeTransaction {
            let productId = transaction.productID
            let period = periodFor(productId: productId) ?? "month"
            let expiresAt = transaction.expirationDate ?? approxExpiry(for: productId, from: transaction.purchaseDate)
            logger.log("syncEntitlementsOnAppLaunch active tx=\(transaction.id, privacy: .public) product=\(productId, privacy: .public)")
            await syncSubscriptionToServer(transaction: transaction,
                                           productId: productId,
                                           period: period,
                                           expiresAt: expiresAt,
                                           isActive: true)
        } else {
            logger.log("syncEntitlementsOnAppLaunch no active transaction; fetching status")
            await fetchSubscriptionStatus()
        }
    }

    /// Refresh current subscription status based on current entitlements
    func refreshSubscriptionStatus() async {
        var premium = false
        var currentId: String? = nil
        for await entitlement in Transaction.currentEntitlements {
            switch entitlement {
            case .verified(let t):
                if isActiveSubscriptionTransaction(t) {
                    premium = true
                    currentId = t.productID
                }
            case .unverified:
                continue
            }
        }
        if hasPremium != premium {
            hasPremium = premium
            logger.log("refreshSubscriptionStatus hasPremium=\(premium)")
        }
        if activeSubscriptionProductId != currentId {
            activeSubscriptionProductId = currentId
            logger.log("refreshSubscriptionStatus activeProduct=\(currentId ?? "nil", privacy: .public)")
        }
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
            await fetchSubscriptionConfig()
            debugPrintActiveTransactions()
        } catch {
            logger.error("loadProducts error: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // Покупка продукта
    func purchase(product: Product) async {
        do {
            if product.subscription != nil {
                pendingPurchaseProductId = product.id
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await handlePurchase(transaction: transaction)
                    await transaction.finish()
                case .unverified(_, let error):
                    logger.error("purchase verification failed: \(error.localizedDescription, privacy: .public)")
                }
            case .userCancelled:
                logger.log("purchase cancelled by user")
            case .pending:
                logger.log("purchase pending")
            @unknown default:
                logger.error("purchase returned unknown result")
            }
        } catch {
            logger.error("purchase error: \(error.localizedDescription, privacy: .public)")
            pendingPurchaseProductId = nil
        }
    }
    
    // Обработка успешной покупки (MVP)
    private func handlePurchase(transaction: Transaction, force: Bool = false) async {
        let productId = transaction.productID
        let transactionId = String(transaction.id)
        if force {
            forgetHandledTransaction(transactionId)
        } else if hasProcessedTransaction(transactionId) {
            logger.log("handlePurchase skip duplicate tx=\(transactionId, privacy: .public)")
            return
        }

        logger.log("handlePurchase tx=\(transactionId, privacy: .public) product=\(productId, privacy: .public)")
        defer {
            rememberHandledTransaction(transactionId)
            pendingPurchaseProductId = nil
        }

        if consumableIDs.contains(productId) {
            // Подтверждаем покупку токенов на сервере (идемпотентно)
            await confirmTokensPurchase(productId: productId, transaction: transaction, quantity: 1)
            logger.log("confirmTokensPurchase completed balance=\(self.purchasedTokenCount)")
        } else if subscriptionIDs.contains(productId) {
            guard isActiveSubscriptionTransaction(transaction) else {
                logger.log("handlePurchase ignoring inactive/upgrade tx=\(transactionId, privacy: .public)")
                return
            }
            let effectiveProductId: String = {
                if let pending = pendingPurchaseProductId, pending != productId, subscriptionIDs.contains(pending) {
                    logger.log("handlePurchase pending mismatch, using pending product=\(pending, privacy: .public)")
                    return pending
                }
                return productId
            }()

            hasPremium = true
            activeSubscriptionProductId = effectiveProductId
            logger.log("handlePurchase premium activated product=\(effectiveProductId, privacy: .public)")
            let period = periodFor(productId: effectiveProductId) ?? "month"
            let exp = transaction.expirationDate ?? approxExpiry(for: effectiveProductId, from: transaction.purchaseDate)
            await syncSubscriptionToServer(transaction: transaction, productId: effectiveProductId, period: period, expiresAt: exp, isActive: true)
            await fetchSubscriptionStatus()
        }
    }
    
    // Восстановление покупок
    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard isActiveSubscriptionTransaction(transaction) || consumableIDs.contains(transaction.productID) else { continue }
                await handlePurchase(transaction: transaction, force: true)
            case .unverified(_, _):
                // Обычно игнорируется для восстановления
                break
            }
        }
        await fetchSubscriptionStatus()
    }

    /// Re-sync currently active App Store entitlements with the backend (e.g. on app launch)
    func synchronizeActiveSubscriptionsWithServer(force: Bool = false) async {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard isActiveSubscriptionTransaction(transaction) else { continue }
                await handlePurchase(transaction: transaction, force: force)
            case .unverified:
                continue
            }
        }
    }

    // Удобный геттер для UI
    func productDisplayName(_ product: Product) -> String {
        product.displayName
    }

    func productPrice(_ product: Product) -> String {
        product.displayPrice
    }

    private func currentActiveSubscriptionTransaction() async -> Transaction? {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if isActiveSubscriptionTransaction(transaction) {
                    return transaction
                }
            case .unverified:
                continue
            }
        }
        return nil
    }

    func allowance(for productId: String) -> Int {
        guard let period = periodFor(productId: productId) else { return 0 }
        if let serverAllowance = subscriptionAllowances[period] {
            return serverAllowance
        }
        return defaultSubscriptionAllowances[period] ?? 0
    }

    func isDowngradeComparedToActive(_ product: Product) -> Bool {
        guard let activeId = activeSubscriptionProductId,
              let activeProduct = products.first(where: { $0.id == activeId }) else {
            return false
        }
        if product.price < activeProduct.price { return true }
        let activeAllowance = allowance(for: activeProduct.id)
        let candidateAllowance = allowance(for: product.id)
        return candidateAllowance < activeAllowance
    }

    func presentManageSubscriptions() async {
#if os(iOS)
        if #available(iOS 15.0, *) {
            do {
                if let scene = await activeWindowScene() {
                    try await AppStore.showManageSubscriptions(in: scene)
                } else {
                    print("[StoreKit] No active scene available for manage subscriptions UI")
                }
            } catch {
                print("[StoreKit] manage subscriptions error: \(error)")
            }
        }
#endif
    }

    func requestRefund() async {
#if os(iOS)
        guard let transaction = await currentActiveSubscriptionTransaction() else { return }
        if #available(iOS 15.0, *) {
            do {
                if let scene = await activeWindowScene() {
                    let status = try await transaction.beginRefundRequest(in: scene)
                    switch status {
                    case .success:
                        print("[StoreKit] refund request submitted")
                    case .userCancelled:
                        print("[StoreKit] refund request canceled by user")
                    @unknown default:
                        print("[StoreKit] refund request returned unknown status")
                    }
                } else {
                    print("[StoreKit] No active scene available for refund request")
                }
            } catch {
                print("[StoreKit] refund request error: \(error)")
            }
        }
#endif
    }

#if os(iOS)
    private func activeWindowScene() async -> UIWindowScene? {
        await MainActor.run {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
        }
    }
#endif

    private func fetchSubscriptionConfig() async {
        guard let token = currentJWT() else { return }
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/subscriptions/config"))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let decoded = try? JSONDecoder().decode(SubscriptionConfigResponse.self, from: data),
               let allowances = decoded.allowances {
                subscriptionAllowances = defaultSubscriptionAllowances.merging(allowances) { _, new in new }
            }
        } catch { /* ignore */ }
    }

    // MARK: - Debug helpers
    func debugPrintActiveTransactions() {
        Task {
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    guard isActiveSubscriptionTransaction(transaction) else { continue }
                    print("[StoreKit] tx id=\(transaction.id) original=\(transaction.originalID) product=\(transaction.productID)")
                case .unverified:
                    continue
                }
            }
        }
    }
}

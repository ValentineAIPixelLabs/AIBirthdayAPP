
// MARK: - Paywall (Subscription-only, no tokens)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var store: StoreKitManager
    @State private var selectedProduct: Product? = nil

    var subscriptionProducts: [Product] {
        store.products
            .filter { store.subscriptionIDs.contains($0.id) }
            .sorted { a, b in orderIndex(a.id) < orderIndex(b.id) }
    }

    private func orderIndex(_ id: String) -> Int {
        if id.contains("weekly") { return 0 }
        if id.contains("monthly") { return 1 }
        if id.contains("yearly") { return 2 }
        return 99
    }

    // Helper methods for allowance/labels
    private func allowance(for id: String) -> Int {
        if id.contains("weekly") { return 100 }
        if id.contains("monthly") { return 300 }
        if id.contains("yearly") { return 1200 }
        return 0
    }

    private func estimatedUsageText(for tokens: Int) -> String {
        let greetings = max(tokens / 5, 1)
        let cards = max(tokens / 20, 1)
        return "≈ \(greetings) / \(cards)"
    }

    private func planDisplayName(for id: String) -> String {
        if id.contains("weekly") { return "Неделя" }
        if id.contains("monthly") { return "Месяц" }
        if id.contains("yearly") { return "Год" }
        return "Подписка"
    }

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                // Top bar with close and title
                HStack(spacing: 8) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.secondary, .secondary.opacity(0.2))
                            .padding(8)
                    }
                    Text("Премиум-доступ")
                        .font(.largeTitle.bold())
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Short description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Получите доступ к генерации поздравлений и открыток на основе данных о контактах.")
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)

                        // Comparison table
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Сравнение тарифов")
                                .font(.headline)
                                .padding(.horizontal, 4)

                            Grid(horizontalSpacing: 12, verticalSpacing: 8) {
                                // Header row
                                GridRow {
                                    Text("Тариф").font(.subheadline.weight(.semibold))
                                    Text("≈ токенов").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("≈ поздравл. / открыт.").font(.subheadline.weight(.semibold)).frame(width: 160, alignment: .trailing)
                                }
                                .opacity(0.8)

                                ForEach(subscriptionProducts, id: \.id) { p in
                                    let t = allowance(for: p.id)
                                    GridRow {
                                        Text(planDisplayName(for: p.id))
                                        Text("\(t)").monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
                                        Text(estimatedUsageText(for: t)).frame(width: 160, alignment: .trailing)
                                    }
                                    .font(.callout)
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)

                        // Plans
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Выберите тариф")
                                .font(.headline)
                                .padding(.horizontal, 20)

                            if subscriptionProducts.isEmpty {
                                VStack(spacing: 8) {
                                    ProgressView()
                                    Text("Загружаем цены…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                ForEach(subscriptionProducts, id: \.id) { product in
                                    let isActive = store.activeSubscriptionProductId == product.id
                                    let recommended = product.id.contains("yearly")
                                    PlanRow(product: product,
                                            isSelected: selectedProduct?.id == product.id,
                                            isActive: isActive,
                                            allowance: allowance(for: product.id),
                                            isRecommended: recommended) {
                                        if !isActive { selectedProduct = product }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                    }
                    .padding(.top, 6)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    guard let p = selectedProduct else { return }
                    Task { await store.purchase(product: p) }
                } label: {
                    Text("Продолжить").frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedProduct == nil)

                HStack(spacing: 18) {
                    Button("Terms") { if let u = URL(string: "https://aibirthday.app/terms") { openURL(u) } }
                    Button("Privacy Policy") { if let u = URL(string: "https://aibirthday.app/privacy") { openURL(u) } }
                    Button("Restore") { Task { await store.restorePurchases() } }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
        }
        .task {
            store.startTransactionListener()
            await store.loadProducts()
            await store.refreshSubscriptionStatus()
            await store.fetchSubscriptionStatus()
        }
    }
}

private struct PaywallFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PlanRow: View {
    let product: Product
    let isSelected: Bool
    let isActive: Bool
    let allowance: Int
    let isRecommended: Bool
    let onTap: () -> Void

    var periodLabel: String {
        if let s = product.subscription?.subscriptionPeriod {
            switch s.unit { case .week: return s.value == 1 ? "1 неделя" : "\(s.value) нед.";
                             case .month: return s.value == 1 ? "1 месяц" : "\(s.value) мес.";
                             case .year: return s.value == 1 ? "1 год" : "\(s.value) г.";
                             default: return "Период" }
        }
        return "Подписка"
    }

    var allowanceLabel: String {
        if let s = product.subscription?.subscriptionPeriod {
            switch s.unit {
            case .week: return "≈ \(allowance) токенов/нед"
            case .month: return "≈ \(allowance) токенов/мес"
            case .year: return "≈ \(allowance) токенов/год"
            default: return "≈ \(allowance) токенов"
            }
        }
        return "≈ \(allowance) токенов"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(product.displayName).font(.title3.weight(.semibold))
                        if isRecommended {
                            Text("Выгоднее")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                        }
                    }
                    HStack(spacing: 8) {
                        Text(periodLabel).font(.caption).foregroundStyle(.secondary)
                        Text(allowanceLabel).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(product.displayPrice).font(.title3.weight(.bold)).monospacedDigit()
                    if isActive {
                        Label("Активно", systemImage: "checkmark.seal.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isActive ? .green : (isSelected ? Color.accentColor : .secondary.opacity(0.2)), lineWidth: isActive ? 2 : (isSelected ? 2 : 1))
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
            )
        }
        .buttonStyle(.plain)
        .disabled(isActive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.displayName), \(periodLabel), \(allowanceLabel), цена \(product.displayPrice)\(isActive ? ", активный" : "")")
    }
}
import SwiftUI
import StoreKit

struct StoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var store: StoreKitManager

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Account header
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.circle.fill")
                                .font(.title)
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Баланс токенов")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(store.purchasedTokenCount)")
                                    .font(.system(size: 34, weight: .bold))
                                    .monospacedDigit()
                            }
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            Image(systemName: store.hasPremium ? "star.fill" : "star")
                                .foregroundStyle(store.hasPremium ? .yellow : .secondary)
                            Text(store.hasPremium ? "Premium-аккаунт активен" : "Без подписки")
                                .font(.subheadline)
                                .foregroundStyle(store.hasPremium ? .green : .secondary)
                            Spacer()
                            Button("Управлять") {
                                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                    openURL(url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Ваш аккаунт")
                }

                // MARK: - Token packs
                Section("Пакеты токенов") {
                    if !store.hasPremium {
                        EmptyRow(title: "Доступно при активной подписке",
                                 hint: "Оформите Premium, чтобы докупать токены")
                    } else {
                        let tokenProducts = store.products.filter { store.consumableIDs.contains($0.id) }
                        if tokenProducts.isEmpty {
                            EmptyRow(title: "Пакеты недоступны",
                                     hint: "Потяните вниз, чтобы обновить")
                        } else {
                            ForEach(tokenProducts, id: \.id) { product in
                                ProductRow(product: product,
                                           buttonTitle: "Купить") {
                                    Task { await store.purchase(product: product) }
                                }
                            }
                        }
                    }
                }

                // MARK: - Subscriptions
                Section("Premium подписка") {
                    let subscriptionProducts = store.products.filter { store.subscriptionIDs.contains($0.id) }

                    if subscriptionProducts.isEmpty {
                        EmptyRow(title: "Подписки недоступны",
                                 hint: "Проверьте конфигурацию StoreKit и попробуйте обновить")
                    } else {
                        ForEach(subscriptionProducts, id: \.id) { product in
                            ProductRow(product: product,
                                       buttonTitle: store.hasPremium ? "Перейти" : "Оформить") {
                                Task { await store.purchase(product: product) }
                            }
                        }
                    }
                }

                // MARK: - Restore
                Section {
                    Button {
                        Task { await store.restorePurchases() }
                    } label: {
                        Label("Восстановить покупки", systemImage: "arrow.clockwise")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Магазин")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .task {
                store.startTransactionListener()
                await store.loadProducts()
                await store.refreshSubscriptionStatus()
                await store.fetchSubscriptionStatus()
            }
            .refreshable {
                await store.loadProducts()
                await store.refreshSubscriptionStatus()
                await store.fetchSubscriptionStatus()
            }
        }
    }
}

// MARK: - Reusable Row for both consumables and subscriptions
private struct ProductRow: View {
    let product: Product
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // DisplayName is the human-friendly product name configured in App Store Connect
                Text(product.displayName)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if let info = product.subscription {
                    Text(subscriptionSubtitle(period: info.subscriptionPeriod, hasTrial: info.introductoryOffer != nil))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !product.description.isEmpty {
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(product.id)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 8) {
                Text(product.displayPrice)
                    .bold()
                    .monospacedDigit()
                Button(buttonTitle) { action() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 6)
    }

    private func subscriptionSubtitle(period: Product.SubscriptionPeriod, hasTrial: Bool) -> String {
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "день" : "дн."
        case .week: unit = period.value == 1 ? "неделя" : "нед."
        case .month: unit = period.value == 1 ? "месяц" : "мес."
        case .year: unit = period.value == 1 ? "год" : "года"
        @unknown default: unit = "период"
        }
        let base = period.value == 1 ? "Каждый \(unit)" : "Каждые \(period.value) \(unit)"
        return hasTrial ? base + " • Пробный период" : base
    }
}

// MARK: - Empty state row
private struct EmptyRow: View {
    let title: String
    let hint: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

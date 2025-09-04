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

import SwiftUI
import StoreKit

// MARK: - Paywall (Updated per request)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var store: StoreKitManager

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                DarkPurpleBackground().ignoresSafeArea()

                if #available(iOS 17.0, *),
                   let groupID = store.subscriptionGroupID,
                   !store.subscriptionIDs.isEmpty {
                    ios17Content(groupID: groupID)
                } else {
                    legacyContent
                }
            }
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть", role: .cancel) { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            store.startTransactionListener()
            await store.loadProducts()
            await store.refreshSubscriptionStatus()
            await store.fetchSubscriptionStatus()
        }
    }

    // MARK: - Sections
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(hex: 0x8A5DFF), Color(hex: 0xC06BFF)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: .black.opacity(0.25), radius: 16, y: 12)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Премиум-доступ")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Создавайте идеальные поздравления с помощью ИИ")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var benefitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BenefitRow(icon: "person.text.rectangle", title: "Генерация по данным о контактах")
            BenefitRow(icon: "paintbrush", title: "Уникальные дизайны открыток")
            BenefitRow(icon: "sparkles", title: "Лучшее качество изображений")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func ios17Content(groupID: String) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                headerSection
                benefitSection
                ios17StoreCard(groupID: groupID)
                legalSection
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity)
        }
    }

    private var legacyContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                headerSection
                benefitSection
                legacyStoreCard
                legalSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func ios17StoreCard(groupID: String) -> some View {
        if #available(iOS 17.0, *), !store.subscriptionIDs.isEmpty {
            SubscriptionStoreContainer(groupID: groupID,
                                       productIDs: Array(store.subscriptionIDs))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 22, y: 18)
                )
        } else {
            legacyStoreCard
        }
    }

    @ViewBuilder
    private var legacyStoreCard: some View {
        if store.subscriptionIDs.isEmpty {
            HStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Загружаем предложения…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        } else {
            LegacySubscriptionList(
                products: store.products.filter { store.subscriptionIDs.contains($0.id) },
                allow: { store.allowance(for: $0.id) },
                purchase: { product in await store.purchase(product: product) }
            )
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .shadow(color: .black.opacity(0.3), radius: 22, y: 18)
            )
        }
    }

    @ViewBuilder
    private var legalSection: some View {
        HStack(spacing: 24) {
            Button("Условия") {
                if let url = URL(string: "https://aibirthday.app/terms") {
                    openURL(url)
                }
            }

            Button("Конфиденциальность") {
                if let url = URL(string: "https://aibirthday.app/privacy") {
                    openURL(url)
                }
            }

            Button("Управлять") {
                Task { await store.presentManageSubscriptions() }
            }
        }
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

}

private struct BenefitRow: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.green.opacity(0.22), Color.mint.opacity(0.18)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LegacySubscriptionList: View {
    let products: [Product]
    let allow: (Product) -> Int
    let purchase: (Product) async -> Void

    var body: some View {
        VStack(spacing: 16) {
            ForEach(products) { product in
                LegacySubscriptionRow(product: product,
                                      allowance: allow(product)) {
                    await purchase(product)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
    }
}

private struct LegacySubscriptionRow: View {
    let product: Product
    let allowance: Int
    let purchase: () async -> Void

    var body: some View {
        Button {
            Task { await purchase() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(product.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(product.displayPrice)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                Text(periodTitle(for: product))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(allowance) токенов")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func periodTitle(for product: Product) -> String {
        if let sub = product.subscription {
            switch sub.subscriptionPeriod.unit {
            case .week: return sub.subscriptionPeriod.value == 1 ? "Неделя" : "Каждые \(sub.subscriptionPeriod.value) нед."
            case .month: return sub.subscriptionPeriod.value == 1 ? "Месяц" : "Каждые \(sub.subscriptionPeriod.value) мес."
            case .year: return sub.subscriptionPeriod.value == 1 ? "Год" : "Каждые \(sub.subscriptionPeriod.value) г."
            case .day: return sub.subscriptionPeriod.value == 1 ? "День" : "Каждые \(sub.subscriptionPeriod.value) дн."
            @unknown default: return "Период"
            }
        }
        let id = product.id.lowercased()
        if id.contains("weekly") { return "Неделя" }
        if id.contains("monthly") { return "Месяц" }
        if id.contains("yearly") { return "Год" }
        return "Период"
    }
}

// MARK: - Plan row with larger/bolder period and checkbox to the right of price
// MARK: - Local, dark‑purple background for Paywall (усилен)
private struct DarkPurpleBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark
                    ? [Color(hex: 0x3A216A), Color(hex: 0x09011F)]
                    : [Color(hex: 0x4B2C8F), Color(hex: 0x14002B)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(colors: [Color.white.opacity(0.08), .clear],
                           center: .top, startRadius: 0, endRadius: 420)
                .blendMode(.softLight)
                .allowsHitTesting(false)
            RadialGradient(colors: [Color.black.opacity(0.35), .clear],
                           center: .bottom, startRadius: 0, endRadius: 520)
                .blendMode(.multiply)
                .allowsHitTesting(false)
            LinearGradient(colors: [Color.black.opacity(0.14), Color.black.opacity(0.26)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Helpers
private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

@available(iOS 17.0, *)
private struct SubscriptionStoreContainer: View {
    @EnvironmentObject var store: StoreKitManager
    let groupID: String
    let productIDs: [String]

    var body: some View {
        SubscriptionStoreView(productIDs: productIDs)
            .tint(Color(hex: 0xB06BFF))
            .subscriptionStatusTask(for: groupID) { _ in
                await store.refreshSubscriptionStatus()
            }
            .storeButton(.visible, for: .restorePurchases)
    }
}


import SwiftUI
import StoreKit

// MARK: - Paywall (Updated per request)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var store: StoreKitManager
    @State private var selectedProduct: Product? = nil
    @State private var isCTAEnabled: Bool = false

    private func orderIndex(_ id: String) -> Int {
        if id.contains("weekly") { return 0 }
        if id.contains("monthly") { return 1 }
        if id.contains("yearly") { return 2 }
        return 99
    }

    var subscriptionProducts: [Product] {
        store.products
            .filter { store.subscriptionIDs.contains($0.id) }
            .sorted { a, b in orderIndex(a.id) < orderIndex(b.id) }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                DarkPurpleBackground().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection
                        benefitSection
                        planSection
                        bottomActionSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity)
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
            updateDefaultSelection()
            updateCTAEnabled()
        }
        .onChange(of: store.activeSubscriptionProductId) { _ in
            updateDefaultSelection()
            updateCTAEnabled()
        }
        .onChange(of: store.products) { _ in
            updateDefaultSelection()
            updateCTAEnabled()
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
    private var planSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if subscriptionProducts.isEmpty {
                HStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text("Загружаем предложения…")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(subscriptionProducts, id: \.id) { product in
                        let isActive = store.activeSubscriptionProductId == product.id
                        let isDisabled = isActive

                        PlanRow(
                            product: product,
                            isSelected: selectedProduct?.id == product.id,
                            isActive: isActive,
                            isDisabled: isDisabled,
                            allowance: store.allowance(for: product.id),
                            onTap: {
                                guard !isDisabled else { return }
                                selectedProduct = product
                                updateCTAEnabled()
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var bottomActionSection: some View {
        VStack(spacing: 10) {
            Button {
                guard let product = selectedProduct, isCTAEnabled else { return }
                Task {
                    if store.isDowngradeComparedToActive(product) {
                        await store.presentManageSubscriptions()
                    } else {
                        await store.purchase(product: product)
                    }
                }
            } label: {
                Text(ctaTitle())
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(isCTAEnabled ? 1.0 : 0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(hex: 0xB06BFF).opacity(isCTAEnabled ? 1.0 : 0.45))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(isCTAEnabled ? 0.25 : 0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isCTAEnabled)

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

                Button("Восстановить") {
                    Task { await store.restorePurchases() }
                }
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers (selection)
    private func activeProduct() -> Product? {
        guard let id = store.activeSubscriptionProductId else { return nil }
        return subscriptionProducts.first(where: { $0.id == id })
    }

    // MARK: - Selection/CTA logic
    private func updateDefaultSelection() {
        guard !subscriptionProducts.isEmpty else { return }

        // Сортируем по цене (дороже – дальше)
        let byPriceAsc = subscriptionProducts.sorted { a, b in
            a.price < b.price
        }

        if let active = activeProduct() {
            // Ищем следующий более дорогой, чем активный
            if let nextHigher = byPriceAsc.first(where: { $0.price > active.price }) {
                selectedProduct = nextHigher
            } else {
                // Активен самый дорогой: выделяем его (CTA будет выключена)
                selectedProduct = active
            }
        } else {
            // Нет активной подписки — выбираем самый дорогой (годовой)
            selectedProduct = byPriceAsc.last ?? subscriptionProducts.first
        }
    }

    private func updateCTAEnabled() {
        guard let sel = selectedProduct else { isCTAEnabled = false; return }
        // CTA недоступна, если выбран активный продукт и он уже самый дорогой план
        if let active = activeProduct() {
            if sel.id == active.id {
                let byPriceAsc = subscriptionProducts.sorted { $0.price < $1.price }
                let isMax = (active.id == byPriceAsc.last?.id)
                isCTAEnabled = !isMax
                return
            }
        }
        isCTAEnabled = true
    }

    // MARK: - CTA title
    private func ctaTitle() -> String {
        guard let p = selectedProduct else { return "Выберите план" }

        if store.isDowngradeComparedToActive(p) {
            return "Управлять подпиской в App Store"
        }

        if let active = activeProduct(), active.id == p.id {
            let byPriceAsc = subscriptionProducts.sorted { $0.price < $1.price }
            if p.id == byPriceAsc.last?.id {
                return "Максимальный план активен"
            }
        }

        return "Перейти за \(p.displayPrice) \(periodAccusative(for: p))"
    }

    // MARK: - Period phrase for CTA (accusative)
    private func periodAccusative(for product: Product) -> String {
        guard let sub = product.subscription else {
            let id = product.id.lowercased()
            if id.contains("weekly") { return "в неделю" }
            if id.contains("monthly") { return "в месяц" }
            if id.contains("yearly") { return "в год" }
            return ""
        }
        let value = sub.subscriptionPeriod.value
        switch sub.subscriptionPeriod.unit {
        case .week:  return value == 1 ? "в неделю" : "на \(value) нед."
        case .month: return value == 1 ? "в месяц" : "на \(value) мес."
        case .year:  return value == 1 ? "в год"   : "на \(value) г."
        case .day:   return value == 1 ? "в день"  : "на \(value) дн."
        @unknown default: return ""
        }
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

// MARK: - Plan row with larger/bolder period and checkbox to the right of price
private struct PlanRow: View {
    let product: Product
    let isSelected: Bool
    let isActive: Bool
    let isDisabled: Bool
    let allowance: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Left: title + period + allowance
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isDisabled ? .white.opacity(0.6) : .white)
                        .lineLimit(1)

                    // Период: крупнее и жирнее
                    Text(periodTitle(for: product))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isDisabled ? .white.opacity(0.6) : .white)

                    Text("\(allowance) токенов")
                        .font(.subheadline)
                        .foregroundStyle(isDisabled ? .white.opacity(0.5) : .white.opacity(0.9))
                }
                Spacer()

                // Right: price + checkbox в одну строку
                HStack(spacing: 10) {
                    Text(product.displayPrice)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(isDisabled ? .white.opacity(0.65) : .white)
                        .monospacedDigit()

                    ZStack {
                        Circle()
                            .stroke(
                                isActive ? .white.opacity(0.35) : .white.opacity(isSelected ? 0.9 : 0.35),
                                lineWidth: isSelected ? 3 : 2.5
                            )
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Circle()
                                .fill(Color.white.opacity(isDisabled ? 0.5 : 1.0))
                                .frame(width: 12, height: 12)
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x5D2A8F).opacity(isDisabled ? 0.55 : 0.90),
                                     Color(hex: 0x4B1C77).opacity(isDisabled ? 0.65 : 0.98)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isActive
                                ? Color.white.opacity(0.25) // полупрозрачная обводка для активного
                                : (isSelected ? .white.opacity(0.9) : .white.opacity(0.08)),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .opacity(isDisabled && !isActive ? 0.85 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled) // активный тариф нельзя выбрать повторно
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.displayName), \(allowance) токенов, \(periodTitle(for: product)), цена \(product.displayPrice)\(isActive ? ", уже активен" : "")")
    }

    private func periodTitle(for product: Product) -> String {
        if let sub = product.subscription {
            switch sub.subscriptionPeriod.unit {
            case .week:  return sub.subscriptionPeriod.value == 1 ? "Неделя" : "Каждые \(sub.subscriptionPeriod.value) нед."
            case .month: return sub.subscriptionPeriod.value == 1 ? "Месяц"  : "Каждые \(sub.subscriptionPeriod.value) мес."
            case .year:  return sub.subscriptionPeriod.value == 1 ? "Год"    : "Каждые \(sub.subscriptionPeriod.value) г."
            case .day:   return sub.subscriptionPeriod.value == 1 ? "День"   : "Каждые \(sub.subscriptionPeriod.value) дн."
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

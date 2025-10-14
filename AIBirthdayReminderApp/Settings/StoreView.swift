import SwiftUI
import StoreKit
import Combine
import UIKit

/// Unified paywall that keeps the custom branding while following Apple’s subscription layout cues.
struct PaywallView: View {
    @EnvironmentObject private var store: StoreKitManager

    var body: some View {
        PaywallScreen()
            .task {
                store.startTransactionListener()
                await store.loadProducts()
                await store.refreshSubscriptionStatus()
                await store.fetchSubscriptionStatus()
            }
    }
}

// MARK: - Screen

private struct PaywallScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreKitManager
    @State private var selectedProductID: String?
    @State private var isPurchasing: Bool = false

    private var subscriptionProducts: [Product] {
        store.products
            .filter { store.subscriptionIDs.contains($0.id) }
            .sorted(by: sortProducts)
    }

    private var isLoading: Bool { store.subscriptionIDs.isEmpty == false && store.products.isEmpty }

    private var recommendedProductID: String? {
        subscriptionProducts.first(where: { $0.id.contains("year") })?.id
            ?? subscriptionProducts.first(where: { $0.id.contains("month") })?.id
    }

    private var activeProductID: String? { store.activeSubscriptionProductId }
    private var pendingProductID: String? { store.pendingSubscriptionProductId }
    private let previewCards: [PreviewCardModel] = [
        .init(title: " ", subtitle: " ", gradient: [Color(hex: 0xFF9A9E), Color(hex: 0xFAD0C4)], imageName: "PaywallPreviewCard"),
        .init(title: " ", subtitle: " ", gradient: [Color(hex: 0xA18CD1), Color(hex: 0xFBC2EB)], imageName: "PaywallPreviewCard"),
        .init(title: " ", subtitle: " ", gradient: [Color(hex: 0x84FAB0), Color(hex: 0x8FD3F4)], imageName: "PaywallPreviewCard")
    ]
    private var isLegacyOS: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackdropView()
                GeometryReader { geo in
                    let isCompact = geo.size.height < 760
                    VStack(spacing: isCompact ? 14 : 20) {
                        marketingCard(isCompact: isCompact)
//                        perksSection(isCompact: isCompact)
                        plansSection(isCompact: isCompact)
                        footerSection(isCompact: isCompact)
                    }
                    .padding(.horizontal, CardStyle.listHorizontalPadding)
                    .padding(.top, isCompact ? 18 : 32)
                    .padding(.bottom, isCompact ? 14 : 44)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть", role: .cancel) { dismiss() }
                        .tint(isLegacyOS ? .white : nil)
                }
            }
        }
        .onAppear { selectDefaultIfNeeded(force: true) }
        .onReceive(store.$products) { _ in selectDefaultIfNeeded(force: false) }
        .onReceive(store.$activeSubscriptionProductId) { active in
            guard let active, !subscriptionProducts.isEmpty else { return }
            if subscriptionProducts.contains(where: { $0.id == active }) {
                selectedProductID = active
            }
        }
    }

    // MARK: Sections

    private func marketingCard(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 8 : 16) {
            PreviewDeckView(cards: previewCards, isCompact: isCompact)
                .frame(height: isCompact ? 180 : 230)
                .padding(.top, isCompact ? -8 : -8)

            VStack(spacing: isCompact ? 2 : 6) {
                Text("Премиум-доступ")
                    .font(adjustedFont(.title1, weight: .bold, delta: isCompact ? -3 : -1))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Создавайте идеальные поздравления с помощью ИИ")
                    .font(adjustedFont(.callout, delta: isCompact ? -4 : -2))
                    .foregroundStyle(.white.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.vertical, isCompact ? 8 : 16)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func plansSection(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 14) {
            if isLoading {
                HStack(spacing: 14) {
                    ProgressView().tint(.white)
                    Text("Загружаем предложения…")
                        .font(adjustedFont(.callout, delta: isCompact ? -4 : -2))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, isCompact ? 12 : 20)
            } else if subscriptionProducts.isEmpty {
                VStack(spacing: isCompact ? 5 : 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(adjustedFont(.title2, delta: isCompact ? -4 : -2))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Не удалось загрузить предложения подписки.")
                        .font(adjustedFont(.callout, delta: isCompact ? -4 : -2))
                        .foregroundStyle(.white.opacity(0.8))
                    Button {
                        Task {
                            await store.loadProducts()
                            await store.fetchSubscriptionStatus()
                        }
                    } label: {
                        Text("Повторить попытку")
                            .font(adjustedFont(.callout, weight: .semibold, delta: isCompact ? -3 : -2))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.2))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, isCompact ? 12 : 18)
            } else {
                VStack(spacing: isCompact ? 6 : 10) {
                    ForEach(subscriptionProducts, id: \.id) { product in
                        SubscriptionPlanCard(
                            product: product,
                            allowance: store.allowance(for: product.id),
                            isActive: activeProductID == product.id,
                            isPending: pendingProductID == product.id,
                            isRecommended: recommendedProductID == product.id,
                            isSelected: selectedProductID == product.id,
                            isPurchasing: isPurchasing,
                            isCompact: isCompact
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedProductID = product.id
                            }
                        }
                    }
                }
                Button(action: {
                    guard let selected = selectedProductID,
                          let chosen = subscriptionProducts.first(where: { $0.id == selected }) else { return }
                    Task { await purchase(product: chosen) }
                }) {
                    Group {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text(buttonLabel)
                                .font(adjustedFont(.headline, weight: .semibold, delta: isCompact ? -3 : -2))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isCompact ? 8 : 12)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: isLegacyOS ? 24 : (isCompact ? 18 : 12)))
                .tint(Color.accentPrimary)
                .controlSize(isCompact ? .small : .large)
                .padding(.top, isCompact ? 4 : 8)
                .disabled(btnDisabled)
            }
        }
        .padding(.vertical, isCompact ? 12 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    

    private func perksSection(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            Text("Что входит")
                .font(adjustedFont(.headline))
                .foregroundStyle(.white.opacity(0.9))
            BenefitRow(icon: "wand.and.stars", title: "Персонализированные поздравления на основе контактов и событий.")
            BenefitRow(icon: "sparkles.rectangle.stack", title: "Авторские дизайны открыток и изображений высокого качества.")
            BenefitRow(icon: "bolt.horizontal.circle", title: "Мгновенная генерация без ограничений и задержек.")
        }
        .padding(isCompact ? 16 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func footerSection(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 6 : 12) {
            HStack(spacing: isCompact ? 10 : 16) {
                Link("Условия", destination: URL(string: "https://aibirthday.app/terms")!)
                Divider()
                    .frame(height: 12)
                    .overlay(Color.white.opacity(0.5))
                Link("Конфиденциальность", destination: URL(string: "https://aibirthday.app/privacy")!)
            }
            .font(adjustedFont(.footnote, weight: .semibold, delta: isCompact ? -2 : -1))
            .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private func sortProducts(lhs: Product, rhs: Product) -> Bool {
        guard let lhsPeriod = lhs.subscription?.subscriptionPeriod,
              let rhsPeriod = rhs.subscription?.subscriptionPeriod else {
            return lhs.displayName < rhs.displayName
        }

        let lhsDays = lhsPeriod.approximateDays
        let rhsDays = rhsPeriod.approximateDays

        if lhsDays == rhsDays {
            return lhs.displayName < rhs.displayName
        }
        return lhsDays < rhsDays
    }

    private func selectDefaultIfNeeded(force: Bool) {
        guard !subscriptionProducts.isEmpty else { return }

        let hasSelected = selectedProductID.flatMap { id in
            subscriptionProducts.contains(where: { $0.id == id })
        } ?? false

        if !hasSelected {
            if let active = store.activeSubscriptionProductId,
               subscriptionProducts.contains(where: { $0.id == active }) {
                selectedProductID = active
                return
            }

            if let recommended = recommendedProductID,
               subscriptionProducts.contains(where: { $0.id == recommended }) {
                selectedProductID = recommended
            } else {
                selectedProductID = subscriptionProducts.first?.id
            }
        } else if force,
                  let active = store.activeSubscriptionProductId,
                  subscriptionProducts.contains(where: { $0.id == active }) {
            selectedProductID = active
        }
    }

    private func buttonTitle(for product: Product) -> String {
        if let offer = product.subscription?.introductoryOffer,
           offer.paymentMode == .freeTrial {
            return "Начать бесплатно"
        }
        return "Продолжить за \(product.displayPrice)"
    }

    private func purchase(product: Product) async {
        if await MainActor.run(body: { isPurchasing }) { return }
        await MainActor.run { isPurchasing = true }
        defer { Task { @MainActor in isPurchasing = false } }
        await store.purchase(product: product)
    }

    private var buttonLabel: String {
        guard let selected = selectedProductID,
              let product = subscriptionProducts.first(where: { $0.id == selected }) else {
            return "Продолжить"
        }
        return buttonTitle(for: product)
    }

    private var btnDisabled: Bool {
        if isPurchasing { return true }
        guard let selected = selectedProductID,
              let product = subscriptionProducts.first(where: { $0.id == selected }) else {
            return true
        }
        if store.activeSubscriptionProductId == product.id { return true }
        return false
    }
}

// MARK: - Components

private struct SubscriptionPlanCard: View {
    let product: Product
    let allowance: Int
    let isActive: Bool
    let isPending: Bool
    let isRecommended: Bool
    let isSelected: Bool
    let isPurchasing: Bool
    let isCompact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
                HStack(alignment: .center, spacing: isCompact ? 12 : 14) {
                    SelectionIndicator(state: indicatorState)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(adjustedFont(.headline, weight: .semibold, delta: isCompact ? -3 : -2))
                            .foregroundStyle(.white)

                        Text(periodDescription(for: product))
                            .font(adjustedFont(.subheadline, delta: isCompact ? -3 : -2))
                            .foregroundStyle(.white.opacity(0.8))

//                        Text("\(allowance) токенов")
//                            .font(.footnote)
//                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: isCompact ? 6 : 8) {
                            if isPending {
                                StatusBadge(text: "В обработке", color: .yellow.opacity(0.85))
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: isCompact ? 2 : 3) {
                        Text(product.displayPrice)
                            .font(adjustedFont(.title3, weight: .bold, delta: isCompact ? -3 : -2))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        if let trial = introductoryOfferDescription(for: product) {
                            Text(trial)
                                .font(adjustedFont(.caption2, weight: .semibold, delta: isCompact ? -3 : -2))
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, isCompact ? 10 : 16)
            .padding(.vertical, isCompact ? 8 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: borderWidth)
                    )
                    .shadow(color: Color.black.opacity(isActive ? 0.3 : 0.16), radius: isActive ? 24 : 14, y: isActive ? 18 : 10)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: isActive)
        .animation(.easeInOut(duration: 0.25), value: isPending)
        .disabled(isPurchasing)
    }

    private func periodDescription(for product: Product) -> String {
        guard let subscription = product.subscription else { return "Подписка" }
        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value
        switch unit {
        case .day: return value == 1 ? "Оплата ежедневно" : "Каждые \(value) дн."
        case .week:
            if value == 1 { return "Оплата еженедельно" }
            if value == 2 { return "Каждые 2 недели" }
            if value == 4 { return "Каждые 4 недели" }
            return "Каждые \(value) недели"
        case .month: return value == 1 ? "Оплата ежемесячно" : "Каждые \(value) мес."
        case .year: return value == 1 ? "Оплата ежегодно" : "Каждые \(value) г."
        @unknown default: return "Подписка"
        }
    }

    private func introductoryOfferDescription(for product: Product) -> String? {
        guard let subscription = product.subscription,
              let intro = subscription.introductoryOffer else { return nil }
        let price = intro.displayPrice
        let period = subscription.subscriptionPeriod
        switch intro.paymentMode {
        case .freeTrial:
            return "\(period.localizedDescription) бесплатно"
        case .payAsYouGo:
            return "\(price) \(period.localizedShort) • \(intro.periodCount) раз"
        case .payUpFront:
            return "\(price) за \(period.localizedDescription)"
        default:
            return nil
        }
    }

    private var indicatorState: SelectionIndicator.State {
        if isPending { return .pending }
        if isActive { return .current }
        if isSelected { return .selected }
        return .idle
    }

    private var borderColor: Color {
        switch indicatorState {
        case .current: return Color.green.opacity(0.8)
        case .selected: return Color.accentPrimary
        case .pending: return Color.yellow.opacity(0.5)
        case .idle: return Color.white.opacity(0.18)
        }
    }

    private var borderWidth: CGFloat {
        switch indicatorState {
        case .current: return 2.6
        case .selected: return 2
        default: return 1
        }
    }
}

private struct SelectionIndicator: View {
    enum State {
        case idle
        case pending
        case selected
        case current
    }

    let state: State

    var body: some View {
        ZStack {
            Circle()
                .stroke(borderColor, lineWidth: strokeWidth)
                .frame(width: 26, height: 26)

            if state == .pending {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(borderColor)
                    .frame(width: 18, height: 18)
            } else if state == .selected {
                Circle()
                    .fill(borderColor)
                    .frame(width: 12, height: 12)
            } else if state == .current {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(borderColor)
            }
        }
        .frame(width: 26, height: 26)
    }

    private var borderColor: Color {
        switch state {
        case .idle: return Color.white.opacity(0.5)
        case .pending: return Color.yellow.opacity(0.9)
        case .selected: return Color.accentPrimary
        case .current: return Color.green.opacity(0.9)
        }
    }

    private var strokeWidth: CGFloat {
        switch state {
        case .current: return 2.4
        case .selected: return 2
        default: return 2
        }
    }
}

private struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(adjustedFont(.caption2, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.2))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(color.opacity(0.6), lineWidth: 1)
                    )
            )
            .foregroundStyle(color.maxSaturation)
    }
}

private struct PreviewCardModel: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let gradient: [Color]
    let imageName: String?
}

private struct PreviewCardView: View {
    let model: PreviewCardModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.clear)
                .overlay {
                    if let imageName = model.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    } else {
                        LinearGradient(colors: model.gradient,
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 18, y: 16)

            VStack(alignment: .leading, spacing: 6) {
                if !model.title.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(model.title)
                        .font(adjustedFont(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                }
                if !model.subtitle.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(model.subtitle)
                        .font(adjustedFont(.subheadline))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(18)
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Заготовка открытки")
    }
}

private struct PreviewDeckView: View {
    let cards: [PreviewCardModel]
    let isCompact: Bool

    var body: some View {
        GeometryReader { proxy in
            let containerWidth = proxy.size.width
            let baseWidth = min(containerWidth * (isCompact ? 0.38 : 0.5), isCompact ? 160 : 200)
            let cardOffset = baseWidth * (isCompact ? 0.72 : 0.82)

            ZStack {
                if let left = cards.first {
                    PreviewCardView(model: left)
                        .frame(width: baseWidth)
                        .rotationEffect(.degrees(-14))
                        .scaleEffect(isCompact ? 0.85 : 0.9)
                        .offset(x: -cardOffset, y: isCompact ? 10 : 18)
                        .opacity(0.64)
                        .zIndex(0)
                }

                if cards.indices.contains(1) {
                    PreviewCardView(model: cards[1])
                        .frame(width: baseWidth)
                        .shadow(color: .black.opacity(0.28), radius: 28, y: 22)
                        .zIndex(2)
                }

                if cards.count > 2 {
                    PreviewCardView(model: cards[2])
                        .frame(width: baseWidth)
                        .rotationEffect(.degrees(14))
                        .scaleEffect(isCompact ? 0.85 : 0.9)
                        .offset(x: cardOffset, y: isCompact ? 10 : 18)
                        .opacity(0.64)
                        .zIndex(0)
                }
            }
            .frame(width: containerWidth, height: baseWidth * (isCompact ? 1.1 : 1.45), alignment: .center)
        }
        .allowsHitTesting(false)
    }
}

private func adjustedFont(_ style: UIFont.TextStyle, weight: Font.Weight = .regular, delta: CGFloat = -2) -> Font {
    let baseSize = UIFont.preferredFont(forTextStyle: style).pointSize
    let adjusted = max(8, baseSize + delta)
    return .system(size: adjusted, weight: weight)
}

private struct BenefitRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.white)
                .background(
                    Circle()
                        .fill(.white.opacity(0.08))
                        .overlay(
                            Circle().stroke(.white.opacity(0.18), lineWidth: 1)
                        )
                )
            Text(title)
                .font(adjustedFont(.subheadline))
                .foregroundStyle(.white.opacity(0.92))
            Spacer(minLength: 0)
        }
    }
}

private struct BackdropView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x120513), Color(hex: 0x06001A)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    gradient: Gradient(colors: [Color(hex: 0xFFBE7B).opacity(0.55), .clear]),
                    center: .topLeading,
                    startRadius: 40,
                    endRadius: max(size.width, size.height) * 0.9
                )
                .blendMode(.screen)

                RadialGradient(
                    gradient: Gradient(colors: [Color(hex: 0x7F6BF4).opacity(0.65), .clear]),
                    center: UnitPoint(x: 0.85, y: 0.75),
                    startRadius: 20,
                    endRadius: max(size.width, size.height) * 0.8
                )
                .blendMode(.softLight)

                RadialGradient(
                    gradient: Gradient(colors: [Color(hex: 0xFF8AD6).opacity(0.5), .clear]),
                    center: UnitPoint(x: 0.92, y: 0.98),
                    startRadius: 30,
                    endRadius: max(size.width, size.height) * 0.7
                )
                .blendMode(.screen)

                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(hex: 0x1B0F2D).opacity(0.4),
                        Color(hex: 0x5E3056).opacity(0.35),
                        Color(hex: 0x3B1F58).opacity(0.4),
                        Color(hex: 0x0A0319).opacity(0.45),
                        Color(hex: 0x1B0F2D).opacity(0.4)
                    ]),
                    center: .center
                )
                .blur(radius: 80)

                LinearGradient(
                    colors: [Color.black.opacity(0.45), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Helpers

private extension Product.SubscriptionPeriod {
    var approximateDays: Int {
        switch unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        @unknown default: return value * 30
        }
    }

    var localizedDescription: String {
        switch unit {
        case .day: return value == 1 ? "1 день" : "\(value) дней"
        case .week: return value == 1 ? "1 неделя" : "\(value) недель"
        case .month: return value == 1 ? "1 месяц" : "\(value) месяцев"
        case .year: return value == 1 ? "1 год" : "\(value) лет"
        @unknown default: return "\(value)"
        }
    }

    var localizedShort: String {
        switch unit {
        case .day: return value == 1 ? "в день" : "каждые \(value) дн."
        case .week:
            if value == 1 { return "еженедельно" }
            if value == 2 { return "каждые 2 недели" }
            if value == 4 { return "каждые 4 недели" }
            return "каждые \(value) недели"
        case .month: return value == 1 ? "ежемесячно" : "каждые \(value) мес."
        case .year: return value == 1 ? "ежегодно" : "каждые \(value) г."
        @unknown default: return ""
        }
    }
}

private extension Color {
    static var accentPrimary: Color { Color(hex: 0xA86BFF) }

    var maxSaturation: Color {
        Color(hue: hue, saturation: min(1, saturation * 1.2), brightness: brightness)
    }

    var hue: Double {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(h)
    }
    var saturation: Double {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(s)
    }
    var brightness: Double {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(b)
    }

    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreKitManager())
}

import SwiftUI
import UIKit

// MARK: - Public API

/// Источник визуала аватара.
enum AvatarSource: Equatable {
    case image(UIImage)
    case emoji(String)          // например: "🎉"
    case monogram(String)       // например: "В" (инициал)
    
    var isEmpty: Bool {
        switch self {
        case .image(let img): return img.size == .zero
        case .emoji(let s), .monogram(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

/// Форма аватара.
enum AvatarShape: Equatable {
    case circle
    case rounded(corner: CGFloat)
}

/// Предустановленные размеры аватара.
enum AvatarSize: Equatable {
    case header        // крупный аватар в шапке редактора
    case headerXL      // +30% для детальных экранов
    case listLarge     // карточки/детали
    case listSmall     // строки списков
    case inline        // маленький инлайн
    
    var side: CGFloat {
        switch self {
        case .header:     return 96
        case .headerXL:   return 96 * 1.3
        case .listLarge:  return 64
        case .listSmall:  return 40
        case .inline:     return 28
        }
    }
    /// Размер шрифта для эмодзи/монограммы как доля от side.
    var glyphFontSize: CGFloat {
        // Подобрано по текущему визуалу: ~0.46 от размера
        return side * 0.46
    }
    /// Толщина рамки.
    var borderWidth: CGFloat {
        switch self {
        case .header, .headerXL: return 0.5
        default:                  return 0.5
        }
    }
    /// Радиус тени.
    var shadowRadius: CGFloat {
        switch self {
        case .header, .headerXL: return 12
        case .listLarge:         return 8
        case .listSmall, .inline: return 5
        }
    }
}

// MARK: - Themed Avatar Backgrounds
private enum AvatarColors {
    static let palette: [UIColor] = [
        .systemMint, .systemTeal, .systemBlue, .systemIndigo, .systemPurple,
        .systemPink, .systemOrange, .systemGreen, .systemCyan
    ]
    static let alpha: CGFloat = 0.16
    
    static func color(for seed: String) -> Color {
        guard !seed.isEmpty else {
            return Color(palette[0].withAlphaComponent(alpha))
        }
        // Детeministic index based on Unicode scalars sum
        let sum = seed.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let index = abs(sum) % palette.count
        return Color(palette[index].withAlphaComponent(alpha))
    }
}

/// Универсальный аватар. Рисует фото/эмодзи/монограмму в заданной форме и размере.
/// Можно включать бейдж редактирования.
struct AppAvatarView: View {
    let source: AvatarSource
    let shape: AvatarShape
    let size: AvatarSize
    var showsEditBadge: Bool = false
    
    init(source: AvatarSource,
         shape: AvatarShape = .circle,
         size: AvatarSize = .header,
         showsEditBadge: Bool = false) {
        self.source = source
        self.shape = shape
        self.size = size
        self.showsEditBadge = showsEditBadge
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            
            // Base background + border drawn per shape
            Group {
                switch shape {
                case .circle:
                    Circle()
                        .fill(opaqueBaseFill) // opaque base to prevent shadow bleed-through
                        .frame(width: size.side, height: size.side)
                        .overlay(
                            Circle()
                                .fill(backgroundFill) // translucent tint on top
                                .frame(width: size.side, height: size.side)
                        )
                        .overlay(Circle().stroke(borderColor, lineWidth: size.borderWidth))
                case .rounded(let c):
                    RoundedRectangle(cornerRadius: c, style: .continuous)
                        .fill(opaqueBaseFill)
                        .frame(width: size.side, height: size.side)
                        .overlay(
                            RoundedRectangle(cornerRadius: c, style: .continuous)
                                .fill(backgroundFill)
                                .frame(width: size.side, height: size.side)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: c, style: .continuous)
                                .stroke(borderColor, lineWidth: size.borderWidth)
                        )
                }
            }
            .shadow(color: AppButtonStyle.Primary.shadow, radius: AppButtonStyle.Primary.shadowRadius, x: 0, y: 2)
            
            // Content (image/emoji/monogram) clipped to shape
            Group {
                switch shape {
                case .circle:
                    contentOverlay
                        .clipShape(Circle())
                case .rounded(let c):
                    contentOverlay
                        .clipShape(RoundedRectangle(cornerRadius: c, style: .continuous))
                }
            }
            .frame(width: size.side, height: size.side)
            
            if showsEditBadge {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: editBadgeFont, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.25))
                            .frame(width: editBadgeFrame, height: editBadgeFrame)
                    )
                    .offset(x: 4, y: 4)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size.side, height: size.side)
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Private
    
    private var editBadgeFont: CGFloat {
        switch size {
        case .header: return 22
        case .listLarge: return 18
        case .listSmall: return 14
        case .inline: return 12
        case .headerXL: return 22
        }
    }
    private var editBadgeFrame: CGFloat { editBadgeFont + 4 }
    
    private var borderColor: Color {
        Color.black.opacity(0.05)
    }
    
    private var opaqueBaseFill: Color {
        Color(UIColor.secondarySystemBackground)
    }
    
    /// Фон зависит от источника: для фото — прозрачный, для эмодзи/монограммы — мягкий системный фон.
    private var backgroundFill: Color {
        switch source {
        case .image:
            return Color.clear
        case .emoji(let value):
            return AvatarColors.color(for: value)
        case .monogram(let value):
            return AvatarColors.color(for: value)
        }
    }
    
    @ViewBuilder
    private var contentOverlay: some View {
        switch source {
        case .image(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.side, height: size.side)
                .clipped()
        case .emoji(let value):
            Text(value.isEmpty ? "🙂" : value)
                .font(.system(size: size.glyphFontSize))
                .frame(width: size.side, height: size.side)
        case .monogram(let value):
            Text(value.isEmpty ? "?" : value)
                .font(.system(size: size.glyphFontSize, weight: .semibold))
                .frame(width: size.side, height: size.side)
        }
    }
}

/// Готовая шапка для экранов редактирования:
/// аватар + кнопка "Выбрать аватар", упакованные в Section для Form.
struct AvatarHeaderSection: View {
    let source: AvatarSource
    let shape: AvatarShape
    let size: AvatarSize
    let buttonTitle: String
    let onTap: () -> Void
    @Environment(\.horizontalSizeClass) private var hSize

    // Compact-friendly vertical metrics
    private var topPadding: CGFloat { hSize == .compact ? 6 : 12 }
    private var bottomPadding: CGFloat { hSize == .compact ? 6 : 10 }
    private var rowTopInset: CGFloat { hSize == .compact ? 6 : 12 }
    private var rowBottomInset: CGFloat { hSize == .compact ? 4 : 8 }
    private var verticalSpacing: CGFloat { hSize == .compact ? 4 : 6 }
    
    var body: some View {
        Section {
            VStack(spacing: verticalSpacing) {
                Button(action: onTap) {
                    AppAvatarView(source: source, shape: shape, size: size, showsEditBadge: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Выбрать аватар")
                
                Button(buttonTitle, action: onTap)
                    .font(.callout)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
        .listRowInsets(EdgeInsets(top: rowTopInset, leading: 0, bottom: rowBottomInset, trailing: 0))
        .listRowBackground(Color.clear)
    }
}

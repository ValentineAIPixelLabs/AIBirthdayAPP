import SwiftUI

struct ContactAvatarHeaderView: View {
    let contact: Contact
    let pickedImage: UIImage?
    let pickedEmoji: String?
    let headerHeight: CGFloat
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20) // Отступ сверху уменьшен для аккуратного вида
            Button(action: onTap) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.001))
                        .avatarFrame(size: CardStyle.Avatar.size * 2.5 + CardStyle.Avatar.size * 0.42)
                        .avatarShadow()
                    if let imageData = contact.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: pickedImage ?? uiImage)
                            .resizable()
                            .scaledToFill()
                            .avatarFrame(size: CardStyle.Avatar.size * 2.5)
                            .clipped()
                            .clipShape(Circle())
                    } else if let emoji = pickedEmoji ?? contact.emoji {
                        Text(emoji)
                            .font(.system(size: CardStyle.Avatar.size * 2.5 * 0.5))
                            .avatarFrame(size: CardStyle.Avatar.size * 2.5)
                            .alignmentGuide(HorizontalAlignment.center) { d in d[HorizontalAlignment.center] }
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .avatarShadow()
                    } else {
                        Text(String(contact.name.prefix(1)))
                            .font(.system(size: CardStyle.Avatar.size * 2.5 * 0.45, weight: .semibold))
                            .foregroundColor(.white)
                            .avatarFrame(size: CardStyle.Avatar.size * 2.5)
                            .alignmentGuide(HorizontalAlignment.center) { d in d[HorizontalAlignment.center] }
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .avatarShadow()
                    }
                }
                .avatarFrame(size: CardStyle.Avatar.size * 2.5)
            }
            .contentShape(Circle())
            .buttonStyle(.plain)


        }
        .padding(.top, 8)
    }




    @ViewBuilder
    private var overlayInfo: some View {
        // Removed overlayInfo content as per instructions
        EmptyView()
    }

}

struct ContactAvatarView: View {
    let contact: Contact
    let size: CGFloat

    var body: some View {
        Group {
            if let imageData = contact.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .avatarFrame(size: size)
                    .clipShape(Circle())
            } else if let emoji = contact.emoji {
                Text(emoji)
                    .font(.system(size: size * 0.45))
                    .avatarFrame(size: size)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            } else {
                let initial = String(contact.name.prefix(1)).uppercased()
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(initial)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundColor(.white)
                }
                .avatarFrame(size: size)
            }
        }
    }
}

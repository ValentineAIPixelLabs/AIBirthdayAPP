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
                        .frame(width: 187, height: 187)
                        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 10)
                    if let imageData = contact.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: pickedImage ?? uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 160)
                            .clipped()
                            .clipShape(Circle())
                    } else if let emoji = pickedEmoji ?? contact.emoji {
                        Text(emoji)
                            .font(.system(size: 80))
                            .frame(width: 160, height: 160, alignment: .center)
                            .alignmentGuide(HorizontalAlignment.center) { d in d[HorizontalAlignment.center] }
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 215/255, green: 240/255, blue: 220/255),
                                                Color(red: 170/255, green: 210/255, blue: 180/255)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                    } else {
                        Text(String(contact.name.prefix(1)))
                            .font(.system(size: 72, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 160, height: 160, alignment: .center)
                            .alignmentGuide(HorizontalAlignment.center) { d in d[HorizontalAlignment.center] }
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 180/255, green: 200/255, blue: 220/255),
                                                Color(red: 150/255, green: 175/255, blue: 200/255)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                    }
                }
                .frame(width: 160, height: 160)
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
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let emoji = contact.emoji {
                Text(emoji)
                    .font(.system(size: size * 0.65))
                    .frame(width: size, height: size)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 215/255, green: 240/255, blue: 220/255),
                                        Color(red: 170/255, green: 210/255, blue: 180/255)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            } else {
                let initial = String(contact.name.prefix(1)).uppercased()
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 180/255, green: 200/255, blue: 220/255),
                                    Color(red: 150/255, green: 175/255, blue: 200/255)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text(initial)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 1)
    }
}

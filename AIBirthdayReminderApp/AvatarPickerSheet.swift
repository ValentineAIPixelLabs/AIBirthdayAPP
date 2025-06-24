import SwiftUI

struct AvatarPickerSheet: View {
    var onCamera: () -> Void
    var onPhoto: () -> Void
    var onEmoji: () -> Void
    var onMonogram: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.17))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("ВЫБОР АВАТАРА")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)

            HStack(spacing: 8) {
                AvatarPickButton(title: "Камера", systemImage: "camera", bgColor: Color.gray.opacity(0.10), action: onCamera)
                AvatarPickButton(title: "Фото", systemImage: "photo.on.rectangle", bgColor: Color.blue.opacity(0.08), tint: .blue, action: onPhoto)
                AvatarPickButton(title: "Эмодзи", systemImage: "face.smiling", bgColor: Color.green.opacity(0.10), tint: .green, action: onEmoji)
                AvatarPickButton(title: "Монограмма", label: "A", bgColor: Color.purple.opacity(0.10), tint: .purple, action: onMonogram)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.bottom, 20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.systemBackground))
                .ignoresSafeArea()
        )
    }
}

struct AvatarPickButton: View {
    var title: String
    var systemImage: String? = nil
    var label: String? = nil
    var bgColor: Color
    var tint: Color = .gray
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(bgColor)
                        .frame(width: 82, height: 95)
                    if let systemImage {
                        Image(systemName: systemImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundColor(tint)
                    } else if let label {
                        Text(label)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(tint)
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

struct CropperView: View {
    let image: UIImage
    let onCrop: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1
    @State private var lastOffset: CGSize = .zero

    let cropSize: CGFloat = 280

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                // Background dim
                Color.black.opacity(0.6)
                    .ignoresSafeArea()

                // Cropping area
                ZStack {
                    // Image with zoom and pan
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropSize, height: cropSize)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                .frame(width: cropSize, height: cropSize)
            }
            Spacer()
            HStack(spacing: 24) {
                Button("Отмена") {
                    dismiss()
                }
                .foregroundColor(.red)
                Spacer()
                Button("Готово") {
                    let cropped = cropImage()
                    onCrop(cropped)
                    dismiss()
                }
                .bold()
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 32)
        }
        .background(Color.black.opacity(0.65).ignoresSafeArea())
    }

    // MARK: - Crop logic

    private func cropImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
        return renderer.image { ctx in
            let context = ctx.cgContext

            // Center of cropping circle
            let center = CGPoint(x: cropSize / 2, y: cropSize / 2)

            // Make circular path and clip
            context.addEllipse(in: CGRect(origin: .zero, size: CGSize(width: cropSize, height: cropSize)))
            context.clip()

            // Compute scale and offset for image draw
            let imgSize = image.size
            let displayScale = scale
            let drawWidth = imgSize.width * displayScale
            let drawHeight = imgSize.height * displayScale

            // Center the image in crop circle, add user offset
            let drawRect = CGRect(
                x: center.x - drawWidth / 2 + offset.width,
                y: center.y - drawHeight / 2 + offset.height,
                width: drawWidth,
                height: drawHeight
            )

            image.draw(in: drawRect)
        }
    }
}

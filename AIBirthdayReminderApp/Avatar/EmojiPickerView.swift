import SwiftUI

struct EmojiCategory: Identifiable {
    let id = UUID()
    let title: String
    let emojis: [String]
}

@MainActor struct EmojiPickerView: View {
    @Environment(\.dismiss) var dismiss
    let onSelect: (String?) -> Void

    let categories: [EmojiCategory] = [
        EmojiCategory(title: "Часто используемые", emojis: ["🎁", "🥳", "🎉", "🎊", "❤️", "🍾", "🎂", "🎓", "🏆", "💍"]),
        EmojiCategory(title: "Смайлы и люди", emojis: ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🥸", "🤩", "🥰", "😡", "😢", "😭", "😱", "😴", "🤤", "😷", "🤒", "🤕", "🤑", "🤠", "😈", "👿"]),
        EmojiCategory(title: "Животные и природа", emojis: ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🦄", "🐔", "🐧", "🐦", "🐤", "🐣", "🐥", "🦆", "🦅", "🦉", "🦇", "🐺"]),
        EmojiCategory(title: "Еда и напитки", emojis: ["🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍈", "🍒", "🍑", "🍍", "🥭", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥕", "🌽", "🥔", "🍠", "🥐", "🍞", "🥖", "🧀", "🥚", "🍳", "🥓", "🥩"]),
        EmojiCategory(title: "Активность и спорт", emojis: ["⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🏉", "🎱", "🏓", "🏸", "🥊", "🥋", "🎽", "⛳️", "🎯", "🥌"]),
        EmojiCategory(title: "Путешествия и транспорт", emojis: ["✈️", "🚗", "🚕", "🚙", "🚌", "🚎", "🚓", "🚑", "🚒", "🚐", "🚚", "🚛", "🚜", "🏍️", "🛵", "🚲"]),
        EmojiCategory(title: "Символы", emojis: ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "🔔", "🔕"]),
    ]

    let columns = [GridItem(.adaptive(minimum: 48), spacing: 12)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categories, id: \.id) { category in
                        Text(category.title)
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(category.emojis, id: \.self) { emoji in
                                emojiButton(emoji)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Эмодзи")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func emojiButton(_ emoji: String) -> some View {
        Button(action: {
            DispatchQueue.main.async {
                onSelect(emoji)
                dismiss()
            }
        }) {
            Text(emoji)
                .font(.system(size: 32))
                .frame(width: 48, height: 48)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.3)))
        }
    }
}

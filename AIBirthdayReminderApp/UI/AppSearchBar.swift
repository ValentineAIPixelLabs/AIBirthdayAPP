import SwiftUI

struct AppSearchable: ViewModifier {
    @Binding var text: String
    var prompt: LocalizedStringKey = "search.prompt"
    var placement: SearchFieldPlacement = .automatic

    func body(content: Content) -> some View {
        content
            .searchable(text: $text, placement: placement, prompt: Text(prompt))
    }
}

extension View {
    func appSearchable(text: Binding<String>, prompt: LocalizedStringKey = "search.prompt", placement: SearchFieldPlacement = .automatic) -> some View {
        self.modifier(AppSearchable(text: text, prompt: prompt, placement: placement))
    }
}

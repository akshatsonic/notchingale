import SwiftUI

struct NotepadCardView: View {
    @ObservedObject var store: AppStore
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        CardContainer(title: "Notepad", tint: Theme.notepadCard, titleIcon: "note.text") {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateString)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.cardTextSecondary)

                DottedDivider()

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $store.notepad)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.cardTextPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .focused($isEditorFocused)

                    // Shown only while empty AND not focused — rather than
                    // trying to pixel-align this against wherever
                    // TextEditor's own internal NSTextView inset happens
                    // to put the cursor (which isn't something reliably
                    // knowable without visually testing it), the
                    // placeholder just disappears the moment you click in,
                    // so there's never a frame where both are visible at
                    // once and could visibly disagree on position.
                    if store.notepad.isEmpty && !isEditorFocused {
                        Text("Write something down…")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.cardTextSecondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxHeight: .infinity)

                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft").font(.system(size: 9))
                    Text("\(wordCount) words")
                }
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.cardTextSecondary)
            }
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: Date())
    }

    private var wordCount: Int {
        store.notepad
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }
}

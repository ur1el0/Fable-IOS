import SwiftUI
import UIKit

enum ManuscriptFormattingStyle {
    case bold
    case italic
    case quote
    case sceneBreak
}

struct ManuscriptFormattingRequest: Identifiable {
    let id = UUID()
    let style: ManuscriptFormattingStyle
}

@MainActor
struct ManuscriptEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var formattingRequest: ManuscriptFormattingRequest?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = UIColor(FableTheme.textPrimary)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.adjustsFontForContentSizeCategory = true
        textView.accessibilityLabel = "Manuscript"
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
        guard let request = formattingRequest,
              context.coordinator.lastAppliedRequestID != request.id else { return }
        context.coordinator.apply(request.style, to: textView)
        context.coordinator.lastAppliedRequestID = request.id
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding private var text: String
        var lastAppliedRequestID: UUID?

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }

        func apply(_ style: ManuscriptFormattingStyle, to textView: UITextView) {
            let source = textView.text as NSString
            let selection = NSRange(
                location: min(textView.selectedRange.location, source.length),
                length: min(textView.selectedRange.length, source.length - min(textView.selectedRange.location, source.length))
            )
            let selectedText = source.substring(with: selection)
            var replacementRange = selection
            let replacement: String
            let caretLocation: Int

            switch style {
            case .bold:
                replacement = "**\(selectedText)**"
                caretLocation = selection.location + (selectedText.isEmpty ? 2 : replacement.utf16.count)
            case .italic:
                replacement = "*\(selectedText)*"
                caretLocation = selection.location + (selectedText.isEmpty ? 1 : replacement.utf16.count)
            case .quote:
                if selectedText.isEmpty {
                    replacement = "> "
                    caretLocation = selection.location + replacement.utf16.count
                } else {
                    let quoted = selectedText
                        .components(separatedBy: .newlines)
                        .map { "> \($0)" }
                        .joined(separator: "\n")
                    replacement = quoted
                    caretLocation = selection.location + replacement.utf16.count
                }
            case .sceneBreak:
                replacementRange = NSRange(location: NSMaxRange(selection), length: 0)
                replacement = "\n\n---\n\n"
                caretLocation = replacementRange.location + replacement.utf16.count
            }

            let updated = source.replacingCharacters(in: replacementRange, with: replacement)
            textView.text = updated
            text = updated
            textView.selectedRange = NSRange(location: min(caretLocation, (updated as NSString).length), length: 0)
        }
    }
}

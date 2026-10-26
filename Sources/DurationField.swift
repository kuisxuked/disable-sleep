import AppKit
import SwiftUI

struct DurationField: NSViewRepresentable {
    @Binding var value: String
    let language: AppLanguage

    func makeCoordinator() -> Coordinator { Coordinator(value: $value) }

    func makeNSView(context: Context) -> NSComboBox {
        let field = NSComboBox()
        field.isEditable = true
        field.completes = false
        field.controlSize = .small
        field.font = .systemFont(ofSize: 12)
        field.numberOfVisibleItems = 5
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSComboBox, context: Context) {
        context.coordinator.value = $value
        let options = ["15", "30", "60", "120", language.text("永不", "Never")]
        if field.objectValues.compactMap({ $0 as? String }) != options {
            field.removeAllItems()
            field.addItems(withObjectValues: options)
        }
        let display = value == "never" ? language.text("永不", "Never") : value
        if field.stringValue != display { field.stringValue = display }
        field.setAccessibilityLabel(language.text("分钟数或永不", "Minutes or Never"))
    }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        var value: Binding<String>
        init(value: Binding<String>) { self.value = value }
        private func save(_ text: String) {
            value.wrappedValue = ["Never", "永不"].contains(text) ? "never" : text
        }
        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSComboBox { save(field.stringValue) }
        }
        func comboBoxSelectionDidChange(_ notification: Notification) {
            if let field = notification.object as? NSComboBox,
               let selected = field.objectValueOfSelectedItem as? String { save(selected) }
        }
    }
}

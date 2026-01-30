import SwiftUI

extension Binding {
    /// Creates a Boolean binding from an optional binding.
    /// Returns true when the optional has a value, false otherwise.
    /// Setting to false sets the optional to nil.
    ///
    /// This is useful for converting `@State var item: Item?` to `isPresented: Binding<Bool>`
    /// for sheets and alerts.
    ///
    /// Usage:
    /// ```swift
    /// @State private var itemToDelete: Item?
    ///
    /// .alert("Delete?", isPresented: $itemToDelete.isPresent()) {
    ///     Button("Delete", role: .destructive) {
    ///         if let item = itemToDelete {
    ///             delete(item)
    ///         }
    ///     }
    /// }
    /// ```
    func isPresent<T>() -> Binding<Bool> where Value == T? {
        Binding<Bool>(
            get: { self.wrappedValue != nil },
            set: { if !$0 { self.wrappedValue = nil } }
        )
    }

    /// Creates a non-optional binding from an optional binding with a default value.
    /// Useful when you need to pass a non-optional binding to a view.
    ///
    /// Usage:
    /// ```swift
    /// @State private var text: String?
    /// TextField("Enter text", text: $text.withDefault(""))
    /// ```
    func withDefault<T>(_ defaultValue: T) -> Binding<T> where Value == T? {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

extension Binding where Value == Bool {
    /// Creates an inverted binding.
    /// Useful when you need to negate a boolean binding.
    var not: Binding<Bool> {
        Binding<Bool>(
            get: { !self.wrappedValue },
            set: { self.wrappedValue = !$0 }
        )
    }
}

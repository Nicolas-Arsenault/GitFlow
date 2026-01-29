import SwiftUI
import AppKit

// MARK: - Custom Hover Tooltip Using NSWindow

/// A view modifier that shows a native-style tooltip when hovering.
/// Uses a floating NSWindow for proper positioning above all content.
struct TooltipModifier: ViewModifier {
    let tooltip: String

    @State private var isHovering = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    TooltipTrigger(
                        tooltip: tooltip,
                        isHovering: $isHovering,
                        hoverTask: $hoverTask,
                        frame: geometry.frame(in: .global)
                    )
                }
            )
            .onHover { hovering in
                isHovering = hovering
                if !hovering {
                    hoverTask?.cancel()
                    TooltipWindowController.shared.hide()
                }
            }
    }
}

/// Background view that triggers tooltip display.
private struct TooltipTrigger: View {
    let tooltip: String
    @Binding var isHovering: Bool
    @Binding var hoverTask: Task<Void, Never>?
    let frame: CGRect

    var body: some View {
        Color.clear
            .onChange(of: isHovering) { hovering in
                hoverTask?.cancel()

                if hovering {
                    hoverTask = Task {
                        try? await Task.sleep(nanoseconds: 700_000_000) // 0.7 seconds
                        if !Task.isCancelled {
                            await MainActor.run {
                                TooltipWindowController.shared.show(tooltip: tooltip)
                            }
                        }
                    }
                }
            }
    }
}

/// Singleton controller for the tooltip window.
final class TooltipWindowController {
    static let shared = TooltipWindowController()

    private var window: NSPanel?
    private var textField: NSTextField?
    private var currentTooltip: String = ""

    private init() {}

    func show(tooltip: String) {
        // Get current mouse location (in screen coordinates)
        let mouseLocation = NSEvent.mouseLocation

        // Create window if needed
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 24),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.hasShadow = true
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            // Create container view with visual effect for proper background
            let visualEffect = NSVisualEffectView()
            visualEffect.material = .toolTip
            visualEffect.state = .active
            visualEffect.wantsLayer = true
            visualEffect.layer?.cornerRadius = 4
            visualEffect.layer?.borderColor = NSColor.separatorColor.cgColor
            visualEffect.layer?.borderWidth = 0.5

            // Create a simple text field for the tooltip
            let field = NSTextField(labelWithString: "")
            field.font = NSFont.toolTipsFont(ofSize: 11)
            field.textColor = NSColor.textColor
            field.drawsBackground = false
            field.isBezeled = false
            field.isEditable = false
            field.isSelectable = false
            field.alignment = .left
            field.lineBreakMode = .byWordWrapping
            field.maximumNumberOfLines = 0

            visualEffect.addSubview(field)
            panel.contentView = visualEffect

            // Position field with padding
            field.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 8),
                field.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -8),
                field.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 4),
                field.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -4)
            ])

            self.window = panel
            self.textField = field
        }

        // Update text
        currentTooltip = tooltip
        textField?.stringValue = tooltip

        // Calculate size based on text
        let maxWidth: CGFloat = 300
        let font = NSFont.toolTipsFont(ofSize: 11)
        let textSize = (tooltip as NSString).boundingRect(
            with: NSSize(width: maxWidth - 16, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        ).size

        let width = ceil(min(max(textSize.width + 18, 40), maxWidth))
        let height = ceil(textSize.height + 10)

        // Position below and slightly to the right of cursor
        let x = mouseLocation.x + 12
        let y = mouseLocation.y - height - 16

        window?.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}

/// The visual content of the tooltip.
private struct TooltipContent: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }
}

extension View {
    /// Adds a tooltip that appears when hovering over the view.
    /// Shows after a short delay, like native macOS tooltips.
    /// - Parameter tooltip: The tooltip text to display.
    /// - Returns: A view with the tooltip applied.
    func tooltip(_ tooltip: String) -> some View {
        self.modifier(TooltipModifier(tooltip: tooltip))
    }
}

// MARK: - Conditional View Modifiers

extension View {
    /// Applies a transformation to a view if a condition is true.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transformation to apply if the condition is true.
    /// - Returns: The transformed view if the condition is true, otherwise the original view.
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies a transformation to a view if a value is non-nil.
    /// - Parameters:
    ///   - value: The optional value to check.
    ///   - transform: The transformation to apply if the value is non-nil.
    /// - Returns: The transformed view if the value is non-nil, otherwise the original view.
    @ViewBuilder
    func applyIfLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}


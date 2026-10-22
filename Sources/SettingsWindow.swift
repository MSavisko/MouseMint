import AppKit

final class SettingsWindow: NSWindowController {
    let automaticSwitch = NSSwitch()
    let naturalSwitch = NSSwitch()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    private let automaticChanged: (Bool) -> Void
    private let naturalChanged: (Bool) -> Void

    init(automaticChanged: @escaping (Bool) -> Void, naturalChanged: @escaping (Bool) -> Void) {
        self.automaticChanged = automaticChanged
        self.naturalChanged = naturalChanged
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Keychron Charge Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24)
        ])

        func explanation(_ text: String) -> NSTextField {
            let label = NSTextField(wrappingLabelWithString: text)
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            return label
        }
        func add(_ view: NSView) {
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        func toggleRow(_ title: String, control: NSSwitch, selector: Selector) -> NSStackView {
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 13, weight: .medium)
            control.target = self
            control.action = selector
            control.setAccessibilityLabel(title)
            let row = NSStackView(views: [label, NSView(), control])
            row.orientation = .horizontal
            row.alignment = .centerY
            return row
        }

        add(toggleRow("Automatically switch Natural Scrolling", control: automaticSwitch, selector: #selector(changeAutomatic)))
        add(explanation("Mouse connected → Off\nMouse disconnected → On"))
        add(explanation("Works with USB cable, receiver, and Bluetooth while this app is open. Checks about every five seconds."))
        let separator = NSBox()
        separator.boxType = .separator
        add(separator)
        add(toggleRow("Natural Scrolling", control: naturalSwitch, selector: #selector(changeNatural)))
        add(explanation("macOS shares this setting between your mouse and trackpad. Turn off automatic switching to change it here or in macOS Settings."))
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        add(statusLabel)
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = .systemRed
        add(errorLabel)
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(from scrolling: AutomaticNaturalScrolling) {
        automaticSwitch.state = scrolling.isAutomatic ? .on : .off
        naturalSwitch.state = scrolling.state.live.map { $0 ? .on : .off } ?? .mixed
        naturalSwitch.isEnabled = !scrolling.isAutomatic && scrolling.state.live != nil
        statusLabel.stringValue = scrolling.isAutomatic
            ? "Automatic switching is on. Your connection controls the setting."
            : "Automatic switching is off. Your scrolling setting stays as you choose."
        errorLabel.stringValue = scrolling.errorMessage ?? (scrolling.state.live == nil ? "Natural Scrolling is unavailable on this macOS version." : "")
        errorLabel.isHidden = errorLabel.stringValue.isEmpty
    }

    func present() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func changeAutomatic() { automaticChanged(automaticSwitch.state == .on) }
    @objc private func changeNatural() { naturalChanged(naturalSwitch.state == .on) }
}

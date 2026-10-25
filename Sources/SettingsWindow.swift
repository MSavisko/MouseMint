import AppKit

final class SettingsWindow: NSWindowController, NSToolbarDelegate {
    enum Pane: String, CaseIterable {
        case general, naturalScrolling, diagnostics, about

        var title: String {
            switch self {
            case .general: return "General"
            case .naturalScrolling: return "Natural Scrolling"
            case .diagnostics: return "Diagnostics"
            case .about: return "About"
            }
        }
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .naturalScrolling: return "arrow.up.arrow.down"
            case .diagnostics: return "stethoscope"
            case .about: return "info.circle"
            }
        }
        var identifier: NSToolbarItem.Identifier { .init(rawValue) }
        var height: CGFloat {
            switch self {
            case .general: return 250
            case .naturalScrolling: return 350
            case .diagnostics: return 400
            case .about: return 250
            }
        }
    }

    let automaticSwitch = NSSwitch()
    let naturalSwitch = NSSwitch()
    let intervalSlider = NSSlider(value: 2, minValue: 0, maxValue: 4, target: nil, action: nil)
    let intervalLabel = NSTextField(labelWithString: "Every 5 seconds (default)")
    let refreshButton = NSButton(title: "Refresh Now", target: nil, action: nil)
    let copyButton = NSButton(title: "Copy Diagnostics", target: nil, action: nil)
    let diagnosticsText = NSTextView()
    private(set) var selectedPane: Pane = .general
    private(set) var copyStatus = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    private let automaticChanged: (Bool) -> Void
    private let naturalChanged: (Bool) -> Void
    private let intervalChanged: (Int) -> Void
    private var displayedInterval: Int?
    private let refreshRequested: () -> Void
    private let diagnostics: () -> String
    private let pasteboard: NSPasteboard
    private var panes: [Pane: NSView] = [:]

    init(automaticChanged: @escaping (Bool) -> Void, naturalChanged: @escaping (Bool) -> Void,
         intervalChanged: @escaping (Int) -> Void,
         refreshRequested: @escaping () -> Void, diagnostics: @escaping () -> String,
         pasteboard: NSPasteboard = .general) {
        self.automaticChanged = automaticChanged
        self.naturalChanged = naturalChanged
        self.intervalChanged = intervalChanged
        self.refreshRequested = refreshRequested
        self.diagnostics = diagnostics
        self.pasteboard = pasteboard
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: Pane.general.height),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "MouseMint Settings"
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .preference
        super.init(window: window)

        panes[.general] = generalPane()
        panes[.naturalScrolling] = scrollingPane()
        panes[.diagnostics] = diagnosticsPane()
        panes[.about] = aboutPane()
        let toolbar = NSToolbar(identifier: "MouseMintSettings")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
        selectPane(.general)
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Pane.allCases.map(\.identifier)
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Pane.allCases.map(\.identifier)
    }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Pane.allCases.map(\.identifier)
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let pane = Pane(rawValue: identifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = pane.title
        item.paletteLabel = pane.title
        item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.title)
        item.target = self
        item.action = #selector(changePane(_:))
        return item
    }

    func selectPane(_ pane: Pane) {
        guard let window, let view = panes[pane] else { return }
        selectedPane = pane
        window.contentView = view
        window.setContentSize(NSSize(width: 500, height: pane.height))
        window.toolbar?.selectedItemIdentifier = pane.identifier
        if pane == .diagnostics { updateDiagnostics() }
    }

    private func makePane() -> (NSView, NSStackView) {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 350))
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24)
        ])
        return (view, stack)
    }

    private func add(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func explanation(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func toggleRow(_ title: String, control: NSSwitch, selector: Selector) -> NSStackView {
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

    private func scrollingPane() -> NSView {
        let (view, stack) = makePane()
        add(toggleRow("Automatically switch Natural Scrolling", control: automaticSwitch, selector: #selector(changeAutomatic)), to: stack)
        add(explanation("Mouse connected → Off\nMouse disconnected → On"), to: stack)
        add(explanation("Works with USB cable, receiver, and Bluetooth while this app is open. The check interval is set in General."), to: stack)
        let separator = NSBox()
        separator.boxType = .separator
        add(separator, to: stack)
        add(toggleRow("Natural Scrolling", control: naturalSwitch, selector: #selector(changeNatural)), to: stack)
        add(explanation("macOS shares this setting between your mouse and trackpad. Turn off automatic switching to change it here or in macOS Settings."), to: stack)
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        add(statusLabel, to: stack)
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = .systemRed
        add(errorLabel, to: stack)
        return view
    }

    private func generalPane() -> NSView {
        let (view, stack) = makePane()
        let title = NSTextField(labelWithString: "Status check interval")
        title.font = .systemFont(ofSize: 13, weight: .medium)
        add(title, to: stack)
        add(explanation("Checks battery, connection, and automatic scrolling. Faster checks react sooner; slower checks make fewer requests."), to: stack)
        intervalSlider.numberOfTickMarks = StatusInterval.seconds.count
        intervalSlider.allowsTickMarkValuesOnly = true
        intervalSlider.isContinuous = false
        intervalSlider.target = self
        intervalSlider.action = #selector(changeInterval)
        intervalSlider.setAccessibilityLabel("Status check interval")
        add(intervalSlider, to: stack)
        let ticks = NSStackView(views: StatusInterval.seconds.map { NSTextField(labelWithString: "\($0) s") })
        ticks.orientation = .horizontal
        ticks.distribution = .equalSpacing
        add(ticks, to: stack)
        intervalLabel.font = .systemFont(ofSize: 12, weight: .medium)
        add(intervalLabel, to: stack)
        add(explanation("This changes status checks, not the mouse's movement polling rate. Your choice is saved. Bluetooth battery freshness is managed by macOS."), to: stack)
        return view
    }

    private func diagnosticsPane() -> NSView {
        let (view, stack) = makePane()
        add(explanation("Inspect the latest mouse reading and scrolling settings. Copy this report when troubleshooting. Nothing is sent automatically."), to: stack)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        diagnosticsText.isEditable = false
        diagnosticsText.isSelectable = true
        diagnosticsText.isRichText = false
        diagnosticsText.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        diagnosticsText.textContainerInset = NSSize(width: 8, height: 8)
        diagnosticsText.isVerticallyResizable = true
        diagnosticsText.isHorizontallyResizable = false
        diagnosticsText.autoresizingMask = [.width]
        diagnosticsText.textContainer?.widthTracksTextView = true
        diagnosticsText.setAccessibilityLabel("Diagnostic report")
        scroll.documentView = diagnosticsText
        add(scroll, to: stack)
        scroll.heightAnchor.constraint(equalToConstant: 252).isActive = true
        refreshButton.target = self
        refreshButton.action = #selector(refreshDiagnostics)
        copyButton.target = self
        copyButton.action = #selector(copyDiagnostics)
        refreshButton.bezelStyle = .rounded
        copyButton.bezelStyle = .rounded
        let buttons = NSStackView(views: [refreshButton, NSView(), copyButton])
        buttons.orientation = .horizontal
        add(buttons, to: stack)
        copyStatus.font = .systemFont(ofSize: 12)
        copyStatus.textColor = .secondaryLabelColor
        copyStatus.setAccessibilityRole(.staticText)
        add(copyStatus, to: stack)
        return view
    }

    private func aboutPane() -> NSView {
        let (view, stack) = makePane()
        let title = NSTextField(labelWithString: "MouseMint")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        add(title, to: stack)
        add(explanation(AppVersion.description), to: stack)
        add(explanation("Mouse battery and scrolling controls for macOS. Supports Keychron M3-A3 over USB cable, USB-C receiver, and Bluetooth."), to: stack)
        add(explanation("Choose how often to check status in General. Natural Scrolling automation is optional."), to: stack)
        add(explanation("Independent utility; not affiliated with Keychron."), to: stack)
        return view
    }

    func update(from scrolling: AutomaticNaturalScrolling, refreshing: Bool = false, statusInterval: Int = StatusInterval.defaultSeconds) {
        let seconds = StatusInterval.validated(statusInterval)
        // A background refresh must not reset a slider drag in progress.
        if displayedInterval != seconds {
            intervalSlider.doubleValue = Double(StatusInterval.sliderIndex(for: seconds))
            intervalLabel.stringValue = "Every \(seconds) seconds\(seconds == StatusInterval.defaultSeconds ? " (default)" : "")"
            intervalSlider.setAccessibilityValueDescription("Every \(seconds) seconds")
            displayedInterval = seconds
        }
        automaticSwitch.state = scrolling.isAutomatic ? .on : .off
        naturalSwitch.state = scrolling.state.live.map { $0 ? .on : .off } ?? .mixed
        naturalSwitch.isEnabled = !scrolling.isAutomatic && scrolling.state.live != nil
        statusLabel.stringValue = scrolling.isAutomatic
            ? "Automatic switching is on. Your connection controls the setting."
            : "Automatic switching is off. Your scrolling setting stays as you choose."
        errorLabel.stringValue = scrolling.errorMessage ?? (scrolling.state.live == nil ? "Natural Scrolling is unavailable on this macOS version." : "")
        errorLabel.isHidden = errorLabel.stringValue.isEmpty
        refreshButton.isEnabled = !refreshing
        refreshButton.title = refreshing ? "Refreshing…" : "Refresh Now"
        updateDiagnostics()
    }

    private func updateDiagnostics() {
        let report = diagnostics()
        if diagnosticsText.string != report {
            diagnosticsText.string = report
            copyStatus.stringValue = ""
        }
    }

    func present() {
        window?.toolbar?.isVisible = true
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func changePane(_ sender: NSToolbarItem) {
        if let pane = Pane(rawValue: sender.itemIdentifier.rawValue) { selectPane(pane) }
    }
    @objc private func changeAutomatic() { automaticChanged(automaticSwitch.state == .on) }
    @objc private func changeNatural() { naturalChanged(naturalSwitch.state == .on) }
    @objc private func changeInterval() {
        let seconds = StatusInterval.seconds(at: intervalSlider.doubleValue)
        intervalSlider.doubleValue = Double(StatusInterval.sliderIndex(for: seconds))
        intervalChanged(seconds)
    }
    @objc private func refreshDiagnostics() { refreshRequested() }
    @objc private func copyDiagnostics() {
        updateDiagnostics()
        pasteboard.clearContents()
        copyStatus.stringValue = pasteboard.setString(diagnosticsText.string, forType: .string)
            ? "Diagnostics copied." : "Could not copy diagnostics. Try again."
    }
}

enum AppVersion {
    static var description: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return "Development build"
        }
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Version \(version) (\(build))"
    }
}

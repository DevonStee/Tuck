import AppKit
import ServiceManagement

// Tuck hides menu bar items the way Ice does, and does nothing else.
//
// Two status items sit side by side: the toggle (chevron) and a divider (thin
// line) to its left. Every item left of the divider is hidden: collapsing
// stretches the divider to 10 000 pt, which pushes those items off the screen.
// The user decides what is hidden by ⌘-dragging items across the divider,
// which is the system's own way of rearranging the menu bar.
//
// Everything runs on the main thread. No permissions are needed.

private let toggleName = "tuck.toggle"
private let dividerName = "tuck.divider"
private let collapsedLength: CGFloat = 10_000
private let autoCollapseDelay: TimeInterval = 10

final class Tuck: NSObject, NSApplicationDelegate {
    private enum State {
        case collapsed
        case expanded
    }

    private var toggle: NSStatusItem!
    private var divider: NSStatusItem!
    private var state = State.expanded
    private var collapseTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Positions count from the right edge. Seeding them only on first run
        // puts the divider just left of the toggle; afterwards the system
        // remembers wherever the user ⌘-dragged them.
        seedPosition(toggleName, 0)
        seedPosition(dividerName, 1)

        toggle = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggle.autosaveName = toggleName
        divider = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        divider.autosaveName = dividerName

        for item in [toggle!, divider!] {
            item.button?.target = self
            item.button?.action = #selector(clicked(_:))
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        divider.button?.image = Self.dividerImage
        divider.button?.toolTip = "⌘ 拖到这条线左边的图标会被藏起来"

        render()
        // Status item windows get their frames a moment after launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.collapse() }
    }

    // MARK: - Actions

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            showMenu(from: sender)
            return
        }
        switch state {
        case .collapsed: expand()
        case .expanded: collapse()
        }
    }

    private func expand() {
        state = .expanded
        render()
        scheduleAutoCollapse()
    }

    private func collapse() {
        collapseTimer?.invalidate()
        collapseTimer = nil
        // If the divider ended up right of the toggle, stretching it would push
        // the toggle itself off screen and leave no way back. Stay expanded.
        guard dividerIsLeftOfToggle() else {
            state = .expanded
            render()
            return
        }
        state = .collapsed
        render()
    }

    private func render() {
        switch state {
        case .collapsed:
            divider.length = collapsedLength
            divider.button?.image = nil
            toggle.button?.image = Self.symbol("chevron.left", label: "展开隐藏的图标")
        case .expanded:
            divider.length = NSStatusItem.variableLength
            divider.button?.image = Self.dividerImage
            toggle.button?.image = Self.symbol("chevron.right", label: "收起图标")
        }
    }

    // MARK: - Auto collapse

    private func scheduleAutoCollapse() {
        collapseTimer?.invalidate()
        collapseTimer = Timer.scheduledTimer(withTimeInterval: autoCollapseDelay, repeats: false) { [weak self] _ in
            guard let self else { return }
            // Don't pull items away while the user is reaching for one or has its menu open.
            if Self.mouseIsInMenuBar() || Self.menuIsOpen() {
                self.scheduleAutoCollapse()
            } else {
                self.collapse()
            }
        }
    }

    private static func mouseIsInMenuBar() -> Bool {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            let frame = screen.frame
            let barHeight = max(frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
            return point.x >= frame.minX && point.x < frame.maxX
                && point.y <= frame.maxY && point.y >= frame.maxY - barHeight
        }
    }

    /// Window layers are readable without Screen Recording permission; titles are not needed.
    private static func menuIsOpen() -> Bool {
        let menuLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { ($0[kCGWindowLayer as String] as? Int) == menuLayer }
    }

    // MARK: - Geometry

    private func dividerIsLeftOfToggle() -> Bool {
        guard
            let dividerFrame = divider.button?.window?.frame,
            let toggleFrame = toggle.button?.window?.frame,
            dividerFrame.width > 0, toggleFrame.width > 0
        else { return false }
        return dividerFrame.maxX <= toggleFrame.minX + 1
    }

    private func seedPosition(_ autosaveName: String, _ position: CGFloat) {
        let key = "NSStatusItem Preferred Position \(autosaveName)"
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(position, forKey: key)
        }
    }

    // MARK: - Menu

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "⌘ 拖动图标越过竖线，就能决定藏哪些", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let login = menu.addItem(withTitle: "开机启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Tuck", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Tuck: launch at login failed: \(error)")
        }
    }

    // MARK: - Images

    private static func symbol(_ name: String, label: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        return NSImage(systemSymbolName: name, accessibilityDescription: label)?.withSymbolConfiguration(config)
    }

    private static let dividerImage: NSImage = {
        let image = NSImage(size: NSSize(width: 6, height: 16), flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: 2, height: 12), xRadius: 1, yRadius: 1).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

let app = NSApplication.shared
let delegate = Tuck()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

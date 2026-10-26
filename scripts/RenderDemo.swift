// Interactive native UI fixture for product recordings. No power settings change.
import AppKit
import SwiftUI

@MainActor
final class DemoScenes: NSObject {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 124), styleMask: [.titled], backing: .buffered, defer: false)
    let model = SleepModel(demo: true)
    var scene = 0

    func launch() {
        window.title = "Disable Sleep · Demo"
        window.appearance = NSAppearance(named: .darkAqua)
        let menu = NSMenu()
        let root = NSMenuItem()
        let submenu = NSMenu()
        let next = NSMenuItem(title: "Next demo scene", action: #selector(advance), keyEquivalent: "n")
        next.target = self
        submenu.addItem(next)
        root.submenu = submenu
        menu.addItem(root)
        NSApp.mainMenu = menu
        model.activate()
        show()
    }

    @objc func advance() { scene = (scene + 1) % 6; show() }

    func show() {
        UserDefaults.standard.set(scene == 0 ? "zh" : "en", forKey: "DisableSleep.language")
        switch scene {
        case 0, 1: model.cancelCountdown(); model.toggle(false)
        case 2: model.toggle(true)
        case 3: model.keepAwakeIndefinitely()
        case 4: model.startCountdown(minutes: 30, target: false)
        case 5: model.cancelCountdown()
        default: break
        }
        let host = NSHostingView(rootView: SleepPanel(model: model, minutes: scene == 3 ? "never" : "30"))
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
@MainActor
struct DemoExporter {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.appearance = NSAppearance(named: .darkAqua)
        let scenes = DemoScenes()
        scenes.launch()
        withExtendedLifetime(scenes) { app.run() }
    }
}

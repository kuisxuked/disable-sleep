// Interactive native UI fixture for product recordings. No power settings change.
import AppKit
import SwiftUI

@MainActor
final class DemoScenes: NSObject {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 124), styleMask: [.titled], backing: .buffered, defer: false)
    let model = SleepModel(demo: true)
    var scene = 0

    func launch() {
        window.title = "LidOff · Demo"
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
        UserDefaults.standard.set(scene == 0 ? "zh" : "en", forKey: "LidOff.language")
        switch scene {
        case 0, 1: model.cancelCountdown(); model.toggle(false)
        case 2: model.toggle(true)
        case 3: model.keepAwakeIndefinitely()
        case 4: model.startCountdown(minutes: 30, target: false)
        case 5: model.cancelCountdown()
        default: break
        }
        let host = NSHostingView(rootView: SleepPanel(model: model, minutes: scene == 3 ? "never" : "30")
            .environment(\.colorScheme, .dark)
            .environment(\.controlActiveState, .active)
            .background(Color(red: 0.14, green: 0.14, blue: 0.15)))
        host.appearance = NSAppearance(named: .darkAqua)
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
        if CommandLine.arguments.contains("--export") {
            let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/native-frames")
            try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for index in 0..<6 {
                scenes.scene = index
                scenes.show()
                RunLoop.main.run(until: Date().addingTimeInterval(0.15))
                let view = scenes.window.contentView!
                view.layoutSubtreeIfNeeded()
                let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try! bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("frame-\(index).png"))
            }
            print("Exported six native LidOff demo frames without changing power settings.")
            return
        }
        withExtendedLifetime(scenes) { app.run() }
    }
}

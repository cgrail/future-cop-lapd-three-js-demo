import SwiftUI
import UIKit

@main
struct MechVsMechApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}

/* ============================================================
   Orientation — the menu, lobby and level-select rotate freely
   (portrait or either landscape), so the app opens whichever way
   the phone is being held. Once a match starts we pin to the
   orientation you deployed in: holding the phone flat makes
   gravity ambiguous, and without the pin the screen flip-flops
   mid-match (worst in joystick mode, where you hold it flatter).
   To play in portrait, rotate to portrait before you deploy.
   AppModel drives the freeze/unlock off its `screen` transitions.
============================================================ */
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// The mask the app currently permits; read by UIKit every time it
    /// re-evaluates orientation. Defaults to portrait + both landscapes
    /// (the freely-rotating menu state).
    static var orientationLock: UIInterfaceOrientationMask = .allButUpsideDown

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}

enum OrientationLock {
    /// Pin to whichever orientation is on screen right now (call when a
    /// match starts), so a flat hold can't flip it during play.
    static func freezeToCurrent() {
        guard let scene = activeWindowScene else { return }
        let mask: UIInterfaceOrientationMask
        switch scene.interfaceOrientation {
        case .landscapeLeft:  mask = .landscapeLeft
        case .landscapeRight: mask = .landscapeRight
        case .portrait:       mask = .portrait
        default:              mask = .allButUpsideDown   // ambiguous — leave all open
        }
        apply(mask, scene: scene)
    }

    /// Rotate freely again — portrait or either landscape (menu / lobby /
    /// level select).
    static func unlock() {
        guard let scene = activeWindowScene else { return }
        apply(.allButUpsideDown, scene: scene)
    }

    private static func apply(_ mask: UIInterfaceOrientationMask, scene: UIWindowScene) {
        guard AppDelegate.orientationLock != mask else { return }
        AppDelegate.orientationLock = mask
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    private static var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

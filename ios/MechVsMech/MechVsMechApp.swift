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
   Orientation lock — the Info.plist allows both landscape grips
   so either hand works at the menu, but once a match starts we
   pin to whichever grip the device is in. Holding the phone flat
   makes gravity ambiguous between landscape-left and -right, and
   without this the screen flip-flops mid-match (worst in joystick
   mode, where you naturally hold it flatter). AppModel drives the
   freeze/unlock off its `screen` transitions.
============================================================ */
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// The mask the app currently permits; read by UIKit every time it
    /// re-evaluates orientation. Defaults to both landscapes (menu state).
    static var orientationLock: UIInterfaceOrientationMask = .landscape

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}

enum OrientationLock {
    /// Pin to whichever landscape grip is on screen right now (call when a
    /// match starts), so a flat hold can't flip it during play.
    static func freezeToCurrent() {
        guard let scene = activeWindowScene else { return }
        let mask: UIInterfaceOrientationMask
        switch scene.interfaceOrientation {
        case .landscapeLeft:  mask = .landscapeLeft
        case .landscapeRight: mask = .landscapeRight
        default:              mask = .landscape   // ambiguous — leave both open
        }
        apply(mask, scene: scene)
    }

    /// Allow both landscape grips again (menu / lobby / level select).
    static func unlock() {
        guard let scene = activeWindowScene else { return }
        apply(.landscape, scene: scene)
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

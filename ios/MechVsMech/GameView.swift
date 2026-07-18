import SwiftUI
import SceneKit

/* ============================================================
   The SceneKit view + touch layer under the SwiftUI overlays.
   Swapping engines (level switch / redeploy) re-attaches the
   same views to the new engine's scene.
============================================================ */

final class GameContainerView: UIView {
    let scnView = SCNView()
    let touchView = TouchControlView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        scnView.backgroundColor = UIColor(rgb: 0x0b0d16)
        scnView.antialiasingMode = .multisampling2X
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = true
        scnView.isUserInteractionEnabled = false   // touches belong to touchView
        addSubview(scnView)
        addSubview(touchView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        scnView.frame = bounds
        touchView.frame = bounds
    }
}

struct GameView: UIViewRepresentable {
    @EnvironmentObject var model: AppModel

    func makeUIView(context: Context) -> GameContainerView {
        let v = GameContainerView()
        attach(v, coordinator: context.coordinator)
        return v
    }

    func updateUIView(_ v: GameContainerView, context: Context) {
        attach(v, coordinator: context.coordinator)
    }

    private func attach(_ v: GameContainerView, coordinator: Coordinator) {
        let engine = model.engine
        if v.scnView.scene !== engine.scene {
            v.scnView.scene = engine.scene
            v.scnView.pointOfView = engine.cameraNode
        }
        coordinator.engine = engine
        v.scnView.delegate = coordinator
        v.scnView.isPlaying = true
        v.touchView.engine = engine
        let m = model
        v.touchView.scheme = { m.scheme }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /* the render-thread frame loop entry point */
    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var engine: GameEngine?
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let engine else { return }
            let vp = renderer.currentViewport
            if vp.height > 0 { engine.viewAspect = Double(vp.width / vp.height) }
            engine.step(time: time)
        }
    }
}

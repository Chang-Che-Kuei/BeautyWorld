/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Main view controller for the AR experience.
 */
/*
func ChangeTexture(_ recognizer: UITapGestureRecognizer) {
    print("texture")
    if (recognizer.state != UIGestureRecognizerState.began){ return }//不用寫，專門為了texture
    let tapPoint:CGPoint = recognizer.location(in: recognizer.view)//將使用者點擊的位子轉成CGPoint
    let resultArray  = self.sceneView.hitTest(tapPoint, options: nil)//內建hitTest函式，會將使用者觸及的點全部物件全部存在陣列resultArray中，ＥＸ如果點在檯燈上，這個陣列至少會有檯燈和平面（檯燈在平面上，都有被手指點到）兩個東西
    if resultArray.count == 0{ return}//如果使用者耍蠢-->沒東西還換texture，預防之後硬取出空陣列而當掉
    let result = resultArray.first//拿出陣列中的第一個（距離使用者最近的物件）
    let node:SCNNode = result!.node;
    let parentNode:SCNNode = node.parent!
    if( parentNode.isKind(of: Domino.self)) {//如果是骨牌 就用換骨牌的程式
        var c = parentNode as! Domino
        print("domino texture change")
        c.changeMaterial()
    }
    else if( parentNode.isKind(of: Pyramid.self)) {//如果是金字塔 就用換金字塔的程式
        var c = parentNode as! Pyramid
        print("Pyramid texture change")
        c.changeMaterial()
    }
    else if( parentNode.isKind(of: Plane.self)) {//如果是平面 就用換平面的程式
        var c = parentNode as! Plane
        print("Plane texture change")
        c.changeMaterial()
    }
}
*/






import ARKit
import Foundation
import AVFoundation
import SceneKit
import UIKit
import Photos
import AudioKit

class ViewController: UIViewController, ARSCNViewDelegate, UIPopoverPresentationControllerDelegate, VirtualObjectSelectionViewControllerDelegate {
    
    // MARK: - Main Setup & View Controller methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Setting.registerDefaults()
        setupScene()
        setupDebug()
        setupUIControls()
        setupFocusSquare()
        setupTable()
        updateSettings()
        resetVirtualObject()
        
        setupGesture()
        
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from being dimmed after a while.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Start the ARSession.
        restartPlaneDetection()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause()
    }
    
    // MARK: - ARKit / ARSCNView
    let session = ARSession()
    var sessionConfig: ARSessionConfiguration = ARWorldTrackingSessionConfiguration()
    var use3DOFTracking = false {
        didSet {
            if use3DOFTracking {
                sessionConfig = ARSessionConfiguration()
            }
            sessionConfig.isLightEstimationEnabled = UserDefaults.standard.bool(for: .ambientLightEstimation)
            session.run(sessionConfig)
        }
    }
    var use3DOFTrackingFallback = false
    @IBOutlet var sceneView: ARSCNView!
    var screenCenter: CGPoint?
    
    func setupScene() {
        // set up sceneView
        sceneView.delegate = self
        sceneView.session = session
        sceneView.antialiasingMode = .multisampling4X
        sceneView.automaticallyUpdatesLighting = false
        
        sceneView.preferredFramesPerSecond = 60
        sceneView.contentScaleFactor = 1.3
        
        //sceneView.scene.physicsWorld.contactDelegate = (self as! SCNPhysicsContactDelegate)
        enableEnvironmentMapWithIntensity(25.0)
        
        DispatchQueue.main.async {
            self.screenCenter = self.sceneView.bounds.mid
        }
        
        if let camera = sceneView.pointOfView?.camera {
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = true
            camera.exposureOffset = -1
            camera.minimumExposure = -1
        }
    }
    
    func enableEnvironmentMapWithIntensity(_ intensity: CGFloat) {
        if sceneView.scene.lightingEnvironment.contents == nil {
            if let environmentMap = UIImage(named: "Models.scnassets/sharedImages/environment_blur.exr") {
                sceneView.scene.lightingEnvironment.contents = environmentMap
            }
        }
        sceneView.scene.lightingEnvironment.intensity = intensity
    }
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        refreshFeaturePoints()
        DispatchQueue.main.async {
            self.updateFocusSquare()
            self.hitTestVisualization?.render()
            // If light estimation is enabled, update the intensity of the model's lights and the environment map
            if let lightEstimate = self.session.currentFrame?.lightEstimate {
                self.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40)
            } else {
                self.enableEnvironmentMapWithIntensity(25)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.addPlane(node: node, anchor: planeAnchor)
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
                
                self.lastPlaneNode = node
                self.lastPlaneAnchor = planeAnchor
                /*
                 if self.showLoadModel{
                 let subScene = SCNScene(named: "Models.scnassets/test/cube.dae")!
                 let childNodes = subScene.rootNode.childNodes
                 for child in childNodes {
                 child.scale = SCNVector3Make(0.01, 0.01, 0.01);
                 child.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
                 node.addChildNode(child)
                 }
                 }
                 */
                
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.updatePlane(anchor: planeAnchor)
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.removePlane(anchor: planeAnchor)
            }
        }
    }
    
    var trackingFallbackTimer: Timer?
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: !self.showDebugVisuals)
        
        switch camera.trackingState {
        case .notAvailable:
            textManager.escalateFeedback(for: camera.trackingState, inSeconds: 5.0)
        case .limited:
            if use3DOFTrackingFallback {
                // After 10 seconds of limited quality, fall back to 3DOF mode.
                trackingFallbackTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { _ in
                    self.use3DOFTracking = true
                    self.trackingFallbackTimer?.invalidate()
                    self.trackingFallbackTimer = nil
                })
            } else {
                textManager.escalateFeedback(for: camera.trackingState, inSeconds: 10.0)
            }
        case .normal:
            textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
            if use3DOFTrackingFallback && trackingFallbackTimer != nil {
                trackingFallbackTimer!.invalidate()
                trackingFallbackTimer = nil
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        
        guard let arError = error as? ARError else { return }
        
        let nsError = error as NSError
        var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
        if let recoveryOptions = nsError.localizedRecoveryOptions {
            for option in recoveryOptions {
                sessionErrorMsg.append("\(option).")
            }
        }
        
        let isRecoverable = (arError.code == .worldTrackingFailed)
        if isRecoverable {
            sessionErrorMsg += "\nYou can try resetting the session or quit the application."
        } else {
            sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
        }
        
        displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        textManager.blurBackground()
        textManager.showAlert(title: "Session Interrupted", message: "The session will be reset after the interruption has ended.")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        textManager.unblurBackground()
        session.run(sessionConfig, options: [.resetTracking, .removeExistingAnchors])
        restartExperience(self)
        textManager.showMessage("RESETTING SESSION")
    }
    
    // MARK: - Ambient Light Estimation
    
    func toggleAmbientLightEstimation(_ enabled: Bool) {
        
        if enabled {
            if !sessionConfig.isLightEstimationEnabled {
                // turn on light estimation
                sessionConfig.isLightEstimationEnabled = true
                session.run(sessionConfig)
            }
        } else {
            if sessionConfig.isLightEstimationEnabled {
                // turn off light estimation
                sessionConfig.isLightEstimationEnabled = false
                session.run(sessionConfig)
            }
        }
    }
    
    // MARK: - Gesture Recognizers
    
    var currentGesture: Gesture?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let object = virtualObject else {
            return
        }
        
        if currentGesture == nil {
            currentGesture = Gesture.startGestureFromTouches(touches, self.sceneView, object)
        } else {
            currentGesture = currentGesture!.updateGestureFromTouches(touches, .touchBegan)
        }
        
        displayVirtualObjectTransform()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if virtualObject == nil {
            return
        }
        currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchMoved)
        displayVirtualObjectTransform()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if virtualObject == nil {
            chooseObject(addObjectButton)
            return
        }
        
        currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchEnded)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if virtualObject == nil {
            return
        }
        currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchCancelled)
    }
    
    // MARK: - Virtual Object Manipulation
    
    func displayVirtualObjectTransform() {
        
        guard let object = virtualObject, let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        // Output the current translation, rotation & scale of the virtual object as text.
        
        let cameraPos = SCNVector3.positionFromTransform(cameraTransform)
        let vectorToCamera = cameraPos - object.position
        
        let distanceToUser = vectorToCamera.length()
        
        var angleDegrees = Int(((object.eulerAngles.y) * 180) / Float.pi) % 360
        if angleDegrees < 0 {
            angleDegrees += 360
        }
        
        let distance = String(format: "%.2f", distanceToUser)
        let scale = String(format: "%.2f", object.scale.x)
        textManager.showDebugMessage("Distance: \(distance) m\nRotation: \(angleDegrees)°\nScale: \(scale)x")
    }
    
    func moveVirtualObjectToPosition(_ pos: SCNVector3?, _ instantly: Bool, _ filterPosition: Bool) {
        if(canMoveVirtualObject == false){ return}
        guard let newPosition = pos else {
            textManager.showMessage("CANNOT PLACE OBJECT\nTry moving left or right.")
            // Reset the content selection in the menu only if the content has not yet been initially placed.
            if virtualObject == nil {
                resetVirtualObject()
            }
            return
        }
        
        if instantly {
            setNewVirtualObjectPosition(newPosition)
        } else {
            updateVirtualObjectPosition(newPosition, filterPosition)
        }
    }
    
    var dragOnInfinitePlanesEnabled = false
    
    func worldPositionFromScreenPosition(_ position: CGPoint,
                                         objectPos: SCNVector3?,
                                         infinitePlane: Bool = false) -> (position: SCNVector3?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool) {
        
        // -------------------------------------------------------------------------------
        // 1. Always do a hit test against exisiting plane anchors first.
        //    (If any such anchors exist & only within their extents.)
        
        let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
        if let result = planeHitTestResults.first {
            
            let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
            let planeAnchor = result.anchor
            
            // Return immediately - this is the best possible outcome.
            return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
        }
        
        // -------------------------------------------------------------------------------
        // 2. Collect more information about the environment by hit testing against
        //    the feature point cloud, but do not return the result yet.
        
        var featureHitTestPosition: SCNVector3?
        var highQualityFeatureHitTestResult = false
        
        let highQualityfeatureHitTestResults = sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)
        
        if !highQualityfeatureHitTestResults.isEmpty {
            let result = highQualityfeatureHitTestResults[0]
            featureHitTestPosition = result.position
            highQualityFeatureHitTestResult = true
        }
        
        // -------------------------------------------------------------------------------
        // 3. If desired or necessary (no good feature hit test result): Hit test
        //    against an infinite, horizontal plane (ignoring the real world).
        
        if (infinitePlane && dragOnInfinitePlanesEnabled) || !highQualityFeatureHitTestResult {
            
            let pointOnPlane = objectPos ?? SCNVector3Zero
            
            let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
            if pointOnInfinitePlane != nil {
                return (pointOnInfinitePlane, nil, true)
            }
        }
        
        // -------------------------------------------------------------------------------
        // 4. If available, return the result of the hit test against high quality
        //    features if the hit tests against infinite planes were skipped or no
        //    infinite plane was hit.
        
        if highQualityFeatureHitTestResult {
            return (featureHitTestPosition, nil, false)
        }
        
        // -------------------------------------------------------------------------------
        // 5. As a last resort, perform a second, unfiltered hit test against features.
        //    If there are no features in the scene, the result returned here will be nil.
        
        let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
        if !unfilteredFeatureHitTestResults.isEmpty {
            let result = unfilteredFeatureHitTestResults[0]
            return (result.position, nil, false)
        }
        
        return (nil, nil, false)
    }
    
    // Use average of recent virtual object distances to avoid rapid changes in object scale.
    var recentVirtualObjectDistances = [CGFloat]()
    
    func setNewVirtualObjectPosition(_ pos: SCNVector3) {
        
        guard let object = virtualObject, let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        recentVirtualObjectDistances.removeAll()
        
        let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
        var cameraToPosition = pos - cameraWorldPos
        
        // Limit the distance of the object from the camera to a maximum of 10 meters.
        cameraToPosition.setMaximumLength(10)
        
        object.position = cameraWorldPos + cameraToPosition
        
        if object.parent == nil {
            sceneView.scene.rootNode.addChildNode(object)
        }
    }
    
    func resetVirtualObject() {
        virtualObject?.unloadModel()
        virtualObject?.removeFromParentNode()
//        self.sceneView.scene.rootNode.addChildNode(domino!)
        for node in sceneView.scene.rootNode.childNodes{
            node.removeFromParentNode()
        }
//            sceneView.scene.rootNode.removeA
        
        //dominos.removeAll()
        //pyramids.removeAll()
        
        
        virtualObject = nil
        
        addObjectButton.setImage(#imageLiteral(resourceName: "add"), for: [])
        addObjectButton.setImage(#imageLiteral(resourceName: "addPressed"), for: [.highlighted])
        
        // Reset selected object id for row highlighting in object selection view controller.
        UserDefaults.standard.set(-1, for: .selectedObjectID)
    }
    
    func updateVirtualObjectPosition(_ pos: SCNVector3, _ filterPosition: Bool) {
        guard let object = virtualObject else {
            return
        }
        
        guard let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
        var cameraToPosition = pos - cameraWorldPos
        
        // Limit the distance of the object from the camera to a maximum of 10 meters.
        cameraToPosition.setMaximumLength(10)
        
        // Compute the average distance of the object from the camera over the last ten
        // updates. If filterPosition is true, compute a new position for the object
        // with this average. Notice that the distance is applied to the vector from
        // the camera to the content, so it only affects the percieved distance of the
        // object - the averaging does _not_ make the content "lag".
        let hitTestResultDistance = CGFloat(cameraToPosition.length())
        
        recentVirtualObjectDistances.append(hitTestResultDistance)
        recentVirtualObjectDistances.keepLast(10)
        
        if filterPosition {
            let averageDistance = recentVirtualObjectDistances.average!
            
            cameraToPosition.setLength(Float(averageDistance))
            let averagedDistancePos = cameraWorldPos + cameraToPosition
            
            object.position = averagedDistancePos
        } else {
            object.position = cameraWorldPos + cameraToPosition
        }
    }
    
    func checkIfObjectShouldMoveOntoPlane(anchor: ARPlaneAnchor) {
        guard let object = virtualObject, let planeAnchorNode = sceneView.node(for: anchor) else {
            return
        }
        
        // Get the object's position in the plane's coordinate system.
        let objectPos = planeAnchorNode.convertPosition(object.position, from: object.parent)
        
        if objectPos.y == 0 {
            return; // The object is already on the plane - nothing to do here.
        }
        
        // Add 10% tolerance to the corners of the plane.
        let tolerance: Float = 0.1
        
        let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
        let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
        let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
        let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance
        
        if objectPos.x < minX || objectPos.x > maxX || objectPos.z < minZ || objectPos.z > maxZ {
            return
        }
        
        // Drop the object onto the plane if it is near it.
        let verticalAllowance: Float = 0.03
        if objectPos.y > -verticalAllowance && objectPos.y < verticalAllowance {
            textManager.showDebugMessage("OBJECT MOVED\nSurface detected nearby")
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            object.position.y = anchor.transform.columns.3.y
            SCNTransaction.commit()
        }
    }
    
    // MARK: - Virtual Object Loading
    
    var virtualObject: VirtualObject?
    var isLoadingObject: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.settingsButton.isEnabled = !self.isLoadingObject
                self.addObjectButton.isEnabled = !self.isLoadingObject
                self.screenshotButton.isEnabled = !self.isLoadingObject
                self.restartExperienceButton.isEnabled = !self.isLoadingObject
            }
        }
    }
    
    @IBOutlet weak var addObjectButton: UIButton!
    
    func loadVirtualObject(at index: Int) {
        //resetVirtualObject()
        canMoveVirtualObject = true
        InsertPyramid = false
        InsertDomino = false
        InsertWolf = false
        InsertPlant = false
        InsertMushroom = false
        InsertMeat = false
        
        // Show progress indicator
        let spinner = UIActivityIndicatorView()
        spinner.center = addObjectButton.center
        spinner.bounds.size = CGSize(width: addObjectButton.bounds.width - 5, height: addObjectButton.bounds.height - 5)
        addObjectButton.setImage(#imageLiteral(resourceName: "buttonring"), for: [])
        sceneView.addSubview(spinner)
        spinner.startAnimating()
        
        // Load the content asynchronously.
        DispatchQueue.global().async {
            self.isLoadingObject = true
            let object = VirtualObject.availableObjects[index]
            object.viewController = self
            self.virtualObject = object
            
            object.loadModel()
            
            DispatchQueue.main.async {
                // Immediately place the object in 3D space.
                if let lastFocusSquarePos = self.focusSquare?.lastPosition {
                    self.setNewVirtualObjectPosition(lastFocusSquarePos)
                } else {
                    self.setNewVirtualObjectPosition(SCNVector3Zero)
                }
                
                // Remove progress indicator
                spinner.removeFromSuperview()
                
                // Update the icon of the add object button
                let buttonImage = UIImage.composeButtonImage(from: object.thumbImage)
                let pressedButtonImage = UIImage.composeButtonImage(from: object.thumbImage, alpha: 0.3)
                self.addObjectButton.setImage(buttonImage, for: [])
                self.addObjectButton.setImage(pressedButtonImage, for: [.highlighted])
                self.isLoadingObject = false
            }
        }
    }
    
    @IBAction func chooseObject(_ button: UIButton) {
        // Abort if we are about to load another object to avoid concurrent modifications of the scene.
        if isLoadingObject { return }
        
        textManager.cancelScheduledMessage(forType: .contentPlacement)
        
        let rowHeight = 45
        let popoverSize = CGSize(width: 250, height: rowHeight * VirtualObject.availableObjects.count)
        
        let objectViewController = VirtualObjectSelectionViewController(size: popoverSize)
        objectViewController.delegate = self
        objectViewController.modalPresentationStyle = .popover
        objectViewController.popoverPresentationController?.delegate = self
        self.present(objectViewController, animated: true, completion: nil)
        
        objectViewController.popoverPresentationController?.sourceView = button
        objectViewController.popoverPresentationController?.sourceRect = button.bounds
    }
    
    // MARK: - VirtualObjectSelectionViewControllerDelegate
    
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, didSelectObjectAt index: Int) {
        loadVirtualObject(at: index)
    }
    
    func virtualObjectSelectionViewControllerDidDeselectObject(_: VirtualObjectSelectionViewController) {
    }
    
    // MARK: - Planes
    
    var planes = [ARPlaneAnchor: Plane]()
    
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        
        let pos = SCNVector3.positionFromTransform(anchor.transform)
        textManager.showDebugMessage("NEW SURFACE DETECTED AT \(pos.friendlyString())")
        
        let plane = Plane.init(anchor: anchor, isHidden: showDebugVisuals, with: Plane.currentMaterial() )
        
        planes[anchor] = plane
        node.addChildNode(plane!)
        textManager.cancelScheduledMessage(forType: .planeEstimation)
        textManager.showMessage("SURFACE DETECTED")
        if virtualObject == nil {
            textManager.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .contentPlacement)
        }
    }
    
    func updatePlane(anchor: ARPlaneAnchor) {
        if let plane = planes[anchor] {
            plane.update(anchor)
        }
    }
    
    func removePlane(anchor: ARPlaneAnchor) {
        if let plane = planes.removeValue(forKey: anchor) {
            plane.removeFromParentNode()
        }
    }
    
    func restartPlaneDetection() {
        
        // configure session
        if let worldSessionConfig = sessionConfig as? ARWorldTrackingSessionConfiguration {
            worldSessionConfig.planeDetection = .horizontal
            session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        }
        
        // reset timer
        if trackingFallbackTimer != nil {
            trackingFallbackTimer!.invalidate()
            trackingFallbackTimer = nil
        }
        
        textManager.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT",
                                    inSeconds: 7.5,
                                    messageType: .planeEstimation)
    }
    
    // MARK: - Focus Square
    var focusSquare: FocusSquare?
    
    func setupFocusSquare() {
        focusSquare?.isHidden = true
        focusSquare?.removeFromParentNode()
        focusSquare = FocusSquare()
        sceneView.scene.rootNode.addChildNode(focusSquare!)
        
        textManager.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, messageType: .focusSquare)
    }
    
    func updateFocusSquare() {
        guard let screenCenter = screenCenter else { return }
        
        if virtualObject != nil && sceneView.isNode(virtualObject!, insideFrustumOf: sceneView.pointOfView!) {
            focusSquare?.hide()
        } else {
            focusSquare?.unhide()
        }
        let (worldPos, planeAnchor, _) = worldPositionFromScreenPosition(screenCenter, objectPos: focusSquare?.position)
        if let worldPos = worldPos {
            focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
            textManager.cancelScheduledMessage(forType: .focusSquare)
        }
    }
    
    // MARK: - Hit Test Visualization
    
    var hitTestVisualization: HitTestVisualization?
    
    var showHitTestAPIVisualization = UserDefaults.standard.bool(for: .showHitTestAPI) {
        didSet {
            UserDefaults.standard.set(showHitTestAPIVisualization, for: .showHitTestAPI)
            if showHitTestAPIVisualization {
                hitTestVisualization = HitTestVisualization(sceneView: sceneView)
            } else {
                hitTestVisualization = nil
            }
        }
    }
    
    // MARK: - Debug Visualizations
    
    @IBOutlet var featurePointCountLabel: UILabel!
    
    func refreshFeaturePoints() {
        guard showDebugVisuals else {
            return
        }
        
        // retrieve cloud
        guard let cloud = session.currentFrame?.rawFeaturePoints else {
            return
        }
        
        DispatchQueue.main.async {
            self.featurePointCountLabel.text = "Features: \(cloud.count)".uppercased()
        }
    }
    
    var showDebugVisuals: Bool = UserDefaults.standard.bool(for: .debugMode) {
        didSet {
            featurePointCountLabel.isHidden = !showDebugVisuals
            debugMessageLabel.isHidden = !showDebugVisuals
            messagePanel.isHidden = !showDebugVisuals
            //planes.values.forEach { $0.showDebugVisualization(showDebugVisuals) }
            
            if showDebugVisuals {
                sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
            } else {
                sceneView.debugOptions = []
            }
            
            // save pref
            UserDefaults.standard.set(showDebugVisuals, for: .debugMode)
        }
    }
    
    func setupDebug() {
        // Set appearance of debug output panel
        messagePanel.layer.cornerRadius = 3.0
        messagePanel.clipsToBounds = true
    }
    
    // MARK: - UI Elements and Actions
    
    @IBOutlet weak var messagePanel: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var debugMessageLabel: UILabel!
    
    var textManager: TextManager!
    
    func setupUIControls() {
        textManager = TextManager(viewController: self)
        
        // hide debug message view
        debugMessageLabel.isHidden = true
        
        featurePointCountLabel.text = ""
        debugMessageLabel.text = ""
        messageLabel.text = ""
    }
    
    @IBOutlet weak var restartExperienceButton: UIButton!
    var restartExperienceButtonIsEnabled = true
    
    @IBAction func restartExperience(_ sender: Any) {
        
        guard restartExperienceButtonIsEnabled, !isLoadingObject else {
            return
        }
        DispatchQueue.main.async {
            self.restartExperienceButtonIsEnabled = false
            
            self.textManager.cancelAllScheduledMessages()
            self.textManager.dismissPresentedAlert()
            self.textManager.showMessage("STARTING A NEW SESSION")
            self.use3DOFTracking = false
            
            self.setupFocusSquare()
            self.resetVirtualObject()
            self.restartPlaneDetection()
            
            self.restartExperienceButton.setImage(#imageLiteral(resourceName: "restart"), for: [])
            
            self.MusicTreeNode.stop()
            
            // Disable Restart button for five seconds in order to give the session enough time to restart.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                self.restartExperienceButtonIsEnabled = true
            })
        }
    }
    
    @IBOutlet weak var screenshotButton: UIButton!
    
    @IBAction func takeScreenshot() {
        guard screenshotButton.isEnabled else {
            return
        }
        
        let takeScreenshotBlock = {
            
            UIImageWriteToSavedPhotosAlbum(self.sceneView.snapshot(), nil, nil, nil)
            DispatchQueue.main.async {
                // Briefly flash the screen.
                let flashOverlay = UIView(frame: self.sceneView.frame)
                flashOverlay.backgroundColor = UIColor.white
                self.sceneView.addSubview(flashOverlay)
                UIView.animate(withDuration: 0.25, animations: {
                    flashOverlay.alpha = 0.0
                }, completion: { _ in
                    flashOverlay.removeFromSuperview()
                })
            }
        }
        
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            takeScreenshotBlock()
        case .restricted, .denied:
            let title = "Photos access denied"
            let message = "Please enable Photos access for this application in Settings > Privacy to allow saving screenshots."
            textManager.showAlert(title: title, message: message)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (authorizationStatus) in
                if authorizationStatus == .authorized {
                    takeScreenshotBlock()
                }
            })
        }
    }
    
    // MARK: - Recording
    
    @IBOutlet weak var CameraHitArea: UIButton!
    var recordTimer:Timer!
    var recordImageList: [UIImage] = []
    
    var isRecordStart: Bool = false;
    
    func ScreenLongPress(recognizer:UILongPressGestureRecognizer) {
        
        print(recognizer)
        
        let p = recognizer.location(in: self.sceneView)
        let view = self.sceneView.frame
        if recognizer.state == .began && p.x < 64 && p.y > view.height-64{
            startRecording()
        }
        
    }
    
    func startRecording() {
        
        let takeReaordingBlock = {
            UIImageWriteToSavedPhotosAlbum(self.sceneView.snapshot(), nil, nil, nil)
            
        }
        
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            if isRecordStart{
                recordTimer.invalidate()
                imageListToVideo()
                isRecordStart = false
                self.screenshotButton.setImage(#imageLiteral(resourceName: "shutter"), for: [])
            }
            else{
                recordTimer = Timer.scheduledTimer(timeInterval: 0.05,target:self,selector:#selector(ViewController.addUIimageIntoList),userInfo:nil,repeats:true)
                isRecordStart = true
                self.screenshotButton.setImage(#imageLiteral(resourceName: "shutterRecord"), for: [])
            }
            takeReaordingBlock()
        case .restricted, .denied:
            let title = "Photos access denied"
            let message = "Please enable Photos access for this application in Settings > Privacy to allow saving screenshots."
            textManager.showAlert(title: title, message: message)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (authorizationStatus) in
                if authorizationStatus == .authorized {
                    takeReaordingBlock()
                }
            })
        }
    }
    
    func addUIimageIntoList(){
        var img: UIImage = self.sceneView.snapshot()
        img = resizeImage(image: img,newWidth: 720)!
        recordImageList.append(img)
    }
    
    func resizeImage(image: UIImage, newWidth: CGFloat) -> UIImage? {
        
        let scale = newWidth / image.size.width
        let newHeight = image.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func imageListToVideo(){
        
        let settings = RenderSettings()
        let imageAnimator = ImageAnimator(renderSettings: settings, recordImageList: recordImageList)
        imageAnimator.render() {
            let alertView = UIAlertController(title: "螢幕錄影", message: "已成功輸出AR影像到\"照片\"", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default, handler: { (alert) in
                
            })
            alertView.addAction(action)
            self.present(alertView, animated: true, completion: nil)
            
        }
    }
    
    // MARK: - Nature
    
    @IBOutlet weak var NatureView: UIStackView!
    @IBAction func showNature(_ sender: Any) {
        NatureView.isHidden = !NatureView.isHidden;
    }
    
    
    // MARK: - Fantacy
    
    @IBOutlet weak var FantacyView: UIStackView!
    @IBAction func showFantacy(_ button: UIButton) {
        FantacyView.isHidden = !FantacyView.isHidden;
    }
    
    func setupTable(){
        
        FantacyView.subviews.forEach{ fantacyButton in
            fantacyButton.layer.addBorder(edge: UIRectEdge.bottom, color: UIColor.black, thickness: 0.5)
        }
        
        NatureView.subviews.forEach{ natureButton in
            natureButton.layer.addBorder(edge: UIRectEdge.bottom, color: UIColor.black, thickness: 0.5)
        }
    }
    
    
    
    
    
    // MARK: - Settings
    
    @IBOutlet weak var settingsButton: UIButton!
    
    @IBAction func showSettings(_ button: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let settingsViewController = storyboard.instantiateViewController(withIdentifier: "settingsViewController") as? SettingsViewController else {
            return
        }
        
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSettings))
        settingsViewController.navigationItem.rightBarButtonItem = barButtonItem
        settingsViewController.title = "Options"
        
        let navigationController = UINavigationController(rootViewController: settingsViewController)
        navigationController.modalPresentationStyle = .popover
        navigationController.popoverPresentationController?.delegate = self
        navigationController.preferredContentSize = CGSize(width: sceneView.bounds.size.width - 20, height: sceneView.bounds.size.height - 50)
        self.present(navigationController, animated: true, completion: nil)
        
        navigationController.popoverPresentationController?.sourceView = settingsButton
        navigationController.popoverPresentationController?.sourceRect = settingsButton.bounds
    }
    
    @objc
    func dismissSettings() {
        self.dismiss(animated: true, completion: nil)
        updateSettings()
    }
    
    private func updateSettings() {
        let defaults = UserDefaults.standard
        
        showDebugVisuals = defaults.bool(for: .debugMode)
        toggleAmbientLightEstimation(defaults.bool(for: .ambientLightEstimation))
        dragOnInfinitePlanesEnabled = defaults.bool(for: .dragOnInfinitePlanes)
        showHitTestAPIVisualization = defaults.bool(for: .showHitTestAPI)
        use3DOFTracking    = defaults.bool(for: .use3DOFTracking)
        use3DOFTrackingFallback = defaults.bool(for: .use3DOFFallback)
        for (_, plane) in planes {
            //    plane.updateOcclusionSetting()
        }
    }
    
    // MARK: - Error handling
    
    func displayErrorMessage(title: String, message: String, allowRestart: Bool = false) {
        // Blur the background.
        textManager.blurBackground()
        
        if allowRestart {
            // Present an alert informing about the error that has occurred.
            let restartAction = UIAlertAction(title: "Reset", style: .default) { _ in
                self.textManager.unblurBackground()
                self.restartExperience(self)
            }
            textManager.showAlert(title: title, message: message, actions: [restartAction])
        } else {
            textManager.showAlert(title: title, message: message, actions: [])
        }
    }
    
    // MARK: - UIPopoverPresentationControllerDelegate
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        updateSettings()
    }
    
    //  --------------Balloon Shooting--------------
    
    @IBOutlet weak var BalloonShootingBtn: UIButton!
    @IBAction func clickBalloonShootingBtn(_ sender: Any) {
        canMoveVirtualObject = false
        FantacyView.isHidden = true
        self.addNewBalloon()
    }
    
    
    @IBAction func clickShootingBtn(_ sender: Any) {
        // fire bullet
        canMoveVirtualObject = false
        let bulletsNode = Bullet()
        
        let (direction, position) = self.getUserVector()
        bulletsNode.position = position // SceneKit/AR coordinates are in meters
        bulletsNode.physicsBody?.applyForce(direction, asImpulse: true)
        sceneView.scene.rootNode.addChildNode(bulletsNode)
    }
    
    
    func getUserVector() -> (SCNVector3, SCNVector3) { // (direction, position)
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4FromMat4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            
            return (dir, pos)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
    
    func addNewBalloon() {
        if let anchor = self.lastPlaneAnchor, let node = self.lastPlaneNode {
            
            let xoffset = floatBetween(-0.1, and: 0.1)
            let yoffset = floatBetween(-0.1, and: 0.1)
            let cubeNode = Balloon()
            cubeNode.position = SCNVector3(anchor.center.x+xoffset, 0.03, anchor.center.z+yoffset)
            node.addChildNode(cubeNode)
            
        }
        else{
            let alertView = UIAlertController(title: "妝世", message: "請多搖晃，先找到平面", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default, handler: { (alert) in
            })
            alertView.addAction(action)
            
            self.present(alertView, animated: true, completion: nil)
        }
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        //爆炸寫在這裡
        contact.nodeA.removeFromParentNode()
        contact.nodeB.removeFromParentNode()
        print("Hit Balloon!")
        
    }
    
    func floatBetween(_ first: Float,  and second: Float) -> Float {
        return (Float(arc4random()) / Float(UInt32.max)) * (first - second) + second
    }
    
    //  -------------- Load Model --------------
    
    
    
    
    //  -------------- Music Tree --------------
    
    
    var showMusicTree: Bool = false
    var MusicTreeNode: MusicTree = MusicTree()
    var lastPlaneNode: SCNNode?
    var lastPlaneAnchor: ARPlaneAnchor?
    
    @IBOutlet weak var musicTreeButton: UIButton!
    
    @IBAction func clickMusicTreeButton(_ sender: Any) {
        canMoveVirtualObject = false
        FantacyView.isHidden = true
        guard musicTreeButton.isEnabled else {
            return
        }
        
        DispatchQueue.main.async {
            // Immediately place the object in 3D space.
            
            if let anchor = self.lastPlaneAnchor, let node = self.lastPlaneNode {
                
                self.MusicTreeNode.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)
                node.addChildNode(self.MusicTreeNode)
                
                if self.showMusicTree {
                    self.MusicTreeNode.stop()
                    self.showMusicTree = false
                }
                else{
                    self.MusicTreeNode.play()
                    self.showMusicTree = true
                }
                
            }
            else{
                
                let alertView = UIAlertController(title: "妝世", message: "請多搖晃，先找到平面", preferredStyle: .alert)
                let action = UIAlertAction(title: "OK", style: .default, handler: { (alert) in
                })
                alertView.addAction(action)
                self.present(alertView, animated: true, completion: nil)
                
            }
            
        }
        
    }
    
    func longPressMusictreePlane(recognizer:UILongPressGestureRecognizer) {
        print("LongPress Plane")
    }
    
    /////Pyramid dropping/////
    
    
    var pyramids = [Pyramid]()
    func insertPyramid( hitResult :ARHitTestResult ){
        
        let insertionYOffset:Float  = 0.3; // the height of pyramid input
        let position : SCNVector3 = SCNVector3Make(
            hitResult.worldTransform.columns.3.x ,
            hitResult.worldTransform.columns.3.y + insertionYOffset,
            hitResult.worldTransform.columns.3.z )
        let pyramid = Pyramid.init(atPosition: position, with: Pyramid.currentMaterial())
        pyramids.append( pyramid!) //record pyramids
        self.sceneView.scene.rootNode.addChildNode(pyramid!)
    }
    
    func InsertPyramidFrom(_ recognizer: UITapGestureRecognizer) {
        print("Tap Screen!")
        let tapPoint:CGPoint = recognizer.location(in: recognizer.view)
        let result  = self.sceneView.hitTest(tapPoint, types:.existingPlaneUsingExtent)
        if result.count == 0{//the point has no planes
            return
        }
        
        let first :ARHitTestResult = result.first!
        self.insertPyramid(hitResult: first)
        
    }
    
    
    
    //remove if the pyramid on the bottom
    
    /////////Domino//////////
    var dominos = [Domino]()
    func insertDomino( hitResult :ARHitTestResult ){
        let insertionYOffset:Float  = 0;
        
        let position : SCNVector3 = SCNVector3Make(
            hitResult.worldTransform.columns.3.x ,
            hitResult.worldTransform.columns.3.y + insertionYOffset,
            hitResult.worldTransform.columns.3.z )
        let domino = Domino.init(atPosition: position, with: Domino.currentMaterial())
        dominos.append( domino!) //record dominos
        self.sceneView.scene.rootNode.addChildNode(domino!)
        
    }
    
    func InsertDominoFrom(_ recognizer: UITapGestureRecognizer) {
        let tapPoint:CGPoint = recognizer.location(in: recognizer.view)
        let result  = self.sceneView.hitTest(tapPoint, types:.existingPlaneUsingExtent)
        if result.count == 0{//the point has no planes
            return
        }
        
        let first :ARHitTestResult = result.first!
        self.insertDomino(hitResult: first)
        
    }
    
    
    
    //a force to push domino
    func PushDomino(_ recognizer: UILongPressGestureRecognizer ){
        let tapPoint:CGPoint = recognizer.location(in: recognizer.view)
        let result  = self.sceneView.hitTest(tapPoint, options: nil)//find which domino
        for thing in result {
            let type:SCNNode = thing.node.parent!
            
            if( type.isMember(of: Domino.self) ) {
                let (direction, _) = self.getUserVector()
                thing.node.physicsBody?.applyForce(direction*2, asImpulse: true)
                return
            }
        }
        
    }
    ////////////////////////////
    
    //////Gesture//////
    
    var InsertPyramid = false
    var InsertDomino = false
    var InsertWolf = false
    var InsertPlant = false
    var InsertMushroom = false
    var InsertMeat = false
    var canMoveVirtualObject = true
    
    @IBAction func PyramidMode(_ sender: Any) {
        InsertPyramid = true
        InsertDomino = false
        InsertWolf = false
        InsertPlant = false
        InsertMushroom = false
        InsertMeat = false
        canMoveVirtualObject = false
    }
    
    @IBAction func DominoMode(_ sender: Any) {
        InsertPyramid = false
        InsertDomino = true
        InsertWolf = false
        InsertPlant = false
        InsertMushroom = false
        InsertMeat = false
        canMoveVirtualObject = false
    }
    
    @IBOutlet weak var guideImage: UIImageView!
    @IBOutlet weak var guideLabel: UILabel!
    
    
    
    func InsertObject(_ recognizer: UITapGestureRecognizer) {
        
        let tapPoint:CGPoint = recognizer.location(in: recognizer.view)
        let result  = self.sceneView.hitTest(tapPoint, types:.existingPlaneUsingExtent)
        if result.count == 0{//the point has no planes
            guideImage.isHidden = false
            guideLabel.isHidden = false
            return
        }
        guideImage.isHidden = true
        guideLabel.isHidden = true
        if (InsertPyramid) {
            self.InsertPyramidFrom(recognizer)
        }
        if (InsertDomino) {
            self.InsertDominoFrom(recognizer)
        }
        if(InsertWolf){
            self.InsertNatureModel(recognizer)
        }
        if(InsertPlant){
            self.InsertNatureModel(recognizer)
        }
        if(InsertMushroom){
            self.InsertNatureModel(recognizer)
        }
        if(InsertMeat){
            self.InsertNatureModel(recognizer)
        }
        
    }
    
    func setupGesture(){
        //Insert Object
        let tapInsert = UITapGestureRecognizer(target:self,action: #selector(self.InsertObject(_:) ))
        tapInsert.numberOfTapsRequired = 1
        self.sceneView.addGestureRecognizer(tapInsert)
        
        //PushDomino
        let pushDomino = UILongPressGestureRecognizer(target:self,action: #selector(self.PushDomino(_:) ))
        pushDomino.minimumPressDuration = 0.5
        self.sceneView.addGestureRecognizer(pushDomino)
        
        
        //Camera record
        let longPressCamera = UILongPressGestureRecognizer(
            target: self,
            action: #selector(ViewController.ScreenLongPress(recognizer:))
        )
        longPressCamera.minimumPressDuration = 1
        self.view.addGestureRecognizer(longPressCamera)
        
        //Change texture
        let changeTexture = UILongPressGestureRecognizer(target:self,action: #selector(self.ChangeTexture(_:) ))
        changeTexture.numberOfTouchesRequired=2
        changeTexture.minimumPressDuration = 0.5
        self.view.addGestureRecognizer(changeTexture)
    }
    
    func ChangeTexture(_ recognizer: UITapGestureRecognizer) {
        print("texture")
        if (recognizer.state != UIGestureRecognizerState.began){ return }
        let tapPoint:CGPoint = recognizer.location(in: recognizer.view)
        let resultArray  = self.sceneView.hitTest(tapPoint, options: nil)
        if resultArray.count == 0{ return}//
        let result = resultArray.first
        let node:SCNNode = result!.node;
        let parentNode:SCNNode = node.parent!
        if( parentNode.isKind(of: Domino.self)) {
            var c = parentNode as! Domino
            print("domino texture change")
            c.changeMaterial()
        }
        else if( parentNode.isKind(of: Pyramid.self)) {
            var c = parentNode as! Pyramid
            print("Pyramid texture change")
            c.changeMaterial()
        }
        else if( parentNode.isKind(of: Plane.self)) {
            var c = parentNode as! Plane
            print("Plane texture change")
            c.changeMaterial()
        }
    }
    
    //////////////////////////
    
    //////load 3D nature models////////
    var indexOf3DModels:Int = 0
    var Name = ["Models.scnassets/Nature3D/wolf/wolf.dae",
                "Models.scnassets/Nature3D/plant/Rigged_Indoor_Plant_IK.dae",
                "Models.scnassets/Nature3D/mushroom/boletus.dae",
                "Models.scnassets/Nature3D/raw meat/Raw_meat.dae"]
    var nodeName = ["wolf","Armature","Cylinder01","Raw_meat"]
    @IBAction func Wolf(_ sender: Any) {
        indexOf3DModels = 0
        InsertPyramid = false
        InsertDomino = false
        InsertWolf = true
        InsertPlant = false
        InsertMushroom = false
        InsertMeat = false
        canMoveVirtualObject = false
    }
    @IBAction func plant(_ sender: Any) {
        indexOf3DModels = 1
        InsertPyramid = false
        InsertDomino = false
        InsertWolf = false
        InsertPlant = true
        InsertMushroom = false
        InsertMeat = false
        canMoveVirtualObject = false
    }
    
    @IBAction func Mushroom(_ sender: Any) {
        indexOf3DModels = 2
        InsertPyramid = false
        InsertDomino = false
        InsertWolf = false
        InsertPlant = false
        InsertMushroom = true
        InsertMeat = false
        canMoveVirtualObject = false
    }
    
    @IBAction func Meat(_ sender: Any) {
        indexOf3DModels = 3
        InsertPyramid = false
        InsertDomino = false
        InsertWolf = false
        InsertPlant = false
        InsertMushroom = false
        InsertMeat = true
        canMoveVirtualObject = false
    }
    
    var natureNode: SCNNode!
    func InsertNatureModel(_ recognizer: UITapGestureRecognizer){
        let tapPoint:CGPoint = recognizer.location(in: recognizer.view)
        let result  = self.sceneView.hitTest(tapPoint, types:.existingPlaneUsingExtent)
        if result.count == 0{//the point has no planes
            return
        }
        print("insert Nature3D")
        let first :ARHitTestResult = result.first!
        let position : SCNVector3 = SCNVector3Make(
            first.worldTransform.columns.3.x ,
            first.worldTransform.columns.3.y + 0.05,
            first.worldTransform.columns.3.z )
        
        if let natureFrom = SCNScene(named: Name[indexOf3DModels]) {
            if let natureNode = natureFrom.rootNode.childNode(withName: nodeName[indexOf3DModels], recursively: true){
                natureNode.position = position
                //                natureNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                //                natureNode.physicsBody?.mass = 6
                if(InsertWolf){
                    natureNode.scale = SCNVector3Make(1.2, 1.2,1.2)
                }
                if(InsertMushroom){
                    natureNode.scale = SCNVector3Make(0.003, 0.003,0.003)
                }
                sceneView.scene.rootNode.addChildNode(natureNode)
            }
            else {print("can't find name")}
        }
        
    }
    
}

struct CollisionCategory: OptionSet {
    let rawValue: Int
    
    static let bullets  = CollisionCategory(rawValue: 1 << 0) // 00...01
    static let balloon = CollisionCategory(rawValue: 1 << 1) // 00..10
}



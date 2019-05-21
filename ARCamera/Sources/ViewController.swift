//
//  ViewController.swift
//
//  Copyright (c) 2018-present patrick piemonte (http://patrickpiemonte.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit
import SceneKit
import SceneKit.ModelIO
import Photos
import VideoToolbox
import ARKit
import NextLevel

public class ViewController: UIViewController {

    // MARK: - properties
    
    // MARK: - ivars
    
    internal lazy var _arView: ARSCNView = {
        let arView = ARSCNView(frame: CGRect.zero, options: nil)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.isPlaying = true
        arView.loops = true
        arView.scene = SCNScene()
        arView.backgroundColor = UIColor.black
        arView.autoenablesDefaultLighting = true
        arView.automaticallyUpdatesLighting = true
        return arView
    }()
    internal var _arConfig: ARConfiguration?
    internal var _nextLevel: NextLevel?
    internal var _bufferRenderer: NextLevelBufferRenderer?

    internal var _recordButton: RecordButton = {
        let button = RecordButton(frame: CGRect(origin: .zero, size: CGSize(width: 75, height: 75)))
        return button
    }()
    internal lazy var _videoLongPressGestureRecognizer: UILongPressGestureRecognizer = {
        let videoLongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleVideoLongPressGestureRecognizer(_:)))
        videoLongPressGestureRecognizer.minimumPressDuration = 0.2
        videoLongPressGestureRecognizer.numberOfTouchesRequired = 1
        videoLongPressGestureRecognizer.allowableMovement = 10.0
        return videoLongPressGestureRecognizer
    }()
    internal var _tapGestureRecognizer: UITapGestureRecognizer?

    internal var _exampleNode: SCNNode?
    
    // MARK: - object lifecycle
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("not supported")
    }
    
    // MARK: - view lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.black
        self.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // preview
        self._arView.frame = self.view.bounds
        self._arView.delegate = self
        self._arView.session.delegate = self
        
        // setup video out rendering
        self._bufferRenderer = NextLevelBufferRenderer(view: self._arView)
        
        self.view.addSubview(self._arView)

        self.setupScene()
        self.setupCamera()

        // gestures
        self._tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGestureRecognizer(_ :)))
        if let tapGestureRecognizer = self._tapGestureRecognizer {
            tapGestureRecognizer.numberOfTapsRequired = 1
            //self._arView.addGestureRecognizer(tapGestureRecognizer)
        }

        var safeAreaBottom: CGFloat = 0.0
        safeAreaBottom = self.view.safeAreaInsets.bottom + 5.0
        self._recordButton.center = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.size.height - safeAreaBottom - (self._recordButton.frame.size.height * 0.5) - 50.0)
        self._recordButton.addGestureRecognizer(self._videoLongPressGestureRecognizer)
        self.view.addSubview(self._recordButton)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.startCamera()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.stopCamera()
    }

}

// MARK: - setup

extension ViewController {
    
    internal func setupCamera() {
        // setup physical camera, NextLevel
        self._nextLevel = NextLevel()
        if let nextLevel = self._nextLevel {
            nextLevel.previewLayer.frame = self._arView.frame
            
            nextLevel.delegate = self
            nextLevel.videoDelegate = self
            
            nextLevel.captureMode = .arKit
            nextLevel.isVideoCustomContextRenderingEnabled = true
            nextLevel.videoStabilizationMode = .off
            nextLevel.frameRate = 60
            
            // video configuration
            nextLevel.videoConfiguration.maximumCaptureDuration = CMTime(seconds: 12.0, preferredTimescale: 1)
            nextLevel.videoConfiguration.bitRate = 15000000
            nextLevel.videoConfiguration.maxKeyFrameInterval = 30
            nextLevel.videoConfiguration.scalingMode = AVVideoScalingModeResizeAspectFill
            nextLevel.videoConfiguration.codec = AVVideoCodecType.hevc
            nextLevel.videoConfiguration.profileLevel = String(kVTProfileLevel_HEVC_Main_AutoLevel)

            // audio configuration
            nextLevel.audioConfiguration.bitRate = 96000
        }
    }
    
    internal func setupScene() {
        guard let url = Bundle.main.url(forResource: "piemonte", withExtension: "usdz") else {
            fatalError("couldn't load 3D model example")
        }
        let mdlAsset = MDLAsset(url: url)
        mdlAsset.loadTextures()
        let scene = SCNScene(mdlAsset: mdlAsset)
        
        self._exampleNode = scene.rootNode
        if let exampleNode = self._exampleNode {
            exampleNode.simdScale = float3(0.05, 0.05, 0.05)
            self._arView.scene.rootNode.addChildNode(exampleNode)
        }
    }
}

// MARK: - tracking

extension ViewController {
    
    internal func startCamera() {
        if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized &&
            NextLevel.authorizationStatus(forMediaType: AVMediaType.audio) == .authorized {
            
            self._arView.isHidden = false
            
            // setup tracking
            let arConfig = ARWorldTrackingConfiguration()
            arConfig.worldAlignment = .gravity
            arConfig.providesAudioData = true
            arConfig.isLightEstimationEnabled = true
            arConfig.planeDetection = [.horizontal]
            arConfig.isAutoFocusEnabled = true
            //arConfig.environmentTexturing = .automatic
            
            self._nextLevel?.arConfiguration?.config = arConfig
            self._nextLevel?.arConfiguration?.session = self._arView.session
            self._nextLevel?.arConfiguration?.runOptions = [.resetTracking, .removeExistingAnchors]
            
            // run session
            do {
                try self._nextLevel?.start()
            } catch let error {
                print("failed to start camera \(error)")
            }
        } else {
            NextLevel.requestAuthorization(forMediaType: .video) { (mediaType, status) in
                print("NextLevel, authorization updated for media \(mediaType) status \(status)")
                if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized &&
                    NextLevel.authorizationStatus(forMediaType: AVMediaType.audio) == .authorized {
                    self.startCamera()
                }
            }
            
            NextLevel.requestAuthorization(forMediaType: AVMediaType.audio) { (mediaType, status) in
                print("NextLevel, authorization updated for media \(mediaType) status \(status)")
                if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized &&
                    NextLevel.authorizationStatus(forMediaType: AVMediaType.audio) == .authorized {
                    self.startCamera()
                }
            }
        }
    }
    
    internal func stopCamera() {
        // pause session
        self._nextLevel?.stop()
        self._arView.isHidden = true
    }
    
}

// MARK: - capture

extension ViewController {
    
    internal func startCapture() {
        self._nextLevel?.record()
    }
    
    
    internal func resetCapture() {
        self._recordButton.reset()
        self._nextLevel?.session?.removeAllClips()
    }
    
    internal func endCapture() {
        if let session = self._nextLevel?.session {
    
            if session.clips.count > 1 {
                session.mergeClips(usingPreset: AVAssetExportPresetHighestQuality, completionHandler: { (url: URL?, error: Error?) in
                    if let url = url {
                        self.saveVideo(withURL: url)
                    } else if let _ = error {
                        print("failed to merge clips at the end of capture \(String(describing: error))")
                    }
                })
            } else if let lastClipUrl = session.lastClipUrl {
                self.saveVideo(withURL: lastClipUrl)
            } else if session.currentClipHasStarted {
                session.endClip(completionHandler: { (clip, error) in
                    if error == nil {
                        self.saveVideo(withURL: (clip?.url)!)
                    } else {
                        print("Error saving video: \(error?.localizedDescription ?? "")")
                    }
                })
            } else {
                // prompt that the video has been saved
                let alertController = UIAlertController(title: "Video Failed", message: "Not enough video captured!", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
            }
            
        }
    }
}

// MARK: - media utilities

extension ViewController {
    
    internal func albumAssetCollection(withTitle title: String) -> PHAssetCollection? {
        let predicate = NSPredicate(format: "localizedTitle = %@", title)
        let options = PHFetchOptions()
        options.predicate = predicate
        let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        if result.count > 0 {
            return result.firstObject
        }
        return nil
    }
    
    internal func saveVideo(withURL url: URL) {
        let NextLevelAlbumTitle = "NextLevel"
        
        PHPhotoLibrary.shared().performChanges({
            let albumAssetCollection = self.albumAssetCollection(withTitle: NextLevelAlbumTitle)
            if albumAssetCollection == nil {
                let changeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: NextLevelAlbumTitle)
                let _ = changeRequest.placeholderForCreatedAssetCollection
            }}, completionHandler: { (success1: Bool, error1: Error?) in
                if let albumAssetCollection = self.albumAssetCollection(withTitle: NextLevelAlbumTitle) {
                    PHPhotoLibrary.shared().performChanges({
                        if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) {
                            let assetCollectionChangeRequest = PHAssetCollectionChangeRequest(for: albumAssetCollection)
                            let enumeration: NSArray = [assetChangeRequest.placeholderForCreatedAsset!]
                            assetCollectionChangeRequest?.addAssets(enumeration)
                        }
                    }, completionHandler: { (success2: Bool, error2: Error?) in
                        if success2 == true {
                            // prompt that the video has been saved
                            let alertController = UIAlertController(title: "Video Saved!", message: "Saved to the camera roll.", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default) { (action) in
                                DispatchQueue.main.async {
                                    self.resetCapture()
                                }
                            }
                            alertController.addAction(okAction)
                            self.present(alertController, animated: true, completion: nil)
                        } else {
                            // prompt that the video has been saved
                            let alertController = UIAlertController(title: "Oops!", message: "Something failed!", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                            alertController.addAction(okAction)
                            self.present(alertController, animated: true, completion: nil)
                        }
                    })
                }
        })
    }
    
    internal func savePhoto(photoImage: UIImage) {
        let NextLevelAlbumTitle = "NextLevel"
        
        PHPhotoLibrary.shared().performChanges({
            
            let albumAssetCollection = self.albumAssetCollection(withTitle: NextLevelAlbumTitle)
            if albumAssetCollection == nil {
                let changeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: NextLevelAlbumTitle)
                let _ = changeRequest.placeholderForCreatedAssetCollection
            }
            
        }, completionHandler: { (success1: Bool, error1: Error?) in
            
            if success1 == true {
                if let albumAssetCollection = self.albumAssetCollection(withTitle: NextLevelAlbumTitle) {
                    PHPhotoLibrary.shared().performChanges({
                        let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: photoImage)
                        let assetCollectionChangeRequest = PHAssetCollectionChangeRequest(for: albumAssetCollection)
                        let enumeration: NSArray = [assetChangeRequest.placeholderForCreatedAsset!]
                        assetCollectionChangeRequest?.addAssets(enumeration)
                    }, completionHandler: { (success2: Bool, error2: Error?) in
                        if success2 == true {
                            let alertController = UIAlertController(title: "Photo Saved!", message: "Saved to the camera roll.", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                            alertController.addAction(okAction)
                            self.present(alertController, animated: true, completion: nil)
                        }
                    })
                }
            } else if let _ = error1 {
                print("failure capturing photo from video frame \(String(describing: error1))")
            }
            
        })
    }
    
}

// MARK: - UIGestureRecognizer

extension ViewController {
    
    @objc internal func handleTapGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        let point = gestureRecognizer.location(in: self._arView)
        let hitTest = self._arView.hitTest(point, types: [.existingPlane, .existingPlaneUsingExtent, .estimatedHorizontalPlane])
        guard let hitPoint = hitTest.first else {
            return
        }
        
        let nodePostion = SCNVector3(hitPoint.worldTransform.columns.3.x,
                                     hitPoint.worldTransform.columns.3.y,
                                     hitPoint.worldTransform.columns.3.z)
        self._exampleNode?.position = nodePostion
        
        if let node = self._exampleNode,
            node.parent == nil {
            self._arView.scene.rootNode.addChildNode(node)
        }
    }
    
    @objc internal func handleVideoLongPressGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            // self.setStatus(status: .recording, animated: true)
            self._recordButton.startRecordingAnimation()
            self.startCapture()
            break
        case .changed:
            break
        case .failed:
            fallthrough
        case .cancelled:
            fallthrough
        case .ended:
            self._recordButton.stopRecordingAnimation()
            self.endCapture()
            fallthrough
        default:
            break
        }
    }
    
}

// MARK: - NextLevelDelegate

extension ViewController: NextLevelDelegate {
    
    public func nextLevel(_ nextLevel: NextLevel, didUpdateAuthorizationStatus status: NextLevelAuthorizationStatus, forMediaType mediaType: AVMediaType) {
    }
    
    // configuration
    public func nextLevel(_ nextLevel: NextLevel, didUpdateVideoConfiguration videoConfiguration: NextLevelVideoConfiguration) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didUpdateAudioConfiguration audioConfiguration: NextLevelAudioConfiguration) {
    }
    
    // session
    public func nextLevelSessionWillStart(_ nextLevel: NextLevel) {
        #if PROTOTYPE
        TinyConsole.print("📷 will start")
        #endif
    }
    
    public func nextLevelSessionDidStart(_ nextLevel: NextLevel) {
        #if PROTOTYPE
        TinyConsole.print("📷 did start")
        #endif
    }
    
    public func nextLevelSessionDidStop(_ nextLevel: NextLevel) {
    }
    
    // session interruption
    public func nextLevelSessionWasInterrupted(_ nextLevel: NextLevel) {
    }
    
    public func nextLevelSessionInterruptionEnded(_ nextLevel: NextLevel) {
    }
    
    // preview
    public func nextLevelWillStartPreview(_ nextLevel: NextLevel) {
    }
    
    public func nextLevelDidStopPreview(_ nextLevel: NextLevel) {
    }
    
    // mode
    public func nextLevelCaptureModeWillChange(_ nextLevel: NextLevel) {
    }
    
    public func nextLevelCaptureModeDidChange(_ nextLevel: NextLevel) {
    }
    
}

extension ViewController: NextLevelVideoDelegate {
    
    // video zoom
    public func nextLevel(_ nextLevel: NextLevel, didUpdateVideoZoomFactor videoZoomFactor: Float) {
    }
    
    // video frame processing
    public func nextLevel(_ nextLevel: NextLevel, willProcessRawVideoSampleBuffer sampleBuffer: CMSampleBuffer, onQueue queue: DispatchQueue) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, willProcessFrame frame: AnyObject, timestamp: TimeInterval, onQueue queue: DispatchQueue) {
    }
    
    // enabled by isCustomContextVideoRenderingEnabled
    public func nextLevel(_ nextLevel: NextLevel, renderToCustomContextWithImageBuffer imageBuffer: CVPixelBuffer, onQueue queue: DispatchQueue) {
        if let frame = self._bufferRenderer?.videoBufferOutput {
            nextLevel.videoCustomContextImageBuffer = frame
        }
    }
    
    // video recording session
    
    public func nextLevel(_ nextLevel: NextLevel, didSetupVideoInSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didSetupAudioInSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didStartClipInSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didCompleteClip clip: NextLevelClip, inSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didAppendVideoSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didAppendAudioSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didAppendVideoPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, inSession session: NextLevelSession) {
        let currentProgress = (session.totalDuration.seconds / 12.0).clamped(to: 0...1)
        self._recordButton.updateProgress(progress: Float(currentProgress), animated: true)
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didSkipVideoPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, inSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didSkipVideoSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didSkipAudioSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didCompleteSession session: NextLevelSession) {
        self.endCapture()
    }
    
    // video frame photo
        
    public func nextLevel(_ nextLevel: NextLevel, didCompletePhotoCaptureFromVideoFrame photoDict: [String : Any]?) {
        if let dictionary = photoDict,
            let photoData = dictionary[NextLevelPhotoJPEGKey] as? Data,
            let photoImage = UIImage(data: photoData) {
            self.savePhoto(photoImage: photoImage)
        }
    }
    
}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {

    public func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        self._bufferRenderer?.renderer(renderer, didRenderScene: scene, atTime: time)
        
        if let session = self._nextLevel?.arConfiguration?.session,
            let pixelBuffer = self._bufferRenderer?.videoBufferOutput {
            self._nextLevel?.arSession(session, didRenderPixelBuffer: pixelBuffer, atTime: time)
        }
    }
    
}

// MARK: - ARSessionObserver

extension ViewController: ARSessionObserver {
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        #if PROTOTYPE
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        // Use `flatMap(_:)` to remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            TinyConsole.print("session error, \(errorMessage)")
        }
        #endif
        
        self.startCamera()
    }
    
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    }
    
    public func sessionWasInterrupted(_ session: ARSession) {
        self._nextLevel?.handleSessionWasInterrupted(Notification(name: Notification.Name("NextLevel")))
    }
    
    public func sessionInterruptionEnded(_ session: ARSession) {
        self._nextLevel?.handleSessionInterruptionEnded(Notification(name: Notification.Name("NextLevel")))
    }
    
    public func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
    
    public func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
        self._nextLevel?.arSession(session, didOutputAudioSampleBuffer: audioSampleBuffer)
    }
}

// MARK: - ARSessionDelegate

extension ViewController: ARSessionDelegate {
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        self._nextLevel?.arSession(session, didUpdate: frame)
    }
    
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    }
    
}

// MARK: -  status bar

extension ViewController {
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            return .lightContent
        }
    }
    
}

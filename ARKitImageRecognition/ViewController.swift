/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit
import Alamofire
import Kingfisher

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    /// The view controller that displays the status and "restart experience" UI.
    lazy var statusViewController: StatusViewController = {
        return childViewControllers.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    /// A serial queue for thread safety when modifying the SceneKit node graph.
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! +
        ".serialSceneKitQueue")
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    static let alamofireSession: SessionManager = {
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = 10
        return Alamofire.SessionManager(configuration: sessionConfiguration)
    }()

    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self

        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Prevent the screen from being dimmed to avoid interuppting the AR experience.
		UIApplication.shared.isIdleTimerDisabled = true

        // Start the AR experience
        resetTracking()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

        session.pause()
	}

    // MARK: - Session management (Image detection setup)
    
    /// Prevents restarting the session while a restart is in progress.
    var isRestartAvailable = true
    func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
            return cgImage
        }
        return nil
    }
    
    func handleDownloadedImage() {
        
    }
    
    func handleResponseDynamicImages(jsonResponse: NSDictionary, resultCallback: @escaping (Set<ARReferenceImage>?) -> () ) {
        let JSON = jsonResponse
        guard let rootUrl = JSON["root"] as? String,
            let files = JSON["files"] as? NSArray else {
                print("Can't parse JSON")
                return
        }
        
        guard let tokenMedia = JSON["token"] as? String else {
            print("Can't parse TOken")
            return
        }
        let imageURLs = files.compactMap({ item -> URL? in
            if let dict = item as? NSDictionary,
                let value = dict.allValues.first as? String,
                let url = URL(string: rootUrl + value + "?" + "alt=media" + "&" + "token"+tokenMedia) {
                return url
            }
            return nil
        })
        
        var arImagesSet = Set<ARReferenceImage>()
        var imagesCount = imageURLs.count
        imageURLs.forEach {
            print("Try donwload by url: \($0)")
            ImageDownloader.default.downloadImage(with: $0, options: [], progressBlock: nil) {
                (image, error, url, data) in
                
                guard let url = url, let data = data else {
                    print("error in handling downloaded image")
                    imagesCount -= 1
                    return
                }
                
                print("Try downloading \(url.absoluteString)")
                guard let arImage = self.loadDynamicImageReference(name: url.absoluteString, data: data) else {
                    imagesCount -= 1
                    return
                }
                print("image: \(String(describing: arImage.name)) downloaded")
                
                arImagesSet.insert(arImage)
                if arImagesSet.count == imageURLs.count {
                    resultCallback(arImagesSet)
                }
            }
        }
    }
    
    func loadDynamicImageReferences(jsonRequestURL: String, resultCallback: @escaping (Set<ARReferenceImage>?) -> () ) {
        let request = Alamofire.request(jsonRequestURL, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: nil)
        request.downloadProgress(queue: DispatchQueue.global(qos: .utility)) { progress in
            print("Progress: \(progress.fractionCompleted)")
        }
        request.validate()
        request.responseJSON { response in
            //to get status code
            if let statusCode = request.response?.statusCode {
                print("Response status: \(statusCode)")
            }
            
            guard let result = response.result.value else {
                print("Response failed")
                return
            }
            let JSON = result as! NSDictionary
            print(JSON)
            self.handleResponseDynamicImages(jsonResponse: JSON, resultCallback: resultCallback)
        }
    }
    
    func loadDynamicImageReference(name: String, data: Data) -> ARReferenceImage? {
        guard let imageFromBundle = UIImage(data: data),
            let imageToCIImage = CIImage(image: imageFromBundle),
            let cgImage = convertCIImageToCGImage(inputImage: imageToCIImage) else { return nil; }
        
        let arImage = ARReferenceImage(cgImage, orientation: CGImagePropertyOrientation.up, physicalWidth: 0.2)

        arImage.name = name
        return arImage
    }

    @IBAction func tapResetTrackingButton(_ sender: UIButton) {
        resetTracking()
    }
    
    /// Creates a new AR configuration to run on the `session`.
    /// - Tag: ARReferenceImage-Loading
	func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        session.run(configuration)
        statusViewController.scheduleMessage("Initialized...", inSeconds: 7.5, messageType: .contentPlacement)
        
        loadDynamicImageReferences(jsonRequestURL: "http://dl.dropboxusercontent.com/s/zk29rowsb3xsayf/request.json") { [weak self] arset in
            let configuration = ARWorldTrackingConfiguration()
            configuration.detectionImages = arset
            guard let strongSelf = self else { return }
            strongSelf.session.run(configuration)
            strongSelf.statusViewController.scheduleMessage("Look around to detect images", inSeconds: 7.5, messageType: .contentPlacement)
        }
	}

    // MARK: - ARSCNViewDelegate (Image detection results)
    /// - Tag: ARImageAnchor-Visualizing
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        updateQueue.async {
            
            // Create a plane to visualize the initial position of the detected image.
            let plane = SCNPlane(width: referenceImage.physicalSize.width,
                                 height: referenceImage.physicalSize.height)
            let planeNode = SCNNode(geometry: plane)
            planeNode.opacity = 0.25
            planeNode.eulerAngles.x = -.pi / 2
            planeNode.runAction(self.imageHighlightAction)
            
            // Add the plane visualization to the scene.
            node.addChildNode(planeNode)
        }

        DispatchQueue.main.async {
            let imageName = referenceImage.name ?? ""
            self.statusViewController.cancelAllScheduledMessages()
            self.statusViewController.showMessage("Detected image “\(imageName)”")
        }
    }

    var imageHighlightAction: SCNAction {
        return .sequence([
            .wait(duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOpacity(to: 0.15, duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOut(duration: 0.5),
            .removeFromParentNode()
        ])
    }
}

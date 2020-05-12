//
//  ViewController.swift
//  AccelerometerGame
//
//  Created by Kyra McKenna on 12/05/2020.
//  Copyright © 2020 KyraMcKenna. All rights reserved.
//

import UIKit
import CoreMotion
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK:- Outlets
    @IBOutlet var cameraPreviewView : UIView!
    
    // Camera
    var rearCamera: AVCaptureDevice?
    var rearCameraInput: AVCaptureDeviceInput?
    
    // Video
    fileprivate var captureSession : AVCaptureSession?
    fileprivate var previewLayer : AVCaptureVideoPreviewLayer?
    fileprivate var viewHasAppearedOnce = false
    fileprivate var isShowingLivePreview = false
    fileprivate var addedNotifications = false
    
    private var motionManager: CMMotionManager!
    private let accelerationThreshold = 0.30
    private var isDeviceHorizontal = false
    
    // CIRCLE GAME
    private var greenDot: UIView!
    private let targetCircle = CAShapeLayer()
    private let targetRadius = 70
    private var circleCentre : CGPoint!
    private var newCircleCentre : CGPoint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
    
        super.viewDidAppear(true)
        
        // Detect Motion - see if device is horizontal
        motionManager = CMMotionManager()
        motionManager.deviceMotionUpdateInterval = 0.05
        
        self.startMotionUpdates()
        
        // Draw Circle and Ball for Motion
        self.drawCircleForMotionDetection()
       
        viewHasAppearedOnce = true;  // Flag makes sure startShowingLivePreview only works if viewDidAppear has executed once.
        // This prevents the issue where "applicationDidBecomeActive" gets called the first time the
        // app appears causing the live preview to be added before we know the exact size of UI elements.
        
        startShowingLivePreview()
    }
    
    // MARK:- Video Preview
        
    @objc internal func startShowingLivePreview() {
        
        if (viewHasAppearedOnce == true && isShowingLivePreview == false) {
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted: Bool) in
                
                DispatchQueue.main.async(execute: {
                    if (granted) {
                        // Listen for notifications for being sent to the background or brought to the foreground
                        if (self.addedNotifications == false) {
                            self.addedNotifications = true
                            
                            NotificationCenter.default.addObserver(self, selector: #selector(self.stopShowingLivePreview), name: UIApplication.willResignActiveNotification, object: nil)
                            NotificationCenter.default.addObserver(self, selector: #selector(self.startShowingLivePreview), name: UIApplication.didBecomeActiveNotification, object: nil)
                        }
                        
                        //
                        // Get an AVFoundation capture session and set the buffer delegate. The default is using high quality
                        self.captureSession = AVCaptureSession()
                        self.captureSession!.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160
                        
                        guard let captureDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: .video, position: .back) else {
                            return
                        }
                        
                        do {
                            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
                            
                            self.captureSession?.beginConfiguration() // 1
                         
                            if (self.captureSession?.canAddInput(deviceInput) == true) {
                                self.captureSession?.addInput(deviceInput)
                            }
                         
                            self.captureSession?.commitConfiguration() //5
                            
                        }
                        catch let error as NSError {
                            NSLog("\(error), \(error.localizedDescription)")
                            return
                        }
                        
                        
                        self.captureSession?.startRunning()
                        
                        //
                        // Setup preview layer
                        //
                        let previewLayerRect             = self.cameraPreviewView.bounds
                        self.previewLayer                = AVCaptureVideoPreviewLayer(session: self.captureSession!)
                        self.previewLayer?.videoGravity  = AVLayerVideoGravity.resizeAspectFill
                        self.previewLayer?.bounds        = previewLayerRect
                        self.previewLayer?.position      = CGPoint(x: previewLayerRect.midX, y: previewLayerRect.midY);
                        
                        self.cameraPreviewView.layer.addSublayer(self.previewLayer!)
                        
                        self.isShowingLivePreview = true
                        
                    } else {
                        let alert       = UIAlertController(title: "Error", message: "App does not have permission to use the camera.", preferredStyle: .alert)
                        let exitAction  = UIAlertAction(title: "OK (Exit)", style: .destructive, handler: { (action : UIAlertAction) in exit(0) })
                        
                        alert.addAction(exitAction)
                        
                        self.show(alert, sender: self)
                    }
                })
            })
        }
    }
    
    
    @objc internal func stopShowingLivePreview() {
        
        if (isShowingLivePreview == true) {
            
            isShowingLivePreview = false
            
            previewLayer?.removeFromSuperlayer()
            
            captureSession?.stopRunning()
            captureSession = nil
        }
    }
    
    
    
    func drawCircleForMotionDetection()
    {
        // Draw Green Dot
        greenDot = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0))
        greenDot.backgroundColor = UIColor.green
        greenDot.layer.cornerRadius = 25.0
        self.view.addSubview(greenDot)
        self.view.bringSubviewToFront(greenDot)
            
        // Move Circle in response to tilt of device
        circleCentre = self.greenDot.center
        newCircleCentre = self.greenDot.center
        
        // Draw Target circle in view center
        let midViewX = view.frame.midX
        let midViewY = view.frame.midY
        let circlePath = UIBezierPath(arcCenter: CGPoint(x: midViewX,y: midViewY), radius: CGFloat(targetRadius), startAngle: CGFloat(0), endAngle:CGFloat(M_PI * 2), clockwise: true)
        targetCircle.path = circlePath.cgPath
        targetCircle.fillColor = UIColor.clear.cgColor
        targetCircle.strokeColor = UIColor.lightGray.cgColor
        targetCircle.lineWidth = 3.0
        view.layer.addSublayer(targetCircle)
    }
    
    private func startMotionUpdates() {
        
        self.motionManager.stopDeviceMotionUpdates()
        
        if (OperationQueue.current?.underlyingQueue) != nil {
            self.motionManager.startDeviceMotionUpdates(
                to: OperationQueue.current!, withHandler: {
                    (deviceMotion, error) -> Void in

                self.motionManager.deviceMotionUpdateInterval = 0.01

                if(error == nil) {
                    
                    self.handleDeviceMotionUpdate(deviceMotion: deviceMotion!)
                } else {
                    //handle the error
                }
            })
            
            motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { (data, error) in
                if let myData = data
                {
                    self.handleDeviceAccelerationUpdate(deviceAcceleration: myData)
                }
            }
        }
    }
    
    func handleDeviceMotionUpdate(deviceMotion:CMDeviceMotion) {
    
        // Get the attitude of the device
        let attitude = deviceMotion.attitude
        
        // Get the pitch (in radians) and convert to degrees.
        let value = (attitude.pitch * 180.0/Double.pi)
        let intValue = abs(Int(value))
        //print("PITCH : \(intValue)")
        if(intValue > 10){
             self.isDeviceHorizontal = false
             DispatchQueue.main.async{
                 //Update UI
                 let keep = NSLocalizedString("Not Horizontal", comment:"")
                 self.showToast(message: keep, yPosition: (20) )
             }
        }else{
             self.isDeviceHorizontal = true
        }
    }
    
    func handleDeviceAccelerationUpdate(deviceAcceleration:CMAccelerometerData){
             
       let accelerationX = (CGFloat(deviceAcceleration.acceleration.x) * 10)
       let accelerationY = (CGFloat(deviceAcceleration.acceleration.y) * -10)

       self.newCircleCentre.x = accelerationX
       self.newCircleCentre.y = accelerationY

       if abs(self.newCircleCentre.x) + abs(self.newCircleCentre.y) < 1.0 {
           self.newCircleCentre = .zero
       }

       self.circleCentre = CGPoint(x: self.circleCentre.x + self.newCircleCentre.x, y: self.circleCentre.y + self.newCircleCentre.y)

       self.circleCentre.x = max(self.greenDot.frame.size.width*0.5, min(self.circleCentre.x, self.view.bounds.width - self.greenDot.frame.size.width*0.5))
       self.circleCentre.y = max(self.greenDot.frame.size.height*0.5, min(self.circleCentre.y, self.view.bounds.height - self.greenDot.frame.size.height*0.5))

       self.greenDot.center = self.circleCentre
       
       let cirx = self.view.frame.midX
       let ciry = self.view.frame.midY
       
       let checkPoint = Int( pow((self.circleCentre.x - cirx), 2) + pow((self.circleCentre.y - ciry), 2))
       
       if ( checkPoint <  (targetRadius * targetRadius) ){
           self.targetCircle.strokeColor = UIColor.green.cgColor
       }else{
           self.targetCircle.strokeColor = UIColor.lightGray.cgColor
       }
    }
}
extension UIViewController {
    
    func showToast(message : String, yPosition:CGFloat) {
        
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 120, y: yPosition+50, width: 250, height: 30))
        let purple = UIColor(red: CGFloat(186 / 255.0), green: CGFloat(85 / 255.0), blue: CGFloat(211 / 255.0), alpha: CGFloat(1))
        toastLabel.backgroundColor = purple
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 18, weight: UIFont.Weight.semibold)
        toastLabel.text = " " + message + " "
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10
        //toastLabel.clipsToBounds  =  true
        toastLabel.numberOfLines = 0
        toastLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
       // toastLabel.sizeToFit()
        toastLabel.clipsToBounds  =  true
        self.view.addSubview(toastLabel)
        UIView.animate(withDuration: 1.0, delay: 0.2, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    }
}



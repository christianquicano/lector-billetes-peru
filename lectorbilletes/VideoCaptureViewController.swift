//
//  VideoCaptureViewController.swift
//  lectorbilletes
//
//  Created by Christian Quicano on 1/4/20.
//  Copyright © 2020 christianquicano. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class VideoCaptureViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var rootLayer: CALayer! = nil

    @IBOutlet weak private var previewView: UIView!
    @IBOutlet weak private var infoView: UIView!

    private let session = AVCaptureSession()

    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let videoDataOutput = AVCaptureVideoDataOutput()

    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Implement this in the subclass.
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAVCapture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        closeInfoView(nil)
        if !Util.getBool(Util.keyNoShow) {
            showInfoView(nil)
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func closeForEverInfoView(_ sender: UIButton?) {
        Util.saveBool(Util.keyNoShow, bool: true)
        infoView.isHidden = true
    }

    @IBAction func closeInfoView(_ sender: UIButton?) {
        infoView.isHidden = true
    }

    @IBAction func showInfoView(_ sender: Any?) {
        infoView.isHidden = false
    }

    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!

        // Select a video device and make an input.
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error).")
            return
        }

        session.beginConfiguration()

        // The model input size is smaller than 640x480, so better resolution won't help us.
        session.sessionPreset = .high

        // Add a video input.
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session.")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)

        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output.
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
//            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session.")
            session.commitConfiguration()
            return
        }
        let captureConnection = videoDataOutput.connection(with: .video)

        // Always process the frames.
        captureConnection?.isEnabled = true

        session.commitConfiguration()

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.connection?.videoOrientation = .portrait
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = previewView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.insertSublayer(previewLayer, at: 0)
    }

    func startCaptureSession() {
        session.startRunning()
    }

    // Clean up capture setup.
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }

    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("The capture output dropped a frame.")
    }

    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation

        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, Home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, Home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, Home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, Home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
}

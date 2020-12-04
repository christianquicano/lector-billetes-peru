//
//  VisionViewController.swift
//  lectorbilletes
//
//  Created by Christian Quicano on 1/3/20.
//  Copyright © 2020 christianquicano. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class VisionViewController: VideoCaptureViewController {

    private var startDate = Date()

    private let synthesizer = AVSpeechSynthesizer()
    private var detectionOverlay: CALayer! = nil

    // Vision parts
//    private var analysisRequests = [VNRequest]()
    private let sequenceRequestHandler = VNSequenceRequestHandler()

    // Registration History
    private let maximumHistoryLength = 15
    private let distanceSceneStability:CGFloat = 20
    private let minConfidence: CGFloat = 0.98
    private let labelBanknotes = "banknotes"
    private let textReadBanknotes = "Enfoque un billete"
    private var transpositionHistoryPoints: [CGPoint] = []
    private var previousPixelBuffer: CVPixelBuffer?

    // The pixel buffer being held for analysis; used to serialize Vision requests.
    private var currentlyAnalyzedPixelBuffer: CVPixelBuffer?

    // QUEUE for dispatching vision classification and barcode requests
    private let visionQueue = DispatchQueue(label: "pro.christianquicano.lectorbilletesQueue")

    var processing = false

    // MARK: - AnalyzeImage
    private var result: Result?
    private var result2: Result?
    private var modelDataHandler: ModelDataHandler? =
    ModelDataHandler(modelFileInfo: MobileNet.modelInfo, labelsFileInfo: MobileNet.labelsInfo)

    private var modelDataHandler_Binary: ModelDataHandler_Binary? =
    ModelDataHandler_Binary(modelFileInfo: MobileNet_Binary.modelInfo, labelsFileInfo: MobileNet_Binary.labelsInfo)

    private func analyzeCurrentImage() {
        didOutput(pixelBuffer: currentlyAnalyzedPixelBuffer)
    }

    //Exman images
    func didOutput(pixelBuffer: CVPixelBuffer?) {
        guard let pixelBuffer = pixelBuffer else {
            processing = false
            currentlyAnalyzedPixelBuffer = nil
            return
        }

        // Pass the pixel buffer to TensorFlow Lite to perform inference.
        result2 = modelDataHandler_Binary?.runModel(onFrame: pixelBuffer)
        let labelFound = result2?.inferences.first?.label ?? ""
        if labelFound == labelBanknotes {
            startDate = Date()
            result = modelDataHandler?.runModel(onFrame: pixelBuffer)
            // Display results by handing off to the InferenceViewController.
            DispatchQueue.main.async {
              self.proccessResult(confidence: (CGFloat(self.result?.inferences.first?.confidence ?? 0.0)),
                                  label: self.result?.inferences.first?.label)
            }
        } else {
            let difference = Date().timeIntervalSince(startDate)
            if difference > 10 {
                startDate = Date()
                speech(text: textReadBanknotes)
                currentlyAnalyzedPixelBuffer = nil
            } else {
                currentlyAnalyzedPixelBuffer = nil
                processing = false
            }
        }


    }

    private func proccessResult(confidence: CGFloat, label: String?) {
        guard confidence > minConfidence else {
            processing = false
            currentlyAnalyzedPixelBuffer = nil
            return
        }
        speech(text: label)
        currentlyAnalyzedPixelBuffer = nil
    }

    func speech(text: String?) {
        guard let text = text else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-PE")
        utterance.rate = 0.6
        if !synthesizer.isSpeaking {
            synthesizer.speak(utterance)
        }
    }

    fileprivate func resetTranspositionHistory() {
        transpositionHistoryPoints.removeAll()
    }

    fileprivate func recordTransposition(_ point: CGPoint) {
        transpositionHistoryPoints.append(point)

        if transpositionHistoryPoints.count > maximumHistoryLength {
            transpositionHistoryPoints.removeFirst()
        }
    }

    /// - Tag: CheckSceneStability
    fileprivate func sceneStabilityAchieved() -> Bool {
        // Determine if we have enough evidence of stability.
        if transpositionHistoryPoints.count == maximumHistoryLength {
            // Calculate the moving average.
            var movingAverage: CGPoint = CGPoint.zero
            for currentPoint in transpositionHistoryPoints {
                movingAverage.x += currentPoint.x
                movingAverage.y += currentPoint.y
            }
            let distance = abs(movingAverage.x) + abs(movingAverage.y)
            if distance < distanceSceneStability {
                return true
            }
        }
        return false
    }
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        guard previousPixelBuffer != nil else {
            previousPixelBuffer = pixelBuffer
            self.resetTranspositionHistory()
            return
        }

        if processing {
            return
        }

        let registrationRequest = VNTranslationalImageRegistrationRequest(targetedCVPixelBuffer: pixelBuffer)
        do {
            try sequenceRequestHandler.perform([ registrationRequest ], on: previousPixelBuffer!)
        } catch let error as NSError {
            print("Failed to process request: \(error.localizedDescription).")
            return
        }

        previousPixelBuffer = pixelBuffer

        if let results = registrationRequest.results {
            if let alignmentObservation = results.first as? VNImageTranslationAlignmentObservation {
                let alignmentTransform = alignmentObservation.alignmentTransform
                self.recordTransposition(CGPoint(x: alignmentTransform.tx, y: alignmentTransform.ty))
            }
        }
        if self.sceneStabilityAchieved() {
            processing = true
            if currentlyAnalyzedPixelBuffer == nil {
                // Retain the image buffer for Vision processing.
                currentlyAnalyzedPixelBuffer = pixelBuffer
                analyzeCurrentImage()
            } else {
                processing = false
            }
        } else {
            processing = false
        }
    }

    override func setupAVCapture() {
        synthesizer.delegate = self

        super.setupAVCapture()

        // setup Vision parts
        setupLayers()
//        setupVision()

        // start the capture
        startCaptureSession()

    }

    func setupLayers() {
        detectionOverlay = CALayer()
        detectionOverlay.bounds = self.view.bounds.insetBy(dx: 20, dy: 20)
        detectionOverlay.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        detectionOverlay.borderColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.7])
        detectionOverlay.borderWidth = 8
        detectionOverlay.cornerRadius = 20
        detectionOverlay.isHidden = true
        rootLayer.addSublayer(detectionOverlay)
    }
}

extension VisionViewController: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.processing = false
    }

}

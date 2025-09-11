//
//  ModelLoader.swift
//  DeNSFW
//
//  Created by Bedapudi Praneeth on 09/09/25.
//

import Foundation
import CoreML
import Vision
import UIKit
import OnnxRuntimeBindings

class ModelLoader: ObservableObject {
    @Published var isModelLoaded = false
    @Published var loadingError: String?
    
    private var ortSession: ORTSession?
    private var ortEnvironment: ORTEnv?
    
    init() {
        loadModel()
    }
    
    func loadModel() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                // Initialize ONNX Runtime environment
                let ortEnv = try ORTEnv(loggingLevel: .warning)
                self?.ortEnvironment = ortEnv
                
                // Get model path
                guard let modelPath = Bundle.main.path(forResource: "vision", ofType: "onnx") else {
                    throw NSError(domain: "ModelLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model file not found in bundle"])
                }
                
                // Create session options
                let sessionOptions = try ORTSessionOptions()
                // Use extended optimizations for better performance
                try sessionOptions.setGraphOptimizationLevel(.extended)
                // Use 3 threads for good balance on modern iPhones
                // Set to 1 for battery saving, or omit to use all cores
                try sessionOptions.setIntraOpNumThreads(3)
                
                // Create ONNX Runtime session
                let session = try ORTSession(env: ortEnv, modelPath: modelPath, sessionOptions: sessionOptions)
                self?.ortSession = session
                
                DispatchQueue.main.async {
                    self?.isModelLoaded = true
                    print("ONNX model loaded successfully")
                    if let inputNames = try? session.inputNames() {
                        print("Input names: \(inputNames)")
                    }
                    if let outputNames = try? session.outputNames() {
                        print("Output names: \(outputNames)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.loadingError = error.localizedDescription
                    print("Failed to load ONNX model: \(error)")
                }
            }
        }
    }
    
    func classifyImage(_ image: UIImage) -> (isNSFW: Bool, confidence: Float) {
        guard isModelLoaded, let session = ortSession else {
            print("Model not loaded yet")
            return (false, 0.0)
        }
        
        guard let preprocessedData = preprocessImage(image) else {
            print("Failed to preprocess image")
            return (false, 0.0)
        }
        
        do {
            // Create input tensor
            let inputShape: [NSNumber] = [1, 3, 224, 224]  // Batch size 1, 3 channels, 224x224
            let inputTensor = try ORTValue(
                tensorData: NSMutableData(data: preprocessedData),
                elementType: .float,
                shape: inputShape
            )
            
            // Run inference
            let inputNames = try session.inputNames()
            let outputNames = try session.outputNames()
            
            let inputs = [inputNames[0]: inputTensor]
            let startTime = Date()
            let outputs = try session.run(
                withInputs: inputs,
                outputNames: Set(outputNames),
                runOptions: nil
            )
            let inferenceTime = Date().timeIntervalSince(startTime)
            
            // Get output tensor
            guard let outputName = outputNames.first,
                  let outputTensor = outputs[outputName],
                  let outputData = try? outputTensor.tensorData() as Data else {
                print("Failed to get output tensor")
                return (false, 0.0)
            }
            
            // Parse output data (4 class probabilities)
            let floatArray = outputData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [Float32] in
                let floatPointer = pointer.bindMemory(to: Float32.self)
                return Array(floatPointer)
            }
            
            // Apply softmax if needed (some models output logits)
            let probabilities = softmax(floatArray)
            
            // New detection logic:
            // 1. Check if NSFW (class 3) is the highest scoring class
            // 2. If yes, check if second highest is less than 50% of NSFW score
            let nsfwScore = probabilities[3]
            
            // Find the highest score and its index
            var maxScore: Float32 = 0
            var maxIndex = 0
            for (index, score) in probabilities.enumerated() {
                if score > maxScore {
                    maxScore = score
                    maxIndex = index
                }
            }
            
            // Find second highest score
            var secondHighest: Float32 = 0
            for (index, score) in probabilities.enumerated() {
                if index != maxIndex && score > secondHighest {
                    secondHighest = score
                }
            }
            
            // NSFW detected only if:
            // 1. NSFW is the top class AND
            // 2. Second highest is less than 50% of NSFW score (showing clear dominance)
            let isNSFW = (maxIndex == 3) && (secondHighest < nsfwScore * 0.5)
            
            // Log results for debugging
            print("----------------------------------------")
            print("Image Classification Results:")
            print("  Class 0 (Safe): \(String(format: "%.3f", probabilities[0]))\(maxIndex == 0 ? " 👑" : "")")
            print("  Class 1 (Safe): \(String(format: "%.3f", probabilities[1]))\(maxIndex == 1 ? " 👑" : "")")
            print("  Class 2 (Safe): \(String(format: "%.3f", probabilities[2]))\(maxIndex == 2 ? " 👑" : "")")
            print("  Class 3 (NSFW): \(String(format: "%.3f", probabilities[3]))\(maxIndex == 3 ? " 👑" : "")")
            print("  Top class: \(maxIndex) with score \(String(format: "%.3f", maxScore))")
            print("  Second highest: \(String(format: "%.3f", secondHighest))")
            if maxIndex == 3 {
                print("  Dominance check: \(String(format: "%.3f", secondHighest)) < \(String(format: "%.3f", nsfwScore * 0.5)) = \(secondHighest < nsfwScore * 0.5 ? "YES" : "NO")")
            }
            print("  Result: \(isNSFW ? "⚠️ NSFW DETECTED" : "✅ SAFE")")
            print("  Inference time: \(String(format: "%.3f", inferenceTime))s")
            
            return (isNSFW, nsfwScore)
            
        } catch {
            print("Inference error: \(error)")
            return (false, 0.0)
        }
    }
    
    private func softmax(_ input: [Float32]) -> [Float32] {
        let maxInput = input.max() ?? 0
        let expValues = input.map { exp($0 - maxInput) }
        let sumExp = expValues.reduce(0, +)
        return expValues.map { $0 / sumExp }
    }
    
    private func preprocessImage(_ image: UIImage) -> Data? {
        // Step 1: Convert to RGB if needed
        guard let cgImage = image.cgImage else { return nil }
        
        // Step 2: Resize to 224x224 with bilinear interpolation
        let targetSize = CGSize(width: 224, height: 224)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        guard let resizedCGImage = resizedImage.cgImage else { return nil }
        
        // Step 3: Convert to float32 array
        let width = 224
        let height = 224
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )
        
        context?.draw(resizedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Create float array for preprocessing
        var floatArray = [Float32](repeating: 0, count: 3 * width * height)
        
        // Mean values for normalization (in BGR order)
        let meanB: Float32 = 0.406
        let meanG: Float32 = 0.456
        let meanR: Float32 = 0.485
        
        // Process pixels
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let dataIndex = pixelIndex * bytesPerPixel
                
                // Step 4: Get RGB values and convert to float32
                let r = Float32(pixelData[dataIndex]) / 255.0
                let g = Float32(pixelData[dataIndex + 1]) / 255.0
                let b = Float32(pixelData[dataIndex + 2]) / 255.0
                
                // Step 5 & 6: Convert RGB to BGR and subtract mean
                // Step 7: Transpose to CHW format (channels, height, width)
                // Channel 0 (B)
                floatArray[0 * width * height + pixelIndex] = b - meanB
                // Channel 1 (G)
                floatArray[1 * width * height + pixelIndex] = g - meanG
                // Channel 2 (R)
                floatArray[2 * width * height + pixelIndex] = r - meanR
            }
        }
        
        // Step 8: Already in shape [3, 224, 224], batch dimension will be added during inference
        // Step 9: Convert to Data
        return floatArray.withUnsafeBytes { Data($0) }
    }
}
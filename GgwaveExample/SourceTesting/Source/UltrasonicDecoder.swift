//
//  UltrasonicDecoder.swift
//  ObjcTest
//
//  Created by fahid on 09/06/2021.
//

import UIKit
import Foundation
import AVFoundation
import UserNotifications
import CoreLocation
import GgwavePod

class UltrasonicDecoder {
    
    static let shared = UltrasonicDecoder()

    private var isListening = false
    private var isPermissionsAsked = false
    private var engine: AVAudioEngine!
    private var testNode: AVAudioInputNode!
    private var data = [Int8]()
    private var instance: ggwave_Instance!
    private var controller: UIViewController!
    private var isEngineRunning = false
    private let reachability = try! Reachability()
    private lazy var scheduleLocationManager = ScheduledLocationManager()
    private var titleForUltrasonicMessage = ""

    deinit {
        scheduleLocationManager.stopGettingUserLocation()
    }
    

    private init(){
        guard let topVC = UIViewController.topViewController() else {
            assertionFailure("Please provide top view controller or atleast one activity screen to start decoder.")
            return
        }
        controller = topVC
        
        reachability.whenReachable = { reachability in
            print("Reachable")
            messageManager.uploadAllMessagesToServer()
        }
        reachability.whenUnreachable = { _ in print("Not Reachable") }
        do { try reachability.startNotifier() }
        catch { print("Unable to start notifier") }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5) { [weak self] in
            guard let self = self else { return }
            self.scheduleLocationManager.getUserLocationWithInterval(interval: 60)
        }
    }
    
    func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
    }
     
    @objc func handleInterruption(_ notification: Notification) {

        guard let info = notification.userInfo, let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt, let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        print(info)
        
        if type == .began {
            // Interruption began, take appropriate actions (save state, update user interface)
            self.stopDecoder()
        }
        else if type == .ended {
            
            self.isPermissionsAsked = false
            self.isEngineRunning = false
            self.startDecodingFromCordova()
            
//            self.activateAudioSession()
//            self.startRecoderTest()

            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // Interruption Ended - playback should resume
            }
        }
    }

    func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    func startDecodingFromCordova() {
        
        if isPermissionsAsked {
            print("startDecodingFromCordova called - from continue flow")
            activateAudioSession()
            startRecoderTest()
            return
        }
        
        print("startDecodingFromCordova called - from scratch flow")

        registerForNotifications()
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
        activateAudioSession()

        isPermissionsAsked = true
        engine = AVAudioEngine()
        testNode = engine.inputNode

        var parameters = ggwave_getDefaultParameters()
        parameters.sampleFormatInp = GGWAVE_SAMPLE_FORMAT_F32
        parameters.sampleFormatOut = GGWAVE_SAMPLE_FORMAT_I16
        parameters.sampleRateOut = Int32(testNode.inputFormat(forBus: 0).sampleRate)
        parameters.sampleRateInp = Int32(testNode.inputFormat(forBus: 0).sampleRate)
        self.instance = ggwave_init(parameters)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                AVAudioSession.sharedInstance().requestRecordPermission({ [weak self] (granted) in
                    guard let self = self else { return }
                    if granted {
                        DispatchQueue.main.async {
                            self.startRecoderTest()
                        }
                    }
                    else {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            let alert = UIAlertController(title: "", message: "Please allow permissions for microphont from iOS settings.", preferredStyle: UIAlertController.Style.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                            self.controller.present(alert, animated: true, completion: nil)
                        }
                    }
                })
            }
            else if let error = error {
                print(error.localizedDescription)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let alert = UIAlertController(title: "", message: "Please allow permissions for notifications from iOS settings.", preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                    self.controller.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    private func startRecoderTest() {

        if isListening { return }
        isListening = true
        data.removeAll()
        
        engine.prepare()
        
        if !isEngineRunning {
            isEngineRunning = true
            
            var streamFormat = AudioStreamBasicDescription()
            streamFormat.mSampleRate = testNode.inputFormat(forBus: 0).sampleRate
            streamFormat.mFormatID = kAudioFormatLinearPCM
            streamFormat.mFormatFlags = kLinearPCMFormatFlagIsFloat
            streamFormat.mFramesPerPacket = 1
            streamFormat.mChannelsPerFrame = 1
            streamFormat.mBitsPerChannel = 32
            streamFormat.mBytesPerFrame = (streamFormat.mBitsPerChannel / 8) * streamFormat.mChannelsPerFrame
            streamFormat.mBytesPerPacket = streamFormat.mBytesPerFrame
            streamFormat.mReserved = 0
            let format = AVAudioFormat.init(streamDescription: &streamFormat)

            testNode.installTap(onBus: 0, bufferSize: 4096, format: format, block: {
                (buffer, time) in
                //  print("testNode.installTap buffer closure")
                if let channelData = buffer.floatChannelData {
                    let arraySize = Int(buffer.frameLength)
                    let samples = Array(UnsafeBufferPointer(start: channelData[0], count:arraySize))
                    //  print(samples)
                    
                    let bytes = samples.compactMap{$0.bytes.map{Int8(bitPattern: $0)}}.reduce([], +)
                    self.data.append(contentsOf: bytes)
                    if self.data.count >= 4096 {
                        var arr = self.data
                        self.ggwave(wp: &arr)
                        self.data.removeAll()
                    }
                }
            })
        }
        
        do {
            try engine.start()
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    private func ggwave(wp: inout [Int8]) {
        
        var decoded = Array<Int8>(repeating: 0, count: 256)
        
        let ret = ggwave_decode(instance, &wp, Int32(wp.count), &decoded)
        if ret <= 0 {
            //  print("No Data Detected.")
        }
        else {
            let bytes: [UInt8] = decoded.map{UInt8(bitPattern: $0)}
            guard var decodedText = String(bytes: bytes, encoding: .utf8) else { return }
            decodedText = decodedText.replacingOccurrences(of: "\0", with: "")
            print("---------------")
            print(decodedText)
            print("---------------")
            
            //  decodedText = "a5c98#TThis is a title #M hi how are you?"
            //  decodedText = "7618e#M hi how are you?"
            //  let bundleIDSHA256 = Bundle.main.bundleIdentifier?.sha256().prefix(5) ?? ""
            let bundleIDSHA256 = "a5c98"
            if bundleIDSHA256.isEmpty { return }
            if !decodedText.contains(bundleIDSHA256) { return }
            decodedText = decodedText.replacingOccurrences(of: bundleIDSHA256, with: "")
            
            if decodedText.contains("#T") {
                let title = decodedText.replacingOccurrences(of: "#T", with: "")
                self.titleForUltrasonicMessage = title.isEmpty ? "Press Bible" : title
                return
            }
            else if decodedText.contains("#M") {
                let msg = decodedText.replacingOccurrences(of: "#M", with: "")
                var loc = ""
                if let coordinate = scheduleLocationManager.lastCapturedLocation?.coordinate {
                    loc = "\(coordinate.latitude), \(coordinate.longitude)"
                }
                if self.titleForUltrasonicMessage.isEmpty {
                    self.titleForUltrasonicMessage = "Press Bible"
                }
                let message = Message(title: self.titleForUltrasonicMessage, msg: msg, loc: loc)
                messageManager.save(message: message)
                self.titleForUltrasonicMessage = ""
                showNotification(message: message)
            }
        }
    }
    
    func showNotification(message: Message) {

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stopDecoder()
            DispatchQueue.main.async { [weak self] in
                guard let _ = self else { return }
                notificationManager.showNotification(message: message)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) { [weak self] in
                    guard let self = self else { return }
                    self.startDecodingFromCordova()
                }
            }
        }
    }
    
    func stopDecoder() {
        isListening = false
        engine?.pause()
//        testNode?.removeTap(onBus: 0)
    }
}











extension Float32 {
   var bytes: [UInt8] {
       withUnsafeBytes(of: self, Array.init)
   }
}





extension UIViewController {
    
    class func topViewController(_ base: UIViewController? = UIApplication.shared.windows.first!.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }
        return base
    }
}

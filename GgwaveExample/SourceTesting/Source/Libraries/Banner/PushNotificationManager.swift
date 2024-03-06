//
//  PushNotificationManager.swift
//  Husl
//
//  Created by Fahad Attique on 04/10/2020.
//  Copyright © 2020 Fahad Attique. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import UserNotifications

let application = UIApplication.shared
let notificationManager = PushNotificationManager.sharedInstance

class PushNotificationManager: NSObject {
    
    // MARK:- Shared
    
    static let sharedInstance = PushNotificationManager()
    
    private var player: AVPlayer!
    private var item: AVPlayerItem!
    // MARK:- Life Cycle
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK:- Functions
    
    func playNotificationSound() {
        
//        let path = Bundle.main.path(forResource: "notification", ofType: "mp3")
//        let soundUrl = URL(fileURLWithPath: path!)
//        item = AVPlayerItem(url: soundUrl)
//        player = AVPlayer(playerItem: item)
//        player.volume = 1.0
//        player.play()

        if UIApplication.shared.applicationState == .active {
            try? AVAudioSession.sharedInstance().setActive(false)
            let systemSoundID: SystemSoundID = 1007
            AudioServicesPlaySystemSound(systemSoundID)
        }
    }
    
    func showNotification(message: Message) {
    
        guard let topVC = UIApplication.shared.delegate?.window??.rootViewController else { return }
        let title = message.title
        let text = message.message
        if UIApplication.shared.applicationState == .active || UIApplication.shared.applicationState == .inactive {
            playNotificationSound()
            let alert = UIAlertController(title: title, message: text, preferredStyle: UIAlertController.Style.alert)
            var buttonTitle = "Close"
            if !checkForUrls(text: text).isEmpty {
                buttonTitle = "Proceed"
                let proceedAction = UIAlertAction(title: buttonTitle, style: .default) { action in
                    self.handleTap(message: message)
                }
                alert.addAction(proceedAction)
                alert.addAction(UIAlertAction(title: "Close", style: UIAlertAction.Style.cancel, handler: nil))
            }
            else {
                buttonTitle = "Close"
                alert.addAction(UIAlertAction(title: buttonTitle, style: UIAlertAction.Style.default, handler: nil))
            }
            
            if let presentedVC = topVC.presentedViewController {
                presentedVC.present(alert, animated: true, completion: nil)
            }
            else {
                topVC.present(alert, animated: true, completion: nil)
            }
            
//            let banner = Banner(title: title, subtitle: text) {
//                self.handleTap(text: text)
//            }
//            banner.textColor = UIColor.white
//            banner.springiness = BannerSpringiness.slight
//            banner.position = BannerPosition.top
//            banner.dismissesOnTap = true
//            banner.dismissesOnSwipe = true
//            banner.show()
        }
        else {
            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = text
            content.sound = UNNotificationSound.default
            content.userInfo = message.toMessageJSON()

            // show this notification five seconds from now
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            // choose a random identifier
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            // add our notification request
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func handleTap(message: Message) {
        
        let text = message.message
        let urls = checkForUrls(text: text)
        guard let url = urls.first else { return }
        messageManager.save(clickedMessage: message)
        if application.canOpenURL(url) {
            application.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func checkForUrls(text: String) -> [URL] {
        let types: NSTextCheckingResult.CheckingType = .link

        do {
            let detector = try NSDataDetector(types: types.rawValue)

            let matches = detector.matches(in: text, options: .reportCompletion, range: NSMakeRange(0, text.count))
        
            return matches.compactMap({$0.url})
        } catch let error {
            debugPrint(error.localizedDescription)
        }

        return []
    }
}




extension PushNotificationManager: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            // The user dismissed the notification without taking action
        }
        else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // The user launched the app
            if let messageJSON = response.notification.request.content.userInfo as? [String:Any] {
                if let message = Message(JSON: messageJSON) {    //    it just update requested
                    self.showNotification(message: message)
                }
            }
        }
    }
}

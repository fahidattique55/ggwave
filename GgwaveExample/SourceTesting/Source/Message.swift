//
//  Message.swift
//  ObjcTest
//
//  Created by fahid on 27/07/2021.
//

import Foundation

class Message: Mappable, Equatable {
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
    
    enum CodingKeys: String {
        case id
        case device
        case url
        case epoch
        case lang
        case location
        case message
        case title
        case messageid
        case zone
    }

    var id = ""
    var zone = ""
    var lang = ""
    var device = ""
    var message = ""
    var title = ""
    var messageid = ""
    var location = ""
    var epoch = ""
    var url: String {
        return PushNotificationManager.sharedInstance.checkForUrls(text: message).first?.absoluteString ?? ""
    }

    init() { }
    init(title: String, msg: String, loc: String) {
        id = UserDefaults.standard.trackingIDForDevice
        message = msg
        self.title = title.isEmpty ? "Press Bible" : title
        let timeStamp = Int64((Date().timeIntervalSince1970))
        epoch = "\(timeStamp)"
        messageid = String((epoch + message).sha256().prefix(8))
        location = loc
        device = "iphone"
        zone = TimeZone.current.abbreviation() ?? ""
        lang = Locale.current.collatorIdentifier ?? ""
    }
    
    public required init?(map: Map) {
        mapping(map: map)
    }

    public func mapping(map: Map) {
        id <- map[CodingKeys.id.rawValue]
        device <- map[CodingKeys.device.rawValue]
        epoch <- map[CodingKeys.epoch.rawValue]
        lang <- map[CodingKeys.lang.rawValue]
        location <- map[CodingKeys.location.rawValue]
        message <- map[CodingKeys.message.rawValue]
        title <- map[CodingKeys.title.rawValue]
        messageid <- map[CodingKeys.messageid.rawValue]
        zone <- map[CodingKeys.zone.rawValue]
    }
    
    public func toMessageJSON() -> [String:String] {
        var json = [String:String]()
        json[CodingKeys.id.rawValue] = id
        json[CodingKeys.device.rawValue] = device
        json[CodingKeys.epoch.rawValue] = epoch
        json[CodingKeys.lang.rawValue] = lang
        json[CodingKeys.location.rawValue] = location
        json[CodingKeys.message.rawValue] = message
        json[CodingKeys.title.rawValue] = title
        json[CodingKeys.messageid.rawValue] = messageid
        json[CodingKeys.zone.rawValue] = zone
        return json
    }

    public func toClickedMessageJSON() -> [String:String] {
        var json = [String:String]()
        json[CodingKeys.messageid.rawValue] = messageid
        json[CodingKeys.url.rawValue] = url
        return json
    }
}






let messageManager = MessageManager.shared
class MessageManager {
    static let shared = MessageManager()
    private init() {}
    func save(message: Message) {
        defaults.save(message: message)
        uploadAllMessagesToServer()
    }
    func deleteAllMessages() {
        defaults.removeAllMessages()
    }
    func uploadAllMessagesToServer() {
        let messages = defaults.savedMessages
        if messages.isEmpty { return }
        let jsons = messages.compactMap{$0.toMessageJSON()}
        let urlString = baseURL + "pushUltrasonicData"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONSerialization.data(withJSONObject: jsons)
        sessionManager.request(request).response { [weak self] response in
            guard let self = self else { return }
            if response.response?.statusCode == 200 {
                messageManager.deleteAllMessages()
                self.uploadAllClickedMessagesToServer()
            }
        }.responseString { (responseString) in
            //  if let url = request.urlRequest?.url { print("\n💚💚\n\(url)\n💚💚\n") }
            print("❤️❤️❤️\(responseString)\n❤️❤️❤️\n")
        }
    }

    // clicked messages handling
    func save(clickedMessage: Message) {
        defaults.save(clickedMessage: clickedMessage)
        uploadAllClickedMessagesToServer()
    }
    func deleteAllClickedMessages() {
        defaults.removeAllClickedMessages()
    }
    func uploadAllClickedMessagesToServer() {
        let messages = defaults.clickedMessages
        if messages.isEmpty { return }
        let jsons = messages.compactMap{$0.toClickedMessageJSON()}
        let urlString = baseURL + "updateUltrasonicData"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONSerialization.data(withJSONObject: jsons)
        sessionManager.request(request).response { [weak self] response in
            guard let _ = self else { return }
            if response.response?.statusCode == 200 {
                messageManager.deleteAllClickedMessages()
            }
        }.responseString { (responseString) in
              if let url = request.urlRequest?.url { print("\n💚💚\n\(url)\n💚💚\n") }
            print("❤️❤️❤️\(responseString)\n❤️❤️❤️\n")
        }
    }
}






extension UserDefaults {
    var trackingIDForDevice: String {   //  This will only change when user will delete the app.
        get{
            if let trackingID = string(forKey: "trackingIDForDevice")?.lowercased() {
                return trackingID
            }
            else {
                let trackingID = UUID().uuidString.lowercased()
                self.setValue(trackingID, forKey: "trackingIDForDevice")
                self.synchronize()
                return trackingID
            }
        }
    }
}








import Foundation
import CommonCrypto

extension Data{
    public func sha256() -> String{
        return hexStringFromData(input: digest(input: self as NSData))
    }
    
    private func digest(input : NSData) -> NSData {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        var hash = [UInt8](repeating: 0, count: digestLength)
        CC_SHA256(input.bytes, UInt32(input.length), &hash)
        return NSData(bytes: hash, length: digestLength)
    }
    
    private  func hexStringFromData(input: NSData) -> String {
        var bytes = [UInt8](repeating: 0, count: input.length)
        input.getBytes(&bytes, length: input.length)
        
        var hexString = ""
        for byte in bytes {
            hexString += String(format:"%02x", UInt8(byte))
        }
        
        return hexString
    }
}

public extension String {
    func sha256() -> String{
        if let stringData = self.data(using: String.Encoding.utf8) {
            return stringData.sha256()
        }
        return ""
    }
}

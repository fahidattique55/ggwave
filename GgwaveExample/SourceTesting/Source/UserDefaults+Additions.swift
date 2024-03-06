//
//  UserDefaults+Additions.swift
//  ObjcTest
//
//  Created by fahid on 27/07/2021.
//

import Foundation

let defaults = UserDefaults.standard
extension UserDefaults {

    var savedMessages: [Message] {
        var messages = [Message]()
        savedMessagesAsString.forEach { (jsonString) in
            if let message = Message(JSONString: jsonString) {
                messages.append(message)
            }
        }
        return messages
    }
    
    private var savedMessagesAsString: [String] {
        get {
            if let messages = self.value(forKey: "savedMessagesAsString") as? [String] {
                return messages
            }
            return []
        }
        set {
            self.setValue(newValue, forKey: "savedMessagesAsString")
            self.synchronize()
        }
    }

    func save(message: Message) {
        
        guard let messageAsString = message.toJSONString() else { return }
        savedMessagesAsString.append(messageAsString)
    }
    
    func removeAllMessages() {
        savedMessagesAsString = []
    }
    
    
    //  Click handling local messages
    
    var clickedMessages: [Message] {
        var messages = [Message]()
        clickedMessagesAsString.forEach { (jsonString) in
            if let message = Message(JSONString: jsonString) {
                messages.append(message)
            }
        }
        return messages
    }
    
    private var clickedMessagesAsString: [String] {
        get {
            if let messages = self.value(forKey: "clickedMessagesAsString") as? [String] {
                return messages
            }
            return []
        }
        set {
            self.setValue(newValue, forKey: "clickedMessagesAsString")
            self.synchronize()
        }
    }

    func save(clickedMessage: Message) {
        
        guard let messageAsString = clickedMessage.toJSONString() else { return }
        clickedMessagesAsString.append(messageAsString)
    }
    
    func removeAllClickedMessages() {
        clickedMessagesAsString = []
    }
}


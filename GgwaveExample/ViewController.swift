//
//  ViewController.swift
//  GgwaveExample
//
//  Created by Fahid Attique on 06/03/2024.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.startDecoder()
    }

    func startDecoder() {
        
        UltrasonicDecoder.shared.startDecodingFromCordova()
        print("startDecoder() called")
    }
    
    func stopDecoder() {
        
        UltrasonicDecoder.shared.stopDecoder()
        print("stopDecoder() called")
    }
}


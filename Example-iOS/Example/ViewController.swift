//
//  ViewController.swift
//  Example
//
//  Created by Dylan Gyesbreghs on 14/04/16.
//  Copyright © 2016 Dylan Gyesbreghs. All rights reserved.
//

import UIKit
import HRMManager

class ViewController: UIViewController, HRMManagerDelegate {

    let heartRateManager = HRMManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        heartRateManager.delegate = self
        heartRateManager.startScan()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func didConnect() {
        print("Did Connect to HRM")
    }
    
    func didDisconnect() {
        print("Did Disconnect to HRM")
    }
    
    func didUpdateHeartRate(heartRate: UInt8, error: NSError?) {
        print("BPM: \(heartRate)")
    }
    
    func didUpdateDeviceInfo(info: String, error: NSError?) {
        print("Device Name: \(info)")
    }
    
    func didFoundHeartRateMonitors(monitors: [String]) {
        if let monitor = monitors.first {
            heartRateManager.connectToHeartRateMonitor(monitor)
        }
    }
    
    func didFoundBodyLocation(location: String, error: NSError?) {
        print("Body Location: \(location)")
    }
}


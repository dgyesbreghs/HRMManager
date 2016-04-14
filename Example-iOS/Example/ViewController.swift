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
        
    }
    
    func didDisconnect() {
        
    }
    
    func didUpdateHeartRate(heartRate: UInt8, error: NSError?) {
        
    }
    
    func didUpdateDeviceInfo(info: String, error: NSError?) {
        
    }
    
    func didFoundHeartRateMonitors(monitors: [String]) {
        
    }
    
    func didFoundBodyLocation(location: String, error: NSError?) {
        
    }
}


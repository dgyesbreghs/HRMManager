//
//  HRMManager.swift
//  HRMManager
//
//  Created by Dylan Gyesbreghs on 13/04/16.
//  Copyright © 2016 Dylan Gyesbreghs. All rights reserved.
//

import CoreBluetooth

class HRMManagerConstants {
    static let HRM_DEVICE_INFO_SERVICE_UUID = "180A"
    static let HRM_HEART_RATE_SERVICE_UUID = "180D"
    static let HRM_MEASUREMENT_CHARACTERISTIC_UUID = "2A37"
    static let HRM_BODY_LOCATION_CHARACTERISTIC_UUID = "2A38"
    static let HRM_MANUFACTURER_NAME_CHARACTERISTIC_UUID = "2A29"
}

public protocol HRMManagerDelegate {
    func didFoundHeartRateMonitors(monitors : [String])
    func didUpdateHeartRate(heartRate : UInt8, error : NSError?)
    func didUpdateDeviceInfo(info : String, error : NSError?)
    func didFoundBodyLocation(location : String, error : NSError?)
    func didConnect()
    func didDisconnect()
}

public class HRMManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    public var delegate : HRMManagerDelegate?
    
    private var monitors = [String : CBPeripheral]()
    private var centralManager : CBCentralManager?
    private var internalPeripheral : CBPeripheral?
    private var debug = false
    
    /**
     Init
     */
    public override init() {
        super.init()
    }
    
    /**
     Start scanning for devices
     */
    public func startScan() {
        self.centralManager = CBCentralManager(delegate: self, queue: dispatch_get_main_queue())
    }
    
    /**
     Connect to a certain HRM device.
     
     @param name A string used to identify the HRM in this dictionary.
     */
    public func connectToHeartRateMonitor(name : String) {
        if !name.isEmpty {
            if let peripheral = self.monitors[name] {
                showDebugInfo("[INFO] Connectign to Heart Rate Monitor: \(name)")
                stopScan()
                self.internalPeripheral = peripheral
                self.internalPeripheral!.delegate = self
                self.centralManager!.connectPeripheral(self.internalPeripheral!, options: nil)
            }
        }
    }
    
    /**
     Stop scanning for devices
     */
    public func stopScan() {
        self.centralManager?.stopScan()
    }
    
    /**
     Enable the debugging info.
     This is helphul if something goes wrong.
     */
    public func enableDebugging() {
        self.debug = true
    }
    
    /**
     Disable the debugging info.
     This is helphul if you're app is in production.
     */
    public func disableDebugging() {
        self.debug = false
    }
    
    // MARK: CBCentralManagerDelegate Methods
    @objc public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        showDebugInfo("[INFO] Did Connect to Peripheral: \(peripheral.name)")
        self.delegate?.didConnect()
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    @objc public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as! String
        if !name.isEmpty {
            showDebugInfo("[INFO] Found Heart Rate Monitor: \(name)")
            self.monitors[name] = peripheral
            self.delegate?.didFoundHeartRateMonitors(Array(self.monitors.keys))
        }
    }
    
    @objc public func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == .PoweredOn {
            showDebugInfo("[INFO] Update state to: Powered On")
            let services = [CBUUID.init(string: HRMManagerConstants.HRM_HEART_RATE_SERVICE_UUID)]
            self.centralManager?.scanForPeripheralsWithServices(services, options: nil)
        }
    }
    
    // MARK: CBPeripheralDelegate Methods
    @objc public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if let services = peripheral.services {
            for service in services {
                showDebugInfo("[INFO] Did discover service: \(service)")
                peripheral.discoverCharacteristics(nil, forService: service)
            }
        }
    }
    
    @objc public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if service.UUID.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_HEART_RATE_SERVICE_UUID)) {
            if let characteristics = service.characteristics {
                for aChar in characteristics {
                    showDebugInfo("[INFO] Did discover characteristics service: \(aChar)")
                    if aChar.UUID.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_MEASUREMENT_CHARACTERISTIC_UUID)) {
                        self.internalPeripheral?.setNotifyValue(true, forCharacteristic: aChar)
                    } else if aChar.UUID.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_BODY_LOCATION_CHARACTERISTIC_UUID)) {
                        self.internalPeripheral?.readValueForCharacteristic(aChar)
                    }
                }
            }
        }
        
        if service.UUID.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_DEVICE_INFO_SERVICE_UUID)) {
            if let characteristics = service.characteristics {
                for aChar in characteristics {
                    showDebugInfo("[INFO] Found a device Manufacture name: \(aChar)")
                    if aChar.UUID.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_MANUFACTURER_NAME_CHARACTERISTIC_UUID)) {
                        self.internalPeripheral?.readValueForCharacteristic(aChar)
                    }
                }
            }
        }
    }
    
    @objc public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if characteristic.UUID.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_MEASUREMENT_CHARACTERISTIC_UUID)) {
            self.calculateHeartRate(characteristic, error: error)
        }
        
        if characteristic.UUID.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_BODY_LOCATION_CHARACTERISTIC_UUID)) {
            self.renderBodyLocation(characteristic, error: error)
        }
        
        if characteristic.UUID.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_MANUFACTURER_NAME_CHARACTERISTIC_UUID)) {
            self.renderManufactureName(characteristic, error: error)
        }
    }
    
    @objc public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.delegate?.didDisconnect()
    }
    
    // MARK: Private Methods
    private func calculateHeartRate(characteristic: CBCharacteristic, error : NSError?) {
        if error == nil {
            if let data = characteristic.value {
                let reportData = UnsafePointer<UInt8>(data.bytes)
                self.delegate?.didUpdateHeartRate(reportData[1], error: error)
            }
        } else {
            self.delegate?.didUpdateHeartRate(0, error: error)
        }
    }
    
    private func renderBodyLocation(characteristic: CBCharacteristic, error : NSError?) {
        if error == nil {
            if let data = characteristic.value {
                let bodyData = UnsafePointer<UInt8>(data.bytes)
                var location = "Undefined"
                if bodyData[0] == 0 {
                    location = "Chest"
                }
                self.delegate?.didFoundBodyLocation(location, error: nil)
                
            }
        } else {
            self.delegate?.didFoundBodyLocation("", error: error)
        }
    }
    
    private func renderManufactureName(characteristic: CBCharacteristic, error : NSError?) {
        if error == nil {
            if let data = characteristic.value {
                if let name = String(data: data, encoding: NSUTF8StringEncoding) {
                    self.delegate?.didUpdateDeviceInfo(name, error: nil)
                }
            }
        } else {
            self.delegate?.didUpdateDeviceInfo("", error: error)
        }
    }
    
    private func showDebugInfo(debugInfo : String) {
        if debug {
            print(debugInfo)
        }
    }
}
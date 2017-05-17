//
//  HRMManager.swift
//  HRMManager
//
//  Created by Dylan Gyesbreghs on 13/04/16.
//  Copyright © 2016 Dylan Gyesbreghs. All rights reserved.
//

import CoreBluetooth

struct HRMManagerConstants {
    static let HRM_DEVICE_INFO_SERVICE_UUID = "180A"
    static let HRM_HEART_RATE_SERVICE_UUID = "180D"
    static let HRM_MEASUREMENT_CHARACTERISTIC_UUID = "2A37"
    static let HRM_BODY_LOCATION_CHARACTERISTIC_UUID = "2A38"
    static let HRM_MANUFACTURER_NAME_CHARACTERISTIC_UUID = "2A29"
}

public protocol HRMManagerDelegate {
    func didFoundHeartRateMonitors(_ monitors : [String])
    func didUpdateHeartRate(_ heartRate : UInt8, error : NSError?)
    func didUpdateDeviceInfo(_ info : String, error : NSError?)
    func didFoundBodyLocation(_ location : String, error : NSError?)
    func didConnect()
    func didDisconnect()
}

open class HRMManager: NSObject {
    open var delegate : HRMManagerDelegate?
    
    fileprivate var monitors = [String : CBPeripheral]()
    fileprivate var centralManager : CBCentralManager?
    fileprivate var internalPeripheral : CBPeripheral?
    fileprivate var debug = false
    
    /**
     Init
     */
    public override init() {
        super.init()
    }
    
    /**
     Start scanning for devices
     */
    open func startScan() {
        self.centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
    
    /**
     Connect to a certain HRM device.
     
     @param name A string used to identify the HRM in this dictionary.
     */
    open func connectToHeartRateMonitor(_ name : String) {
        if !name.isEmpty {
            if let peripheral = self.monitors[name] {
                showDebugInfo("[INFO] Connecting to Heart Rate Monitor: \(name)")
                stopScan()
                self.internalPeripheral = peripheral
                self.internalPeripheral!.delegate = self
                self.centralManager!.connect(self.internalPeripheral!, options: nil)
            }
        }
    }
    
    /**
     Stop scanning for devices
     */
    open func stopScan() {
        self.centralManager?.stopScan()
    }
    
    /**
     Enable the debugging info.
     This is helphul if something goes wrong.
     */
    open func enableDebugging() {
        self.debug = true
    }
    
    /**
     Disable the debugging info.
     This is helphul if you're app is in production.
     */
    open func disableDebugging() {
        self.debug = false
    }
    
    // MARK: Private Methods
    fileprivate func calculateHeartRate(_ characteristic: CBCharacteristic, error : NSError?) {
        if error == nil {
            if let data = characteristic.value {
                let reportData = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)
                self.delegate?.didUpdateHeartRate(reportData[1], error: error)
            }
        } else {
            self.delegate?.didUpdateHeartRate(0, error: error)
        }
    }
    
    fileprivate func renderBodyLocation(_ characteristic: CBCharacteristic, error : NSError?) {
        if error == nil {
            if let data = characteristic.value {
                let bodyData = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)
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
    
    fileprivate func renderManufactureName(_ characteristic: CBCharacteristic, error : NSError?) {
        if error == nil {
            if let data = characteristic.value {
                if let name = String(data: data, encoding: String.Encoding.utf8) {
                    self.delegate?.didUpdateDeviceInfo(name, error: nil)
                }
            }
        } else {
            self.delegate?.didUpdateDeviceInfo("", error: error)
        }
    }
    
    fileprivate func showDebugInfo(_ debugInfo : String) {
        if debug {
            print(debugInfo)
        }
    }
}

// MARK: CBCentralManagerDelegate
extension HRMManager: CBCentralManagerDelegate {
    @objc open func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        showDebugInfo("[INFO] Did Connect to Peripheral: \(String(describing: peripheral.name))")
        self.delegate?.didConnect()
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    @objc open func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as! String
        if !name.isEmpty {
            showDebugInfo("[INFO] Found Heart Rate Monitor: \(name)")
            self.monitors[name] = peripheral
            self.delegate?.didFoundHeartRateMonitors(Array(self.monitors.keys))
        }
    }
    
    @objc open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            showDebugInfo("[INFO] Update state to: Powered On")
            let services = [CBUUID.init(string: HRMManagerConstants.HRM_HEART_RATE_SERVICE_UUID)]
            self.centralManager?.scanForPeripherals(withServices: services, options: nil)
        }
    }
}

// MARK: CBPeripheralDelegate
extension HRMManager: CBPeripheralDelegate {
    @objc open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                showDebugInfo("[INFO] Did discover service: \(service)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    @objc open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if service.uuid.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_HEART_RATE_SERVICE_UUID)) {
            if let characteristics = service.characteristics {
                for aChar in characteristics {
                    showDebugInfo("[INFO] Did discover characteristics service: \(aChar)")
                    if aChar.uuid.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_MEASUREMENT_CHARACTERISTIC_UUID)) {
                        self.internalPeripheral?.setNotifyValue(true, for: aChar)
                    } else if aChar.uuid.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_BODY_LOCATION_CHARACTERISTIC_UUID)) {
                        self.internalPeripheral?.readValue(for: aChar)
                    }
                }
            }
        }
        
        if service.uuid.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_DEVICE_INFO_SERVICE_UUID)) {
            if let characteristics = service.characteristics {
                for aChar in characteristics {
                    showDebugInfo("[INFO] Found a device Manufacture name: \(aChar)")
                    if aChar.uuid.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_MANUFACTURER_NAME_CHARACTERISTIC_UUID)) {
                        self.internalPeripheral?.readValue(for: aChar)
                    }
                }
            }
        }
    }
    
    @objc open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_MEASUREMENT_CHARACTERISTIC_UUID)) {
            self.calculateHeartRate(characteristic, error: error as NSError?)
        }
        
        if characteristic.uuid.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_BODY_LOCATION_CHARACTERISTIC_UUID)) {
            self.renderBodyLocation(characteristic, error: error as NSError?)
        }
        
        if characteristic.uuid.isEqual(CBUUID.init(string: HRMManagerConstants.HRM_MANUFACTURER_NAME_CHARACTERISTIC_UUID)) {
            self.renderManufactureName(characteristic, error: error as NSError?)
        }
    }
    
    @objc open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.delegate?.didDisconnect()
    }
}

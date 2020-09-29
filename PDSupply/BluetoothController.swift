//
//  BluetoothController.swift
//  PDSupply
//
//  Created by Zain Ahmed on 4/26/20.
//  Copyright © 2020 Captio Labs. All rights reserved.
//

import Foundation
import CoreBluetooth
import SwiftUI
import Combine

public class BluetoothController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {
    
    // Shared singleton
    static let shared = BluetoothController();
    
    // Possible values for SupplyData_struct.status in firmware
    public let PD_STATUS_OUTPUT_GOOD: UInt32 = 0x0A
    public let PD_STATUS_OUTPUT_OFF: UInt32 = 0x0B
    public let PD_STATUS_OUTPUT_OVERCURRENT: UInt32 = 0x0C
    public let PD_STATUS_OUTPUT_HIGH: UInt32 = 0x0D
    public let PD_STATUS_OUTPUT_LOW: UInt32 = 0x0E
    
    // Possible values for MasterData_struct_struct.commandedStatus in firmware
    public let PD_COMMAND_OUTPUT_ON: UInt32 = 0x1A
    public let PD_COMMAND_OUTPUT_OFF: UInt32 = 0x1B
    public let PD_COMMAND_OUTPUT_KEEP_STATE: UInt32 = 0x1C
    public let PD_COMMAND_LED_ON: UInt32 = 0x1D
    public let PD_COMMAND_LED_OFF: UInt32 = 0x1E
    
    // Power Supply Data Arrays
    @Published var voltageData: [Double] = [0]
    @Published var currentData: [Double] = [0]
    @Published var statusData: UInt32 = 0x0B
    @Published var counterData: [UInt32] = [0]
    
    // Shortened arrays for graph performance
    @Published var voltageDataShort: [Double] = Array(repeating: 0, count: 100)
    @Published var currentDataShort: [Double] = Array(repeating: 0, count: 100)
    
    // Latest Values
    @Published var latestVoltage: Double = 0;
    @Published var latestCurrent: Double = 0;
    
    let pdsupplyName = "PDSupply Solo"
    let serviceUUID = CBUUID(string: "F3641400-00B0-4240-BA50-05CA45BF8ABC")
    let characteristicUUID = CBUUID(string: "F3641401-00B0-4240-BA50-05CA45BF8ABC")
    var dataCharacteristic: CBCharacteristic! = nil
    
    var manager: CBCentralManager!
    var mainService: CBService! = nil
    var peripheral: CBPeripheral!
    
    @Published var connected = false
    
    required override init() {
        super.init()
        manager = CBCentralManager(delegate: self, queue: nil)
    }
    
    public func commandSupply(commandedStatus: UInt32, commandedOutput: UInt32, commandedVoltage: Float32, commandedCurrent: Float32) {
        
        // Mutable values required for passing as pointers
        var _commandedStatus: UInt32 = commandedStatus
        var _commandedOutput: UInt32 = commandedOutput
        var _commandedVoltage: Float32 = commandedVoltage
        var _commandedCurrent: Float32 = commandedCurrent
        // Output data buffer
        var outputData: Array<UInt8> = Array(repeating: 0, count: 16)
        
        memcpy(&outputData, &_commandedStatus, 4)
        memcpy(&outputData[4], &_commandedOutput, 4)
        memcpy(&outputData[8], &_commandedVoltage, 4)
        memcpy(&outputData[12], &_commandedCurrent, 4)
        
        if (connected) {
            self.peripheral.writeValue(Data(outputData), for: dataCharacteristic, type: .withResponse)
        }
    }
    
    // BLE Controller
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
            print("scanning")
        } else {
            print("bluetooth not available")
        }
    }
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("State updated")
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == pdsupplyName {
            self.peripheral = peripheral
            central.connect(peripheral, options: nil)
            central.stopScan()
            print("PDSupply Found!")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected")
        peripheral.delegate = self
        self.peripheral.discoverServices([serviceUUID])
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("service discovered")
        
        guard let services = peripheral.services else{
            print("services not found")
            return
        }
        
        for service in services {
            if service.uuid == serviceUUID {
                print("found Power Supply protocol Service")
                mainService = service
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("characteristics discovered")
        
        for characteristic in service.characteristics! {
            if characteristic.uuid == characteristicUUID {
                self.dataCharacteristic = characteristic
                self.peripheral.setNotifyValue(true, for: characteristic)
                
                connected = true
                
                // Disable Output
                print("Voltage and Current Zeroed")
                commandSupply(commandedStatus: PD_COMMAND_OUTPUT_OFF, commandedOutput: 0, commandedVoltage: 0, commandedCurrent: 0)
                print("Successfully Paired with PDSupply")
            }
        }
    }
    
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        connected = false;
        
        if central.state == CBManagerState.poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
            print("scanning")
        } else {
            print("bluetooth not available")
        }
    }
    
    let statusValues = ["IDLE", "ACTIVE", "CURRENTLIMITED", "ERROR" , "TESTING"]
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let data = characteristic.value
        
        var test: Array<UInt8> = Array(repeating: 0, count: 64)
        
        if (data != nil) {
            data?.copyBytes(to: &test, count: 64)
            
            var voltage: Float32 = 0;
            var counter: UInt32 = 0;
            var status : UInt32 = 0;
            var current : Float32 = 0;
            
            // TODO: Fix temp pointer warning
            memcpy(&counter, &test, MemoryLayout.size(ofValue: counter))
            memcpy(&status, &test[4], MemoryLayout.size(ofValue: status))
            memcpy(&voltage, &test[8], MemoryLayout.size(ofValue: voltage))
            memcpy(&current, &test[12], MemoryLayout.size(ofValue: current))
            
            counterData.append(counter)
            statusData = status
            voltageData.append(Double(voltage)) // Values come in as a float but the chart library requires a Double
            currentData.append(Double(current))
            
            latestVoltage = Double(voltage)
            latestCurrent = Double(current)
            
            if currentData.count > 100 {
                for i in 0...99 {
                    currentDataShort[i] = Double(currentData[currentData.count - (100 - i)])
                    voltageDataShort[i] = Double(voltageData[voltageData.count - (100 - i)])
                }
            } else {
                currentDataShort = currentData
                voltageDataShort = voltageData
            }
            
            currentDataShort[0] = 0
            voltageDataShort[0] = 0
            
            //                        print("Status: " + String(status) + "\t\t" + "Counter: " + String(counter) + "\t\t" + "Measured mA: " + String(current) + "\t\t" + "Measured Voltage: " + String(voltage))
        }
    }
    
    public func disconnect() {
        manager.cancelPeripheralConnection(peripheral)
    }
}

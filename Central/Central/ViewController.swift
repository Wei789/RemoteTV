//
//  ViewController.swift
//  Central
//
//  Created by 鄭惟臣 on 06/02/2018.
//  Copyright © 2018 鄭惟臣. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {
    
    var centralManager: CBCentralManager!
    var connectPeripheral: CBPeripheral!
    var charDictionary = [String:CBCharacteristic]()
    @IBOutlet weak var urlTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let queue = DispatchQueue.global()
        // 1
        centralManager = CBCentralManager(delegate: self, queue: queue)
        
    }
    
    @IBAction func confirmURLButtonPressed(_ sender: UIButton) {
        if let url = urlTextField.text {
            sendData(url.data(using: .utf8)!, uuidString: "C001", writeType: .withoutResponse)
            view.endEditing(true)
        }
    }
    
    @IBAction func operationButtonPressed(_ sender: UIButton) {
        let opertion = String(sender.tag)
        sendData(opertion.data(using: .utf8)!, uuidString: "C001", writeType: .withoutResponse)
    }
}

extension ViewController: CBCentralManagerDelegate, CBPeripheralDelegate{
    // 1
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            return
        }
        
        if isPaired() {
            // 3
            centralManager.connect(connectPeripheral, options: nil)
        } else {
            // 2
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    // 2
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("找到藍牙裝置: \(peripheral.name ?? "")")
        
        guard peripheral.name != nil else {
            return
        }
        
        guard peripheral.name == "我的裝置" else {
            return
        }
        
        central.stopScan()
        
        let user = UserDefaults.standard
        user.set(peripheral.identifier.uuidString, forKey: "KEY_PERIPHERAL_UUID")
        user.synchronize()
        
        connectPeripheral = peripheral
        connectPeripheral.delegate = self
        
        // 3
        centralManager.connect(connectPeripheral, options: nil)
    }
    
    // 3
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        charDictionary = [:]
        // 4
        peripheral.discoverServices(nil)
    }
    
    // 4
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("error")
            return
        }
        
        for service in peripheral.services! {
            // 5
            connectPeripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // 5
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("error")
            return
        }
        
        for characteristic in service.characteristics! {
            let uuidString = characteristic.uuid.uuidString
            charDictionary[uuidString] = characteristic
            print("找到: \(uuidString)")
        }
    }
    
    // 送資料到peripheral
    func sendData(_ data: Data, uuidString: String, writeType: CBCharacteristicWriteType) {
        guard let charateristic = charDictionary[uuidString] else {
            return
        }
        
        //withResponse wait til time out if peripheral no feedback
        connectPeripheral.writeValue(data, for: charateristic, type: writeType)
    }
    
    // 斷線處理
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("連線中斷")
        if isPaired() {
            // retry until connect success
            centralManager.connect(connectPeripheral, options: nil)
        }
    }
    
    private func isPaired() -> Bool {
        let user = UserDefaults.standard
        if let uuidString = user.string(forKey: "KEY_PERIPHERAL_UUID") {
            let uuid = UUID(uuidString: uuidString)
            let list = centralManager.retrievePeripherals(withIdentifiers: [uuid!])
            if list.count > 0 {
                connectPeripheral = list.first!
                connectPeripheral.delegate = self
                return true
            }
        }
        
        return false
    }
    
    private func unpair() {
        let user  = UserDefaults.standard
        user.removeObject(forKey: "KEY_PERIPHERAL_UUID")
        user.synchronize()
        centralManager.cancelPeripheralConnection(connectPeripheral)
    }
}

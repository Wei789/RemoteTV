//
//  ViewController.swift
//  Peripheral
//
//  Created by 鄭惟臣 on 05/02/2018.
//  Copyright © 2018 鄭惟臣. All rights reserved.
//

import Cocoa
import CoreBluetooth
import WebKit

class ViewController: NSViewController, CBPeripheralManagerDelegate, WKNavigationDelegate {
    
    @IBOutlet weak var webView: WKWebView!
    
    let UUID_SERVICE = "A001"
    let UUID_CHARACTERISTIC = "C001"
    var peripheralManager: CBPeripheralManager!
    var charDictionary = [String:CBMutableCharacteristic]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 在另外一個執行緒中執行
        let queue = DispatchQueue.global()
        peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
        
        webView.navigationDelegate = self
        
        self.view.window?.setFrame(NSRect(x:0, y:0, width: 2560,height: 1600), display: true)
    }
    
    private func play() {
        // space
        touchUpEvent(keyCode: 49, flags: nil)
    }
    
    private func next() {
        // shift + n
        touchUpEvent(keyCode: 45, flags: CGEventFlags.maskShift)
    }
    
    private func previous() {
        // shift + p
        touchUpEvent(keyCode: 35, flags: CGEventFlags.maskShift)
    }
    
    private func tab() {
        touchUpEvent(keyCode: 48, flags: nil)
    }
    
    private func touchUpEvent(keyCode: Int16, flags: CGEventFlags?) {
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode.init (bitPattern: keyCode) , keyDown: true)
        if let flags = flags {
            keyDownEvent?.flags = flags
        }
        
        keyDownEvent?.post(tap: CGEventTapLocation.cghidEventTap)
        
        let KeyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode.init (bitPattern: keyCode), keyDown: false)
        if let flags = flags {
            KeyUpEvent?.flags = flags
        }
        
        KeyUpEvent?.post(tap: CGEventTapLocation.cghidEventTap)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Click tab button for get the focus on youtube
        tab()
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // 會判斷藍芽是否開啟，如果不是藍芽4.X，會傳回未開啟
        guard peripheral.state == .poweredOn else {
            // iOS 會出現對話筐提醒使用者
            return
        }
        
        var service: CBMutableService
        var characteristic: CBMutableCharacteristic
        var charArray = [CBCharacteristic]()
        
        service = CBMutableService(type: CBUUID(string: UUID_SERVICE), primary: true)
        characteristic = CBMutableCharacteristic(
            type: CBUUID(string: UUID_CHARACTERISTIC),
            properties: [.notifyEncryptionRequired, .writeWithoutResponse],
            value: nil,
            permissions: [.writeEncryptionRequired, .readable])
        
        charArray.append(characteristic)
        charDictionary[UUID_CHARACTERISTIC] = characteristic
        
        service.characteristics = charArray
        // 1
        peripheralManager.add(service)
    }
    
    // 1
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            print("error")
            return
        }
        
        let deviceName = "我的裝置"
        // 開始廣播讓central端可以找到這裝置
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[service.uuid],
                                     CBAdvertisementDataLocalNameKey: deviceName])
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("開始廣播")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        if peripheral.isAdvertising {
            peripheral.stopAdvertising()
            print("停止廣播")
        }
        
        if characteristic.uuid.uuidString == UUID_CHARACTERISTIC {
            
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if characteristic.uuid.uuidString == UUID_CHARACTERISTIC {
            
        }
    }
    
    func sendData(_ data: Data, uuidString: String) {
        guard let characteristic = charDictionary[uuidString] else {
            print("device Not Found")
            return
        }
        
        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let at = requests.first else {
            return
        }
        
        guard let data = at.value else {
            return
        }
        
        DispatchQueue.main.async {
            let string = String(data: data, encoding: .utf8)!
            if let opertionType = TVOperation.init(rawValue: string)
            {
                switch opertionType {
                case .previous:
                    self.previous()
                case .Play:
                    self.play()
                case .next:
                    self.next()
                case .tab:
                    self.tab()
                }
            } else {
                var urlString: String = "https://www.youtube.com/embed/"
                if string.contains("list") {
                    urlString = urlString + URL(fileURLWithPath: string).lastPathComponent + "&autoplay=1"
                } else {
                    urlString = urlString + URL(fileURLWithPath: string).lastPathComponent + "?autoplay=1"
                }
                
                let url = NSURL(string: urlString)
                let urlRequest = URLRequest(url: url! as URL)
                self.webView.load(urlRequest)
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    enum TVOperation: String {
        case previous = "0"
        case Play = "1"
        case next = "2"
        case tab = "3"
    }
}


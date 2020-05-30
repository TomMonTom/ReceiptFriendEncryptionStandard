//
//  Extensions.swift
//  ReceiptFriend
//
//  Created by THOMAS THOMPSON on 8/28/19.
//  Copyright © 2019 THOMAS THOMPSON. All rights reserved.
//

import Foundation
import UIKit
import CommonCrypto
import AVFoundation
protocol Cryptable {
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}

struct AES {
    private let key: Data
    private let ivSize: Int         = kCCBlockSizeAES128
    private let options: CCOptions  = CCOptions(kCCOptionPKCS7Padding)
    
    init(keyString: String) throws {
        guard keyString.count == kCCKeySizeAES256 else {
            //NSLog("throwing error...")
            throw Error.invalidKeySize
        }
        self.key = Data(keyString.utf8)
    }
    init(keyString: Data) throws {
//        guard keyString.count == kCCKeySizeAES256 else {
//            //NSLog("throwing error...")
//            throw Error.invalidKeySize
//        }
        self.key = keyString
    }
}

extension AES {
    enum Error: Swift.Error {
        case invalidKeySize
        case generateRandomIVFailed
        case encryptionFailed
        case decryptionFailed
        case dataToStringFailed
    }
}

private extension AES {
    
    func generateRandomIV(for data: inout Data) throws {
        
        try data.withUnsafeMutableBytes { dataBytes in
            
            guard let dataBytesBaseAddress = dataBytes.baseAddress else {
                throw Error.generateRandomIVFailed
            }
            
            let status: Int32 = SecRandomCopyBytes(
                kSecRandomDefault,
                kCCBlockSizeAES128,
                dataBytesBaseAddress
            )
            
            guard status == 0 else {
                throw Error.generateRandomIVFailed
            }
        }
    }
}
extension Double {
    var clean: String {
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }
}
extension AES: Cryptable {
    
    func encrypt(_ data: Data) throws -> Data {
        let dataToEncrypt = data
        
        let bufferSize: Int = ivSize + dataToEncrypt.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        try generateRandomIV(for: &buffer)
        
        var numberBytesEncrypted: Int = 0
        
        do {
            try key.withUnsafeBytes { keyBytes in
                try dataToEncrypt.withUnsafeBytes { dataToEncryptBytes in
                    try buffer.withUnsafeMutableBytes { bufferBytes in
                        
                        guard let keyBytesBaseAddress = keyBytes.baseAddress,
                            let dataToEncryptBytesBaseAddress = dataToEncryptBytes.baseAddress,
                            let bufferBytesBaseAddress = bufferBytes.baseAddress else {
                                throw Error.encryptionFailed
                        }
                        
                        let cryptStatus: CCCryptorStatus = CCCrypt( // Stateless, one-shot encrypt operation
                            CCOperation(kCCEncrypt),                // op: CCOperation
                            CCAlgorithm(kCCAlgorithmAES),           // alg: CCAlgorithm
                            options,                                // options: CCOptions
                            keyBytesBaseAddress,                    // key: the "password"
                            key.count,                              // keyLength: the "password" size
                            bufferBytesBaseAddress,                 // iv: Initialization Vector
                            dataToEncryptBytesBaseAddress,          // dataIn: Data to encrypt bytes
                            dataToEncryptBytes.count,               // dataInLength: Data to encrypt size
                            bufferBytesBaseAddress + ivSize,        // dataOut: encrypted Data buffer
                            bufferSize,                             // dataOutAvailable: encrypted Data buffer size
                            &numberBytesEncrypted                   // dataOutMoved: the number of bytes written
                        )
                        
                        guard cryptStatus == CCCryptorStatus(kCCSuccess) else {
                            throw Error.encryptionFailed
                        }
                    }
                }
            }
            
        } catch {
            throw Error.encryptionFailed
        }
        
        let encryptedData: Data = buffer[..<(numberBytesEncrypted + ivSize)]
        return encryptedData
    }
    
    func decrypt(_ data: Data) throws -> Data {
        
        let bufferSize: Int = data.count - ivSize
        var buffer = Data(count: bufferSize)
        
        var numberBytesDecrypted: Int = 0
        
        do {
            try key.withUnsafeBytes { keyBytes in
                try data.withUnsafeBytes { dataToDecryptBytes in
                    try buffer.withUnsafeMutableBytes { bufferBytes in
                        
                        guard let keyBytesBaseAddress = keyBytes.baseAddress,
                            let dataToDecryptBytesBaseAddress = dataToDecryptBytes.baseAddress,
                            let bufferBytesBaseAddress = bufferBytes.baseAddress else {
                                throw Error.encryptionFailed
                        }
                        
                        let cryptStatus: CCCryptorStatus = CCCrypt( // Stateless, one-shot encrypt operation
                            CCOperation(kCCDecrypt),                // op: CCOperation
                            CCAlgorithm(kCCAlgorithmAES128),        // alg: CCAlgorithm
                            options,                                // options: CCOptions
                            keyBytesBaseAddress,                    // key: the "password"
                            key.count,                              // keyLength: the "password" size
                            dataToDecryptBytesBaseAddress,          // iv: Initialization Vector
                            dataToDecryptBytesBaseAddress + ivSize, // dataIn: Data to decrypt bytes
                            bufferSize,                             // dataInLength: Data to decrypt size
                            bufferBytesBaseAddress,                 // dataOut: decrypted Data buffer
                            bufferSize,                             // dataOutAvailable: decrypted Data buffer size
                            &numberBytesDecrypted                   // dataOutMoved: the number of bytes written
                        )
                        
                        guard cryptStatus == CCCryptorStatus(kCCSuccess) else {
                            throw Error.decryptionFailed
                        }
                    }
                }
            }
        } catch {
            throw Error.encryptionFailed
        }
        
        let decryptedData: Data = buffer[..<numberBytesDecrypted]
        
//        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
//            throw Error.dataToStringFailed
//        }
        
        return decryptedData
    }
}
//https://stackoverflow.com/questions/25388747/sha256-in-swift
extension Data {
    
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    var sha256: Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes({
            _ = CC_SHA256($0, CC_LONG(self.count), &digest)
        })
        return Data(digest)
    }
    
}

extension String {
    
    func sha256(salt: String) -> Data {
        return (self + salt).data(using: .utf8)!.sha256
    }
    
}
/// Defines UI-related utilitiy methods for vision detection.
public class UIUtilities {
    
    // MARK: - Public
    
    public static func addCircle(
        atPoint point: CGPoint,
        to view: UIView,
        color: UIColor,
        radius: CGFloat
        ) {
        let divisor: CGFloat = 2.0
        let xCoord = point.x - radius / divisor
        let yCoord = point.y - radius / divisor
        let circleRect = CGRect(x: xCoord, y: yCoord, width: radius, height: radius)
        let circleView = UIView(frame: circleRect)
        circleView.layer.cornerRadius = radius / divisor
        circleView.alpha = Constants.circleViewAlpha
        circleView.backgroundColor = color
        view.addSubview(circleView)
    }
    
    public static func addRectangle(_ rectangle: CGRect, to view: UIView, color: UIColor) {
        let rectangleView = UIView(frame: rectangle)
        rectangleView.layer.cornerRadius = Constants.rectangleViewCornerRadius
        rectangleView.alpha = Constants.rectangleViewAlpha
        rectangleView.backgroundColor = color
        view.addSubview(rectangleView)
    }
    
    public static func addShape(withPoints points: [NSValue]?, to view: UIView, color: UIColor) {
        guard let points = points else { return }
        let path = UIBezierPath()
        for (index, value) in points.enumerated() {
            let point = value.cgPointValue
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
            if index == points.count - 1 {
                path.close()
            }
        }
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = color.cgColor
        let rect = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
        let shapeView = UIView(frame: rect)
        shapeView.alpha = Constants.shapeViewAlpha
        shapeView.layer.addSublayer(shapeLayer)
        view.addSubview(shapeView)
    }
    
    public static func imageOrientation(
        fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
        ) -> UIImage.Orientation {
        var deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .faceDown || deviceOrientation == .faceUp ||
            deviceOrientation == .unknown {
            deviceOrientation = currentUIOrientation()
        }
        switch deviceOrientation {
        case .portrait:
            return devicePosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return devicePosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return devicePosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return devicePosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        }
    }
    
//    public static func visionImageOrientation(
//        from imageOrientation: UIImage.Orientation
//        ) -> VisionDetectorImageOrientation {
//        switch imageOrientation {
//        case .up:
//            return .topLeft
//        case .down:
//            return .bottomRight
//        case .left:
//            return .leftBottom
//        case .right:
//            return .rightTop
//        case .upMirrored:
//            return .topRight
//        case .downMirrored:
//            return .bottomLeft
//        case .leftMirrored:
//            return .leftTop
//        case .rightMirrored:
//            return .rightBottom
//        }
//    }
    
    // MARK: - Private
    
    private static func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .portrait, .unknown:
                return .portrait
            }
        }
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            DispatchQueue.main.sync {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
}

// MARK: - Constants

private enum Constants {
    static let circleViewAlpha: CGFloat = 0.7
    static let rectangleViewAlpha: CGFloat = 0.3
    static let shapeViewAlpha: CGFloat = 0.3
    static let rectangleViewCornerRadius: CGFloat = 10.0
}

extension UITextField {
    func setup_receipt_tf(){
        self.addTarget(self, action: #selector(touched_inside(_:)), for: .touchUpInside)
        self.addTarget(self, action: #selector(touched_inside(_:)), for: .touchUpOutside)
        self.addTarget(self, action: #selector(touched_inside(_:)), for: .touchDragEnter)
        self.addTarget(self, action: #selector(touched_inside(_:)), for: .touchDragOutside)
        self.addTarget(self, action: #selector(touched_inside(_:)), for: .touchCancel)
        self.addTarget(self, action: #selector(touch_started(_:)), for: .touchDown)
//        if #available(iOS 13.0, *) {
//            overrideUserInterfaceStyle = .light
//        } else {
//            // Fallback on earlier versions
//        }
    }
    
    @objc func touch_started(_ field:UITextField){
        let timingParameters = UISpringTimingParameters(dampingRatio: 1.4, initialVelocity: CGVector(dx: 0, dy: 0))
        let animator = UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters)
        animator.addAnimations {
            field.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
        animator.isInterruptible = true
        animator.startAnimation()
    }
    
    @objc func touched_inside(_ field:UITextField){
        UITextField.animate(withDuration: 0.2,
                            animations: {
                                field.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        },completion: { finish in
            UITextField.animate(withDuration: 0.2, animations: {
                field.transform = CGAffineTransform.identity
            })
        })
    }
}
extension UIButton {
    
    func setup_receipt_btns(){
        self.titleLabel?.adjustsFontSizeToFitWidth = true
        self.addTarget(self, action: #selector(touched_inside(_:)), for: .touchUpInside)
        self.addTarget(self, action: #selector(touched_inside(_:)), for: .touchUpOutside)
        self.addTarget(self, action: #selector(touched_inside(_:)), for: .touchDragOutside)
        self.addTarget(self, action: #selector(touch_started(_:)), for: .touchDown)
        self.addTarget(self, action: #selector(touched_inside(_:)), for: .touchCancel)
        self.layer.backgroundColor = UIColor.systemTeal.cgColor
        if #available(iOS 13.0, *) {
            self.layer.backgroundColor = UIColor.systemIndigo.cgColor
        } else {
            self.layer.backgroundColor = UIColor.blue.cgColor
            // Fallback on earlier versions
        }
        self.layer.cornerRadius = 4.0
        self.setTitleColor(.white, for: .selected)
    }
    @objc func touch_started(_ button:UIButton){
        let timingParameters = UISpringTimingParameters(dampingRatio: 1.4, initialVelocity: CGVector(dx: 0, dy: 0))
        let animator = UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters)
        animator.addAnimations {
            button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
        animator.isInterruptible = true
        animator.startAnimation()
    }
    
    @objc func touched_inside(_ button:UIButton){
        UIButton.animate(withDuration: 0.2,
                         animations: {
                            button.transform = CGAffineTransform(scaleX: 0.875, y: 0.86)
        },completion: { finish in
            UIButton.animate(withDuration: 0.2, animations: {
                button.transform = CGAffineTransform.identity
            })
        })
    }
}
func stringArrayToData(stringArray: [String]) -> Data? {
  return try? JSONSerialization.data(withJSONObject: stringArray, options: [])
}

func dataToStringArray(data: Data) -> [String]? {
  return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String]
}

private var kAssociationKeyMaxLength: Int = 50000

extension UITextField {

    @IBInspectable var maxLength: Int {
        get {
            if let length = objc_getAssociatedObject(self, &kAssociationKeyMaxLength) as? Int {
                return length
            } else {
                return Int.max
            }
        }
        set {
            objc_setAssociatedObject(self, &kAssociationKeyMaxLength, newValue, .OBJC_ASSOCIATION_RETAIN)
            addTarget(self, action: #selector(checkMaxLength), for: .editingChanged)
        }
    }

    @objc func checkMaxLength(textField: UITextField) {
        guard let prospectiveText = self.text,
            prospectiveText.count > maxLength
            else {
                return
        }

        let selection = selectedTextRange

        let indexEndOfText = prospectiveText.index(prospectiveText.startIndex, offsetBy: maxLength)
        let substring = prospectiveText[..<indexEndOfText]
        text = String(substring)

        selectedTextRange = selection
    }
}


// MARK: Helper methods
extension Date {
    var startOfWeek: Date? {
        let gregorian = Calendar(identifier: .gregorian)
        guard let sunday = gregorian.date(from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)) else { return nil }
        return gregorian.date(byAdding: .day, value: 1, to: sunday)
    }

    var endOfWeek: Date? {
        let gregorian = Calendar(identifier: .gregorian)
        guard let sunday = gregorian.date(from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)) else { return nil }
        return gregorian.date(byAdding: .day, value: 7, to: sunday)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        completionHandler([.alert, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        if response.notification.request.identifier == "Local Notification" {
//            //NSLog("Handling notifications with the Local Notification Identifier")
        }
        
        completionHandler()
    }
    func get_total_week(receipt:[Receipt]) -> String?{
        if let week_date = Date().startOfWeek {
            if let filtered_receipts = receipts?.filter({
                $0.date.isBetween(week_date, and: Date())
            }) {
                var total = Float(0.00)
                for i in filtered_receipts {
                    total += i.total.currency_to_float()
                }
                return total.float_to_currency(currency_locale: filtered_receipts[0].currency_locale, currency_code: filtered_receipts[0].currency_code)
            }
        }
        
        return nil
    }
    func scheduleNotification(notificationType: String) {
//        var total = ""
//        DispatchQueue.main.async{
//            if let delegate = UIApplication.shared.delegate as? AppDelegate {
//                if let result = get_total_week(receipt: delegate.receipts!) {
//                    total = result
//                }
//            }
//        }
        
        let content = UNMutableNotificationContent()
        let categoryIdentifier = "Delete Notification Type"
        
        content.title = NSLocalizedString("Reminder", comment: "")
//        if total != "" {
//            content.body = NSLocalizedString("This past week, your total spent is: ", comment: "") + total
//        }else{
        content.body = NSLocalizedString("Just a friendly reminder to input any receipts.", comment: "")
//        }
        content.sound = UNNotificationSound.default
        content.badge = 0
        content.categoryIdentifier = categoryIdentifier
        
        var dateComponents = DateComponents()
        dateComponents.weekday = 7
        dateComponents.hour = 18
        dateComponents.minute = 15
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = "Local Notification"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.add(request) { (error) in
            if let error = error {
                //NSLog("Error \(error.localizedDescription)")
            }
        }
        
        let deleteAction = UNNotificationAction(identifier: "DeleteAction", title: NSLocalizedString("Dismiss", comment: ""), options: [.destructive])
        let category = UNNotificationCategory(identifier: categoryIdentifier,
                                              actions: [deleteAction],
                                              intentIdentifiers: [],
                                              options: [])
        
        notificationCenter.setNotificationCategories([category])
        
    }
}


extension Date {
    
    func toString( dateFormat format  : String, locale: Locale ) -> String? {
        let dateFormatter = DateFormatter()
     
//        dateFormatter.dateFormat = "MM dd yyyy"
        dateFormatter.dateStyle = .short
        dateFormatter.locale = locale
        //dateFormatter.dateFormat = format
        if let string = dateFormatter.string(from: self) as? String {
            return string
        }else{
            return nil
        }
        
    }
    
    func convertDate (dateFormat format_from  : String ,dateFormat format_to  : String ) -> Date?{
        let inputFormatter = DateFormatter()
        let outputFormatter = DateFormatter()
        inputFormatter.dateFormat = format_from
        let showDate = inputFormatter.string(from: self)
            outputFormatter.dateFormat = format_to
        if let _ = outputFormatter.date(from: showDate){
            return outputFormatter.date(from: showDate)
        }else{
            return nil
        }
    }
    
    func isBetween(_ date1: Date, and date2: Date) -> Bool {
        return (min(date1, date2) ... max(date1, date2)).contains(self)
    }
}

extension String {
    func toDateFull( dateFormat format  : String ) -> Date?{
        let dateFormatter = DateFormatter()
        
        dateFormatter.dateStyle = .short
        if (dateFormatter.date(from: self) != nil) {
            return dateFormatter.date(from: self)
        }else{
            dateFormatter.dateStyle = .medium
            if (dateFormatter.date(from: self) != nil) {
                return dateFormatter.date(from: self)
            }else{
                dateFormatter.dateStyle = .long
                if (dateFormatter.date(from: self) != nil) {
                    return dateFormatter.date(from: self)
                }else{
//                    //NSLog("failed to convert date...")
                }
            }
           dateFormatter.dateFormat = format
           dateFormatter.dateStyle = .none
           let del = UIApplication.shared.delegate as! AppDelegate
           dateFormatter.locale = del.date_local
           if (dateFormatter.date(from: self) != nil) {
             return dateFormatter.date(from: self)
           }
           return nil
        }
    }
    func toDate ( dateFormat format  : String ) -> Date?{
        let dateFormatter = DateFormatter()
        
        dateFormatter.dateFormat = format
        let del = UIApplication.shared.delegate as! AppDelegate
        dateFormatter.locale = del.date_local
         if (dateFormatter.date(from: self) != nil) {
             return dateFormatter.date(from: self)
         } else{
            //NSLog("date could not be converted")
        }
          return nil
    }
    func processDate() -> Date?{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        if let _ = dateFormatter.date(from:self) {
            return dateFormatter.date(from:self)
        }else{
            return nil
        }
    }

}
extension Int {
    func toDecimalNumber() -> String{
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(from: NSNumber(value: self))!
    }
}
extension UIView {
    
    func fadeIn(duration: TimeInterval = 0.5, delay: TimeInterval = 0.0, completion: @escaping ((Bool) -> Void) = {(finished: Bool) -> Void in }) {
        self.alpha = 0.0
        
        UIView.animate(withDuration: duration, delay: delay, options: UIView.AnimationOptions.curveEaseIn, animations: {
            self.isHidden = false
            self.alpha = 1.0
        }, completion: completion)
    }
    
    func addBottomBorderWithColor(color: UIColor, width: CGFloat) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: 0, y: self.frame.size.height - width, width: self.frame.size.width, height: width)
        self.layer.addSublayer(border)
    }
    
    func addTopBorderWithColor(color: UIColor, width: CGFloat, width_banner:CGFloat) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: 0, y: -8, width: width_banner, height: width)
        self.layer.addSublayer(border)
    }
    
    func fadeOut(duration: TimeInterval = 0.5, delay: TimeInterval = 0.0, completion: @escaping (Bool) -> Void = {(finished: Bool) -> Void in }) {
        self.alpha = 1.0
        
        UIView.animate(withDuration: duration, delay: delay, options: UIView.AnimationOptions.curveEaseIn, animations: {
            self.alpha = 0.0
        }) { (completed) in
            self.isHidden = true
            completion(true)
        }
    }
    
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}

extension Float {
    
    func float_to_currency(currency_locale:Locale?, currency_code:String?) -> String {
        if currency_locale == nil || currency_code == nil {
            return String(self)
        }
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = currency_locale
        numberFormatter.currencySymbol = getSymbol(code: currency_code!)
        
//        //NSLog("Currency symbol: \(numberFormatter.string(from: NSNumber(value: self))!)")
//        //NSLog("numberFormatter.string(from: NSNumber(value: self))!: \(numberFormatter.string(from: NSNumber(value: self))!)")
        return numberFormatter.string(from: NSNumber(value: self))!
    }
    
//    func getSymbol(forCurrencyCode code: String) -> String? {
//        let locale = NSLocale(localeIdentifier: code)
//        if locale.displayName(forKey: .currencySymbol, value: code) == code {
//            //NSLog("In new locale...")
//            let newlocale = NSLocale(localeIdentifier: code.dropLast() + "_en")
//            return newlocale.displayName(forKey: .currencySymbol, value: code)
//        }
//
//        return locale.displayName(forKey: .currencySymbol, value: code)
//    }
    func getSymbol(code: String) -> String? {
        let result = Locale.availableIdentifiers.map { Locale(identifier: $0) }.first { $0.currencyCode == code }
        return result?.currencySymbol
    }
}


func getSymbol(code: String) -> String? {
    let result = Locale.availableIdentifiers.map { Locale(identifier: $0) }.first { $0.currencyCode == code }
    return result?.currencySymbol
}

extension String{
    
    func currency_to_float() -> Float {
        
        let val = String(self.filter { "0123456789.".contains($0) })
//        //NSLog("currency symbol: \(numberFormatter.currencySymbol)")
//        if let num =  {
        if let val_r = Float(val) {
            return val_r
        }else{
            return 0.00
        }
        
//        }else{
//            return 0.00
//        }
    }
    
    func getSymbol(code: String) -> String? {
        let result = Locale.availableIdentifiers.map { Locale(identifier: $0) }.first { $0.currencyCode == code }
        return result?.currencySymbol
    }
}

extension UIImage {
    func rotate(radians: Float, newImage:inout UIImage){
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        
        newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
    }
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height*2 / size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}

extension FileManager {
    func clearTmpDirectory() {
        do {
            let tmpDirURL = FileManager.default.temporaryDirectory
            let tmpDirectory = try contentsOfDirectory(atPath: tmpDirURL.path)
            try tmpDirectory.forEach { file in
                let fileUrl = tmpDirURL.appendingPathComponent(file)
                try removeItem(atPath: fileUrl.path)
            }
        } catch {
            //catch the error somehow
        }
    }
}


class KeyChain {
    
    class func save(key: String, data: Data) -> OSStatus {
        let query = [
            kSecClass as String       : kSecClassGenericPassword as String,
            kSecAttrService: "ReceiptFriendKey",
            kSecAttrAccount as String : key,
            kSecAttrSynchronizable as String : kCFBooleanTrue,
            kSecValueData as String   : data ] as! [String : Any]
        
        
        SecItemDelete(query as CFDictionary)
        
        return SecItemAdd(query as CFDictionary, nil)
    }
    
    class func load(key: String) -> Data? {
        let query = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService: "ReceiptFriendKey",
            kSecAttrAccount as String : key,
            kSecAttrSynchronizable as String : kCFBooleanTrue,
            kSecReturnData as String  : kCFBooleanTrue!,
            kSecMatchLimit as String  : kSecMatchLimitOne ] as! [String : Any]
        
        var dataTypeRef: AnyObject? = nil
        
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr {
            return dataTypeRef as! Data?
        } else {
            return nil
        }
    }
    class func delete(key: String){
        let query = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService: "ReceiptFriendKey",
            kSecAttrAccount as String : key,
            kSecAttrSynchronizable as String : kCFBooleanTrue,
            kSecMatchLimit as String  : kSecMatchLimitOne ] as! [String : Any]
        
        let status = SecItemDelete(query as CFDictionary)
    }
    class func createUniqueID() -> String {
        let uuid: CFUUID = CFUUIDCreate(nil)
        let cfStr: CFString = CFUUIDCreateString(nil, uuid)
        
        let swiftString: String = cfStr as String
        return swiftString
    }
}

extension Data {
    
//    init<T>(from value: T) {
//        var value = value
//        self.init(buffer: UnsafeBufferPointer(start: &value, count: 1))
//    }
//    
//    func to<T>(type: T.Type) -> T {
//        return self.withUnsafeBytes { $0.load(as: T.self) }
//    }
}

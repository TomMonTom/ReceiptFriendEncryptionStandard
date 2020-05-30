//
//  AppDelegate.swift
//  ReceiptBuddy
//
//  Created by THOMAS THOMPSON on 7/25/19.
//  Copyright © 2019 THOMAS THOMPSON. All rights reserved.
//

import UIKit
import CoreData
//import GoogleMobileAds
import CommonCrypto
import Network
import Firebase
import UserNotifications
//        receipt_dummy = [Receipt](repeating: Receipt(), count: 1000)
//        var k = 0
//        for i in 0 ... 1000 - 1 {
//            receipt_dummy[i].business_name = business_names[k%4]
//            k += 1
//            receipt_dummy[i].date = receipt_date[k%4]
//            receipt_dummy[i].id = i
//            receipt_dummy[i].image = UIImage(named: images_array[k%4])!
//            k += 2
//            receipt_dummy[i].item_name = item_names[k%4]
//            receipt_dummy[i].preview_img = UIImage(named: images_array[k%4])!
//            receipt_dummy[i].price = prices[k%4]
//            k -= 1
//        }
//        receipts = receipt_dummy
//        self.saveBulkData(receipt_array: receipts!)

//var receipt_dummy : [Receipt]!
//var images_array = ["DownArrow","UpArrow","DashboardIcon","ReceiptIcon"]
//var receipt_date = ["10/13/2014","11/32/2015","12/13/2013","09/10/2011"]
//var business_names = ["Buzzy","BeltWorth Inc.","Sam Sampson", "Dollys","Burgers"]
//var item_names = ["Buddle", "Groceries", "Wench parts","Alpha Tones"]
//var prices = ["$0.32","$4,003.30","$120.30","$10.30"]


let categories = [NSLocalizedString("Auto", comment: ""),NSLocalizedString("Bills", comment: ""),NSLocalizedString("Construction", comment: ""),NSLocalizedString("Entertainment", comment: ""),NSLocalizedString("Education", comment: ""),NSLocalizedString("Fees", comment: ""),NSLocalizedString("Financial", comment: ""),NSLocalizedString("Food", comment: ""),NSLocalizedString("Gifts", comment: ""),NSLocalizedString("Health Care", comment: ""),NSLocalizedString("Home", comment: ""),NSLocalizedString("Personal Care", comment: ""),NSLocalizedString("Shopping", comment: ""),NSLocalizedString("Taxes", comment: ""),NSLocalizedString("Travel", comment: ""),NSLocalizedString("Transportation", comment: ""),NSLocalizedString("Utilities", comment: ""),NSLocalizedString("Uncategorized", comment: ""),NSLocalizedString("Miscellaneous", comment: "")]
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var batteryState: Bool {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let state = UIDevice.current.batteryState
        
        if state == .charging || state == .full {
            //NSLog("Device plugged in.")
            return true
            
        } else {
            return false
        }
        
    }
    
    private lazy var back_up_counter = 0
    var last_sort: DictSort!
    var window: UIWindow?
    
    //Data objects
    lazy var receipts : [Receipt]? = [Receipt]()
    var accounts : AccountsInternal?
    lazy var custom_categories : [String]? = [String]()
    
    lazy var filteredData : [Receipt]? = [Receipt]()
    lazy var idx_receipts: Int? = 0
    lazy var in_eea = false
    //Locality settings
    var currency : Locale? = Locale.current
    var currency_code : String? = ""
    lazy var date_local : Locale? = Locale(identifier: "")
    lazy var consent_val : Int = 0
    //Application settings
    private lazy var auto_fill = true
    private lazy var autosave = true
    private lazy var page_layout = true //false: portrait true: landscape
    private lazy var multi_picture_mode = true
    private lazy var auto_save_receipt = false
    
    private lazy var purchased = true
    private let l = "i"
    private let q : Double = 48129838098523847192938848191532
    private let r = "i".data(using:String.Encoding.utf8)!
    private var aes : AES!
    lazy var total_receipts = 0
    lazy var idx_total_receipts = 0
    private lazy var review_enabled = false
    
    func get_review() -> Bool {
        return review_enabled
    }
    
    func set_review() {
        review_enabled = false
    }
    
    func set_page_layout(val:Bool) {
        self.page_layout = val
        UserDefaults.standard.set(val, forKey: "PageLayout")
    }
    
    func set_autosave_receipts(val:Bool){
        self.auto_save_receipt = val
        UserDefaults.standard.set(val, forKey: "AutoSaveReceipts")
    }
    
    func get_autosave_receipts() -> Bool {
        return auto_save_receipt
    }
    func get_autofill() -> Bool {
        return auto_fill
    }
    
    func get_purchased() -> Bool{
        return purchased
    }
    
    func get_multi_picture() -> Bool {
        if purchased{
            return multi_picture_mode
        }else{
            return false
        }
    }
    func get_page_layout() -> Bool {
        return page_layout
    }
    func set_multi_picture(val:Bool) {
        self.multi_picture_mode = val
        UserDefaults.standard.set(val, forKey: "MultiPictureMode")
    }
    
    func s(string:String) -> Data{
//        let salt = q.clean
//        let idx = salt.index(salt.startIndex, offsetBy: (salt.count - string.count))
//        let substring = salt[..<idx]
//        let string_return = (substring + string)
        let salt = string.sha256(salt: q.clean)
        return salt
    }
    
    func enableAES(key:Data) {
        do{
            aes = try AES(keyString: key)
        }catch{
            //NSLog("Could not make AES: \(error.localizedDescription)")
        }
    }
    
    func encrypt(data:Data) -> Data?{
        do{
            let v  = try aes.encrypt(data)
            return v
        }catch{
            //NSLog("Could not encrypt: \(error.localizedDescription)")
        }
        return nil
    }
    
    func decrypt(data:Data) -> Data?{
        do{
            let v  = try aes.decrypt(data)
            return v
        }catch{
            //NSLog("Could not decrypt: \(error.localizedDescription)")
        }
        return nil
    }
    
    let notificationCenter = UNUserNotificationCenter.current()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        notificationCenter.delegate = self
        
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        
        notificationCenter.requestAuthorization(options: options) {
            (didAllow, error) in
            if didAllow {
                self.notificationCenter.getPendingNotificationRequests(completionHandler: { notification in
                    if notification.count == 0 {
                        //NSLog("notifications not found, making one...")
                        self.scheduleNotification(notificationType: "Local Notification")
                    }
                })
                //NSLog("User has declined notifications")
            }
        }
        
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        
        if let value = UserDefaults.standard.object(forKey: "AutoSave") as? Bool {
            autosave = value
        }
        
        
        
        if let value_fill = UserDefaults.standard.object(forKey: "AutoFill") as? Bool {
            auto_fill = value_fill
        }
        if let result_page = UserDefaults.standard.object(forKey: "PageLayout") as? Bool {
            page_layout = result_page
        }
        
        if let value_date_local = UserDefaults.standard.object(forKey: "DateLocale") as? String {
            let local = Locale(identifier:value_date_local)
            date_local = local
        }else{
            date_local = Locale.current
        }
        
        FirebaseApp.configure()
        if let val = UserDefaults.standard.object(forKey: "CurrencyCode") as? String{
            self.currency = Locale(identifier: val)
            self.currency_code = val
        }else{
            self.currency = Locale.current
            self.currency_code = Locale.current.currencyCode
        }
        if let receivedData = KeyChain.load(key: "ReceiptFriendK") {
            let result = receivedData
            do{
                aes = try AES(keyString: result)
            }catch{
                //NSLog("Could not make AES: \(error.localizedDescription)")
            }
        }
        
        if let val = UserDefaults.standard.object(forKey: "CustomCategoryKey") as? Data{
            let data = self.decrypt(data: val)
            if let data = data {
                let arr = dataToStringArray(data: data)
                self.custom_categories = arr
            }
        }else{
            self.custom_categories = [String]()
        }
        
        
        
        
        checkData()
        back_up_counter = UserDefaults.standard.integer(forKey: "BackupKey")
        if back_up_counter > 4 {
            review_enabled = true
        }
        if let val = UserDefaults.standard.object(forKey: "ConsentFormKey") as? Int {
            if val == 1 {
                self.consent_val = 1
            }
        }
        
        if let val = UserDefaults.standard.object(forKey: "AutoSaveReceipts") as? Bool {
            self.auto_save_receipt = val
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        //NSLog("in background...")
        if batteryState {
            if autosave == true {
                //NSLog("in background...")
                create_backup()
            }
        }
        
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
//        SettingsBundleHelper.checkAndExecuteSettings()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.semaphore.wait()
        self.saveContext()
    }

    func set_autosave(value:Bool) {
        self.autosave = value
        UserDefaults.standard.set(value, forKey: "AutoSave")
    }
    
//    func set_purchase_on(){
//        self.purchased = true
//    }
    
    func set_autofill(value:Bool){
        self.auto_fill = value
        UserDefaults.standard.set(value, forKey: "AutoFill")
    }
    
//    func set_purchase(){
//        do{
//            let v  = try aes.encrypt(l.data(using: String.Encoding.utf8)!)
//            let managed_context = self.persistentContainer.viewContext
//            let entity = NSEntityDescription.entity(forEntityName: "Q", in: managed_context)!
//            let i = NSManagedObject(entity: entity, insertInto: managed_context)
//            i.setValue(v, forKey: "i")
//            do{
//                try managed_context.save()
//            }catch{
//                //NSLog("Error in saving context")
//            }
//            if !purchased{
//                purchased = true
//            }
//        }catch{
//            //NSLog("Error in \(error.localizedDescription)")
//        }
//
//    }
//    func set_purchase_false(){
//        do{
//            let v  = try aes.encrypt("darn".data(using: String.Encoding.utf8)!)
//            let managed_context = self.persistentContainer.viewContext
//            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Q")
//            do{
//                let fetch = try managed_context.fetch(fetchRequest)
//                if fetch.count == 0 {
//                    //NSLog("Update cmd could not change")
//                }
//                let receipt = fetch[0] as! NSManagedObject
//                receipt.setValue(v, forKey: "i")
//                do{
//                    try managed_context.save()
//                }catch{
//                    //NSLog("Error in saving context")
//                }
//            }catch{
//                //NSLog("could not reach managed database...")
//            }
//
//            //NSLog("setting purchased to false...")
//            self.purchased = false
//        }catch{
//            //NSLog("Error false: \(error.localizedDescription)")
//        }
//
//    }
    
    func checkData(){
        
        let managed_context = self.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"ReceiptData")
//        fetchRequest.fetchLimit = 100000
        get_total_receipts()
        check_data_payment(managed_context: managed_context)
        check_data_idx(managed_context: managed_context)
        check_data_accounts(managed_context: managed_context)
            //get result
            do{
                let result = try managed_context.fetch(fetchRequest)
                
                if result.count == 0 {
                    //NSLog("Result is not found... creating receipt array")
                    self.receipts = [Receipt]()
                    return
                }
                
                self.receipts = [Receipt](repeating:Receipt(currency_locale: Locale.current, currency_symbol: Locale.current.currencyCode), count: (result.count))
                
                
                var i = 0
                for data in result as! [NSManagedObject]{
                    autoreleasepool{
                        self.receipts![i].id = data.value(forKey: "id") as? Int
                        self.receipts![i].total = data.value(forKey: "total") as? String
                        self.receipts![i].date = data.value(forKey: "date") as? Date
                        self.receipts![i].location = data.value(forKey: "location") as? String
                        self.receipts![i].category = data.value(forKey: "category") as? String
                        self.receipts![i].account = data.value(forKey: "account") as? String
                        self.receipts![i].tax = data.value(forKey: "tax") as? String
                        self.receipts![i].currency_locale = data.value(forKey: "currency_locale") as? Locale
                        self.receipts![i].currency_code = data.value(forKey: "currency_code") as? String
                        i+=1
                    }
                }
                self.receipts! = self.receipts!.sorted(by: {
                    $0.id < $1.id
                })
            }catch{
                //NSLog("Data was unable to be read")
                self.receipts = [Receipt]()
            }
    }
    func search_key_words(search_querry:String,filtered_receipts:[Receipt]){
        
        let container = self.persistentContainer
        container.performBackgroundTask(){managed_context in
//            self.semaphore.wait()
            var ids : [Int] = [Int]()
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"KeyWord")
//            fetchRequest.predicate = NSPredicate(format: "id = %@", String(id))
            fetchRequest.predicate = NSPredicate(format: "keywords contains[c] %@",search_querry)
            do{
                let fetch = try managed_context.fetch(fetchRequest)
                if fetch.count == 0 {
                    //NSLog("keyword search could not find item: \(search_querry)")
                }
                var i = 0
                for keyword in fetch as! [NSManagedObject]{
                    let id = keyword.value(forKey: "id") as? Int
                    
                    ids.append(id!)
                    i += 1
                }
                do{
                    try managed_context.save()
                }catch{
                    //NSLog("Error finding object. May not be found...")
                }
                
                
                
                var receipt = [Receipt]()
                for i in ids {
                    let result = self.receipts!.filter(){
                        $0.id == i
                    }
                    if result.count > 0 {
                        receipt.append(result[0])
                    }
                    
                }
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SearchFoundObjectKeyword"), object: receipt)
                }
                
            }catch{
                //NSLog("error finding fetch request in context...")
            }
//            self.semaphore.signal()
        }
    }
    func read_key_words(receipt:Receipt) -> String?{
        //        //NSLog("loading item: \(receipt_id)")
        let managed_context = self.persistentContainer.viewContext
        var results : String? = nil
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"KeyWord")
        fetchRequest.predicate = NSPredicate(format: "id = %@", String(receipt.id))
        do{
            
            let result = try managed_context.fetch(fetchRequest)
            
            if result.count == 0 {
//                //NSLog("Items Result is not found for receipt \(receipt_id)...")
                return nil
            }
            
            
            for data in result as! [NSManagedObject]{
                    results = data.value(forKey: "keywords") as? String
            }
        }catch{
            //NSLog("Data was unable to be read")
        }
        
        return results
    }
    func update_key_words(id:Int,key_words:String) {
        //        //NSLog("Updating data...\(receipt_input)")
        let managed_context = persistentContainer.viewContext
            self.semaphore.wait()
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"KeyWord")
            fetchRequest.predicate = NSPredicate(format: "id = %@", String(id))
            
            do{
                let fetch = try managed_context.fetch(fetchRequest)
                if fetch.count == 0 {
                    //NSLog("Update cmd Could not find item: \(id)")
                    self.semaphore.signal()
                }
                let receipt = fetch[0] as! NSManagedObject
                receipt.setValue(key_words, forKey: "keywords")
                do{
                    try managed_context.save()
                }catch{
                    //NSLog("Error deleting object. May not be found...")
                }
                
            }catch{
                //NSLog("error finding fetch request in context...")
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "RefreshTable"), object: nil)
            }
            self.semaphore.signal()
    }
    func save_key_words(id:Int, key_words:String){
        let managed_context = persistentContainer.viewContext
        let managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        managedObjectContext.parent = persistentContainer.viewContext
        managedObjectContext.perform() {
                self.semaphore.wait()
                let entity = NSEntityDescription.entity(forEntityName: "KeyWord", in: managed_context)!
                let keyword = NSManagedObject(entity: entity, insertInto: managed_context)
                keyword.setValue(id, forKey: "id")
                keyword.setValue(key_words, forKey: "keywords")
            do{
                try managed_context.save()
            }catch{
                self.semaphore.signal()
                //NSLog("Error in saving context")
            }
            self.semaphore.signal()
        }
    }
    
    func delete_key_words(id:Int){
        let container = persistentContainer
        container.performBackgroundTask(){ managed_context in
            self.semaphore.wait()
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"KeyWord")
            fetchRequest.predicate = NSPredicate(format: "id = %@", String(id))
            
            do{
                let fetch = try managed_context.fetch(fetchRequest)
                if fetch.count == 0 {
                    //NSLog("Delete Keywords Could not find item: \(id)")
                    self.semaphore.signal()
                    return
                }
                let receipt_delete = fetch[0] as! NSManagedObject
                managed_context.delete(receipt_delete)
                
                do{
                    try managed_context.save()
                }catch{
                    //NSLog("Error deleting object. May not be found...")
                }
                
            }catch{
                //NSLog("error finding fetch request in context...")
            }
            
            self.semaphore.signal()
            
        }
    }
    
    func get_total_receipts(){
        let managed_context = self.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"ReceiptData")
        
        do{
            total_receipts = try managed_context.count(for: fetchRequest)
            idx_total_receipts = total_receipts/100000
        }catch{
            //NSLog("could not get receipt count...")
        }
    }
    
    func retreive_data(id: Int, array_amount: Int, scroll_idx: Int){
        
        if  idx_total_receipts < 0 {
            return
        }
        idx_total_receipts -= 1
        
        let container = self.persistentContainer
        container.performBackgroundTask(){ managed_context in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"ReceiptData")
            fetchRequest.fetchLimit = array_amount
            fetchRequest.predicate = NSPredicate(format: "id => %@", String(id))
            //get result
            do{
                let result = try managed_context.fetch(fetchRequest)
                
                if result.count == 0 {
                    //NSLog("Result is not found... creating receipt array")
                }
                
                var receipts_return = [Receipt](repeating:Receipt(currency_locale: self.currency!, currency_symbol: self.currency_code), count: (result.count))
                var i = 0
                for data in result as! [NSManagedObject]{
                    receipts_return[i].id = data.value(forKey: "id") as? Int
                    receipts_return[i].total = data.value(forKey: "total") as? String
                    receipts_return[i].date = data.value(forKey: "date") as? Date
                    receipts_return[i].location = data.value(forKey: "location") as? String
                    receipts_return[i].category = data.value(forKey: "category") as? String
                    receipts_return[i].account = data.value(forKey: "account") as? String
                    receipts_return[i].tax = data.value(forKey: "tax") as? String
                    receipts_return[i].currency_locale = data.value(forKey: "currency_locale") as? Locale
                    receipts_return[i].currency_code = data.value(forKey: "currency_code") as? String
                    i+=1
                }
//                let dict : [String:Any] = ["scroll":scroll_idx,"receipts":receipts_return]
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "AppendFound"), object: receipts_return)
                }
            }catch{
                //NSLog("Data was unable to be read")
            }
        }
    }
    func load_items(receipt_id:Int) -> [Item]?{
//        //NSLog("loading item: \(receipt_id)")
        var items : [Item] = [Item]()
        let managed_context = self.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"ItemData")
        fetchRequest.predicate = NSPredicate(format: "id = %@", String(receipt_id))
        do{
            
            let result = try managed_context.fetch(fetchRequest)
            
            if result.count == 0 {
//                //NSLog("Items Result is not found for receipt \(receipt_id)...")
                return nil
            }
            
            
            for data in result as! [NSManagedObject]{
                autoreleasepool{
                    let idx = data.value(forKey: "idx") as? Int
                    let id = data.value(forKey: "id") as? Int
                    let amount = data.value(forKey: "amount") as? String
                    let count = data.value(forKey: "line_item_count") as? Int
                    let name = data.value(forKey: "line_item_name") as? String
                    let item = Item(name: name!, count: count!, amount: amount!, id: id!)
                    items.insert(item, at: idx!)
                }
            }
        }catch{
            //NSLog("Data was unable to be read")
        }
        
        return items
    }
    func load_all_items() -> [Item]?{
        var items : [Item] = [Item]()
        let managed_context = self.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"ItemData")
        do{
            
            let result = try managed_context.fetch(fetchRequest)
            
            if result.count == 0 {
                //                //NSLog("Items Result is not found for receipt \(receipt_id)...")
                return nil
            }
            
            
            for data in result as! [NSManagedObject]{
                autoreleasepool{
                    let id = data.value(forKey: "id") as? Int
                    let amount = data.value(forKey: "amount") as? String
                    let count = data.value(forKey: "line_item_count") as? Int
                    let name = data.value(forKey: "line_item_name") as? String
                    let item = Item(name: name!, count: count!, amount: amount!, id: id!)
                    let idx = data.value(forKey: "idx") as? Int
                    items.insert(item, at: idx!)
                }
            }
        }catch{
            //NSLog("Data was unable to be read")
        }
        
        return items
    }
    func save_items(items:[Item], id:Int){
        delete_all_items_from_receipt(id: id)
        let managed_context = persistentContainer.viewContext
        let managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        managedObjectContext.parent = persistentContainer.viewContext
        managedObjectContext.perform() {
            autoreleasepool {
                self.semaphore.wait()
                
                for i in 0 ..< items.count {
                    let entity = NSEntityDescription.entity(forEntityName: "ItemData", in: managed_context)!
                    let item = NSManagedObject(entity: entity, insertInto: managed_context)
                    item.setValue(items[i].amount, forKey: "amount")
                    item.setValue(items[i].line_item_count, forKey: "line_item_count")
                    item.setValue(items[i].line_item_name, forKey: "line_item_name")
                    item.setValue(items[i].id, forKey: "id")
                    item.setValue(i, forKey: "idx")
                }
            }
            
            do{
                try managed_context.save()
            }catch{
                self.semaphore.signal()
                //NSLog("Error in saving context")
            }
            self.semaphore.signal()
        }
    }
    func search_item_data(search:String){
        
//        let managed_context = persistentContainer.viewContext
//        let managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        let container = self.persistentContainer
        container.performBackgroundTask(){ managed_context in
            autoreleasepool {
                var ids : [Int] = [Int]()
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"ItemData")
                fetchRequest.predicate = NSPredicate(format: "line_item_name contains[c] %@ OR line_item_count contains[c] %@ OR amount contains[c] %@ ", String(search),String(search),String(search))
        //        fetchRequest.predicate = NSPredicate{ (obj, _) in
        //            return (obj as! Item).range(of: search, options: .caseInsensitive)
        //        }
                do{
                    let fetch = try managed_context.fetch(fetchRequest)
                    if fetch.count == 0 {
                        return
                    }
                    var i = 0
                    for item in fetch as! [NSManagedObject]{
                        let id = item.value(forKey: "id") as? Int
                        ids.append(id!)
                        i += 1
                    }
                    do{
                        try managed_context.save()
                    }catch{
                        //NSLog("Error deleting object. May not be found...")
                    }
                    
                }catch{
                    //NSLog("error finding fetch request in context...")
                }
                var receipt = [Receipt]()
                for i in ids {
                    let result = self.receipts!.filter(){
                        $0.id == i
                    }
                    if result.count > 0 {
                        receipt.append(result[0])
                    }
                    
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SearchFoundObject"), object: receipt)
                }
            }
        }
    }
    func update_item_data(items:[Item],id:Int){
        let container = self.persistentContainer
        container.performBackgroundTask(){managed_context in
            self.semaphore.wait()
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"ItemData")
            fetchRequest.predicate = NSPredicate(format: "id = %@", String(id))
            
            do{
                let fetch = try managed_context.fetch(fetchRequest)
                if fetch.count == 0 {
                    //NSLog("Update cmd Could not find item: \(id)")
                    self.semaphore.signal()
                    return
                }
                var i = 0
                for item in fetch as! [NSManagedObject]{
                    autoreleasepool{
                        item.setValue(items[i].amount, forKey: "amount")
                        item.setValue(items[i].line_item_count, forKey: "line_item_count")
                        item.setValue(items[i].line_item_name, forKey: "line_item_name")
                        item.setValue(items[i].id, forKey: "id")
                        i += 1
                    }
                }
                do{
                    try managed_context.save()
                }catch{
                    //NSLog("Error deleting object. May not be found...")
                }
                
            }catch{
                //NSLog("error finding fetch request in context...")
            }
            self.semaphore.signal()
        }
    }
    
    func save_item_data(items:[Item], id:Int){
        if id != -1 {
           delete_all_items_from_receipt(id: id)
        }
        let managed_context = persistentContainer.viewContext
        let managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        managedObjectContext.parent = persistentContainer.viewContext
        managedObjectContext.perform() {
            autoreleasepool {
                self.semaphore.wait()
                
                for i in 0 ..< items.count {
                    let entity = NSEntityDescription.entity(forEntityName: "ItemData", in: managed_context)!
                    let item = NSManagedObject(entity: entity, insertInto: managed_context)
                    item.setValue(items[i].amount, forKey: "amount")
                    item.setValue(items[i].line_item_count, forKey: "line_item_count")
                    item.setValue(items[i].line_item_name, forKey: "line_item_name")
                    item.setValue(items[i].id, forKey: "id")
                }
            }
            
            do{
                try managed_context.save()
            }catch{
                self.semaphore.signal()
                //NSLog("Error in saving context")
            }
            self.semaphore.signal()
        }
    }

    func delete_all_items_from_receipt(id:Int) {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "ItemData")
        fetch.predicate = NSPredicate(format: "id = %@", String(id))
        let request = NSBatchDeleteRequest(fetchRequest: fetch)
        do{
            try persistentContainer.viewContext.execute(request)
        }catch{
            //NSLog("could not delete all data...")
        }
    }
    
    func delete_data_store(){
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "ItemData")
        let request = NSBatchDeleteRequest(fetchRequest: fetch)
        do{
            try persistentContainer.viewContext.execute(request)
        }catch{
            //NSLog("item data, could not delete all data...")
        }
        let fetch_recipt = NSFetchRequest<NSFetchRequestResult>(entityName: "ReceiptData")
        let request_receipt = NSBatchDeleteRequest(fetchRequest: fetch_recipt)
        do{
            try persistentContainer.viewContext.execute(request_receipt)
        }catch{
            //NSLog("receipt data, could not delete all data...")
        }
        let fetch_recipt_keyword = NSFetchRequest<NSFetchRequestResult>(entityName: "KeyWord")
        let request_keyword = NSBatchDeleteRequest(fetchRequest: fetch_recipt_keyword)
        do{
            try persistentContainer.viewContext.execute(request_keyword)
        }catch{
            //NSLog("keyword data, could not delete all data...")
        }
    }
    
    func check_data_payment(managed_context: NSManagedObjectContext){
        do{
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Q")
            let result = try managed_context.fetch(fetchRequest)
            if result.count > 0 {
                let data_result = result as! [NSManagedObject]
                let value = data_result[0].value(forKey: "i") as? Data
                let v  = try aes.decrypt(value!)
                let b = String(data: v,encoding: String.Encoding.utf8)
                if b == self.l {
                    //NSLog("purchase key found... setting to true")
                    purchased = true
                }
            }else{
                //NSLog("Purchase key not found...")
            }
        }catch{
            //NSLog("Purchase key problem accessing \(error.localizedDescription)")
        }
    }
    
    func check_data_idx(managed_context: NSManagedObjectContext){
        let fetchRequest_idx = NSFetchRequest<NSFetchRequestResult>(entityName:"ReceiptIdx")
        do{
            
            let result = try managed_context.fetch(fetchRequest_idx)
            
            if result.count == 0 {
                //NSLog("Result is not found... for idx, setting to zero...")
                self.idx_receipts = 0
            }
            for data in result as! [NSManagedObject] {
                self.idx_receipts = (data.value(forKey:"idx") as! Int)
                //NSLog("self.idx: \(self.idx_receipts)")
            }
            
        } catch {
            //NSLog("Error retreiving data...")
        }
    }
    
    func check_data_accounts(managed_context: NSManagedObjectContext){
        self.accounts = AccountsInternal()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"Accounts")
        do{
            
            let result = try managed_context.fetch(fetchRequest)
            
            if result.count == 0 {
                //NSLog("Result is not found... for accounts, setting to defaults...")
            }
            var accounts = [Account]()
            for data in result as! [NSManagedObject] {
                
                let account_name = data.value(forKey:"account_name") as? String
                let account_type = data.value(forKey:"account_type") as? String
                accounts.append(Account(account_name: account_name!, account_type: account_type!))
            }
            for i in accounts {
                if i.account_type == "Bank" {
                    self.accounts?.bank_accounts.append(i)
                }else if i.account_type == "Credit"{
                    self.accounts?.credit_accounts.append(i)
                }
            }
        } catch {
            //NSLog("Error retreiving data...")
        }
    }
    
    func deleteMultipleData(ids:[Int]){
        let container = self.persistentContainer
        container.performBackgroundTask(){ managed_context in
            self.semaphore.wait()
                var querry_string = "id = %@"
                var k = 0
                for _ in ids {
                    if k > 0 {
                       querry_string += " OR id = %@"
                    }
                    k += 1
                }
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ReceiptData")
                fetchRequest.predicate = NSPredicate(format:querry_string,argumentArray:ids)
                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest:fetchRequest)
            do{
                try managed_context.execute(batchDeleteRequest)
            }catch{
                //NSLog("Request for bulk delete could not execute...")
            }
            self.semaphore.signal()
        }
    }
    
    func deleteAllData() {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "ReceiptData")
        let request = NSBatchDeleteRequest(fetchRequest: fetch)
        do{
            try persistentContainer.viewContext.execute(request)
        }catch{
            //NSLog("could not delete all data...")
        }
    }
    
    func deleteData(id:Int){
        delete_key_words(id:id)
        let container = persistentContainer
        container.performBackgroundTask(){ managed_context in
            self.semaphore.wait()
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"ReceiptData")
            fetchRequest.predicate = NSPredicate(format: "id = %@", String(id))
            //NSLog("deleting... \(id)")
            do{
                let fetch = try managed_context.fetch(fetchRequest)
                if fetch.count == 0 {
                    //NSLog("Delete cmd Could not find item: \(id)")
                    self.semaphore.signal()
                    return
                }
                let receipt_delete = fetch[0] as! NSManagedObject
                managed_context.delete(receipt_delete)
                
                do{
                    try managed_context.save()
                }catch{
                    //NSLog("Error deleting object. May not be found...")
                }
                
            }catch{
                //NSLog("error finding fetch request in context...")
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "RefreshTable"), object: nil)
            }
            self.semaphore.signal()
            
        }
    }
    
    func get_high_quality_image(receipt:Receipt) -> UIImage? {
//        //NSLog("Retreiving high quality image")
        let managed_context = self.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"ReceiptData")
        fetchRequest.predicate = NSPredicate(format: "id = %@", String(receipt.id))
        do{
            
            let result = try managed_context.fetch(fetchRequest)
            
            if result.count == 0 {
                //NSLog("Image is not found...")
            }
            
            for data in result as! [NSManagedObject]{
                if let compressed_data_img = data.value(forKey: "image") as? Data {
                    if let image = UIImage(data: compressed_data_img) {
                        return image
                    }else{
                        return nil
                    }
                }else{
                    return nil
                }
                
            }
        }catch{
            //NSLog("Data was unable to be read")
        }
        return nil
    }
    
    func get_image_data(receipt:Receipt) -> Data? {
        let managed_context = self.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"ReceiptData")
        fetchRequest.predicate = NSPredicate(format: "id = %@", String(receipt.id))
        do{
            
            let result = try managed_context.fetch(fetchRequest)
            
            if result.count == 0 {
                //NSLog("Image is not found...")
            }
            
            for data in result as! [NSManagedObject]{
                let compressed_data_img = data.value(forKey: "image") as? Data
//                //NSLog("compressed img: \(compressed_data_img)")
                //                //NSLog("compressed image: \(compressed_data_img)")
                return compressed_data_img!
            }
        }catch{
            //NSLog("Data was unable to be read")
        }
        return nil
    }
    
    let semaphore = DispatchSemaphore(value: 1)
    func update_receipt_idx() -> Bool {
        let managed_context = persistentContainer.viewContext
        let fetchRequest_idx = NSFetchRequest<NSFetchRequestResult>(entityName:"ReceiptIdx")
        self.idx_receipts = self.receipts!.count
        do{
            
            let fetch = try managed_context.fetch(fetchRequest_idx)
            if fetch.count == 0 {
                //NSLog("Update cmd Could not find receipt idx")
                return false
            }
            let idx = fetch[0] as! NSManagedObject
            idx.setValue(self.idx_receipts!, forKey: "idx")
            
        } catch {
            //NSLog("Error retreiving data...")
        }
        return true
    }
    
    func updateData(receipt_input:Receipt, id:Int, pict_retake_flag:Bool, image:UIImage?, image_data:Data = Data()){
//        //NSLog("Updating data...\(receipt_input)")
        let managed_context = persistentContainer.viewContext
            self.semaphore.wait()
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName:"ReceiptData")
            fetchRequest.predicate = NSPredicate(format: "id = %@", String(id))
            
            do{
                let fetch = try managed_context.fetch(fetchRequest)
                if fetch.count == 0 {
//                    //NSLog("Update cmd Could not find item: \(id)")
                    self.semaphore.signal()
                    return
                    
                }
                
                let receipt = fetch[0] as! NSManagedObject
                receipt.setValue(receipt_input.location, forKey: "location")
                receipt.setValue(receipt_input.date, forKey: "date")
                if pict_retake_flag == true {
                    let ctx = CIContext()
                    let ciImage = CIImage(image: image!)
                    let compressed_image = ctx.heifRepresentation(of: ciImage!, format: CIFormat.RGBA8, colorSpace: ctx.workingColorSpace!, options: [:])
                    receipt.setValue(compressed_image, forKey: "image")
                }
                if reorganize == true {
                    receipt.setValue(image_data, forKey: "image")
                }
                receipt.setValue(receipt_input.account, forKey: "account")
                receipt.setValue(receipt_input.category, forKey: "category")
                receipt.setValue(receipt_input.total, forKey: "total")
                receipt.setValue(receipt_input.id, forKey: "id")
                receipt.setValue(receipt_input.tax, forKey: "tax")
                receipt.setValue(receipt_input.currency_locale, forKey: "currency_locale")
                receipt.setValue(receipt_input.currency_code, forKey: "currency_code")
                do{
                    try managed_context.save()
                }catch{
                    //NSLog("Error deleting object. May not be found...")
                }
                
            }catch{
                //NSLog("error finding fetch request in context...")
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "RefreshTable"), object: nil)
            }
            self.semaphore.signal()
        
        if reorganize == false {
            back_up_count()
        }
    }
    
    var reorganize = false
    func reorganize_data(idx_originals:[Int]){
        reorganize = true
        for i in 0 ..< self.receipts!.count{
            let image_data = get_image_data(receipt: self.receipts![i])
            self.receipts![i].id = i
            updateData(receipt_input: self.receipts![i], id: idx_originals[i], pict_retake_flag: false, image: nil, image_data: image_data!)
        }
        update_receipt_idx()
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ImportCompleted"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "RefreshTable"), object: nil)
        
        reorganize = false
    }
    
    func saveBulkData(receipt_array:[Receipt], images:[UIImage]?){
//        //NSLog("saving bulk data....")
        let managed_context = persistentContainer.viewContext
//        let managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
//        managedObjectContext.parent = persistentContainer.viewContext
//        managedObjectContext.perform(){
            autoreleasepool{
                self.semaphore.wait()
                self.delete_data_idx_bug()
//                let result = self.update_receipt_idx()
//                if result == false{
                    let entity_idx = NSEntityDescription.entity(forEntityName: "ReceiptIdx", in: managed_context)!
                    let receipt_idx = NSManagedObject(entity: entity_idx, insertInto: managed_context)
                    receipt_idx.setValue(self.idx_receipts, forKey:"idx")
//                }
                
                
                for i in 0 ... receipt_array.count - 1{
                    let entity = NSEntityDescription.entity(forEntityName: "ReceiptData", in: managed_context)!
                    let receipt = NSManagedObject(entity: entity, insertInto: managed_context)
                    receipt.setValue(receipt_array[i].location, forKey: "location")
                    receipt.setValue(receipt_array[i].date, forKey: "date")
                    receipt.setValue(receipt_array[i].category, forKey: "category")
                    receipt.setValue(receipt_array[i].account, forKey: "account")
                    receipt.setValue(receipt_array[i].tax, forKey: "tax")
                    if let result = images {
//                        let resize = result[i].resizeImage(image: result[i], targetSize: CGSize(width: result[i].size.width/6, height: result[i].size.height/6))
                        let ctx = CIContext()
                        let ciImage = CIImage(image: result[i])
                        let compressed_image = ctx.heifRepresentation(of: ciImage!, format: CIFormat.RGBA8, colorSpace: ctx.workingColorSpace!, options: [:])
                        receipt.setValue(compressed_image, forKey: "image")
                    }else{
                        receipt.setValue(receipt_array[i].image, forKey: "image")
                    }
                    receipt.setValue(receipt_array[i].total, forKey: "total")
                    receipt.setValue(receipt_array[i].id, forKey: "id")
                    receipt.setValue(receipt_array[i].currency_locale, forKey: "currency_locale")
                    receipt.setValue(receipt_array[i].currency_code, forKey: "currency_code")
                }
            }
            
            
            do{
                try managed_context.save()
            }catch{
                self.semaphore.signal()
                //NSLog("Error in saving context")
            }
            
            
            
            self.semaphore.signal()
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ImportCompleted"), object: nil)
//      }
        back_up_count()
    }
    func saveData(receipt_save: Receipt,image:UIImage){
        let container = persistentContainer
        container.performBackgroundTask(){ managed_context in
            self.semaphore.wait()
            self.delete_data_idx_bug()
            let entity = NSEntityDescription.entity(forEntityName: "ReceiptData", in: managed_context)!
            
//            let result = self.update_receipt_idx()
//            if result == false{
            let entity_idx = NSEntityDescription.entity(forEntityName: "ReceiptIdx", in: managed_context)!
            let receipt_idx = NSManagedObject(entity: entity_idx, insertInto: managed_context)
            receipt_idx.setValue(self.idx_receipts, forKey:"idx")
//            }
            let receipt = NSManagedObject(entity: entity, insertInto: managed_context)
            receipt.setValue(receipt_save.location, forKey: "location")
            receipt.setValue(receipt_save.date, forKey: "date")
            let ctx = CIContext()
            let ciImage = CIImage(image: image)
            let compressed_image = ctx.heifRepresentation(of: ciImage!, format: CIFormat.RGBA8, colorSpace: ctx.workingColorSpace!, options: [:])
            receipt.setValue(compressed_image, forKey: "image")
            receipt.setValue(receipt_save.total, forKey: "total")
            receipt.setValue(receipt_save.id, forKey: "id")
            receipt.setValue(receipt_save.account, forKey: "account")
            receipt.setValue(receipt_save.tax, forKey: "tax")
            receipt.setValue(receipt_save.category, forKey: "category")
            receipt.setValue(receipt_save.currency_locale, forKey: "currency_locale")
            receipt.setValue(receipt_save.currency_code, forKey: "currency_code")
            do{
                try managed_context.save()
            }catch{
                self.semaphore.signal()
                //NSLog("Error in saving context")
            }
            
            self.semaphore.signal()
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ImportCompleted"), object: nil)
        }
        back_up_count()
    }
    func back_up_count(){
        
        if (back_up_counter + 1) % 10 == 0{
            if receipts!.count > 40000 {
                if batteryState {
                    create_backup()
                }
            }else{
                create_backup()
            }
            
            back_up_counter = 0
        }
        back_up_counter += 1
        UserDefaults.standard.set(back_up_counter, forKey: "BackupKey")
    }
    func create_backup(){
        if autosave == false {
            return
        }
        // get the documents directory url
        let docDirectory = getDocumentsDirectory()
        let fileName = "backup_receipts"
        let fileURL = docDirectory.appendingPathComponent(fileName).appendingPathExtension("recp")
        var keywords = [String]()
        
        
        for i in 0 ..< self.receipts!.count {
            autoreleasepool{
                self.receipts![i].image = self.get_image_data(receipt: self.receipts![i])
                if let x = self.read_key_words(receipt: self.receipts![i]) {
                    keywords.append(x)
                }else{
                    keywords.append("")
                }
            }
        }
        var receipts : Receipts
        if let items = self.load_all_items() {
            receipts = Receipts(receipts: self.receipts!, items: items, bank_accounts:self.accounts?.bank_accounts ,credit_accounts: self.accounts?.credit_accounts, keywords: keywords)
        }else{
            receipts = Receipts(receipts: self.receipts!, items: nil, bank_accounts:self.accounts?.bank_accounts, credit_accounts: self.accounts?.credit_accounts, keywords: keywords)
        }
        
        do {
            let data = try PropertyListEncoder().encode(receipts)
            let p = q
            
            let v  = try aes.encrypt(data)
            let archive = try NSKeyedArchiver.archivedData(withRootObject: v, requiringSecureCoding: true)
            try archive.write(to: fileURL)
        } catch {
            //NSLog("Couldn't write file receipt...: \(error.localizedDescription)")
        }
    }
    
    func save_data_accounts() {
//        //NSLog("Saving accounts...")
        delete_data_accounts()
        let container = persistentContainer
        container.performBackgroundTask(){ managed_context in
            self.semaphore.wait()
            let total_accounts = self.accounts!.bank_accounts + self.accounts!.credit_accounts
            for i in 0 ..< total_accounts.count {
                autoreleasepool{
                    let entity = NSEntityDescription.entity(forEntityName: "Accounts", in: managed_context)!
                    let account = NSManagedObject(entity: entity, insertInto: managed_context)
                    account.setValue(total_accounts[i].account_type, forKey: "account_type")
                    account.setValue(total_accounts[i].account_name, forKey: "account_name")
                }
            }
            do{
                try managed_context.save()
            }catch{
                self.semaphore.signal()
                //NSLog("Error in saving context")
            }
            //NSLog("Done saving...")
            self.semaphore.signal()
        }
    }
    func delete_data_accounts(){
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Accounts")
        let request = NSBatchDeleteRequest(fetchRequest: fetch)
        do{
            try persistentContainer.viewContext.execute(request)
        }catch{
            //NSLog("could not delete all accounts data...")
        }
    }
    func delete_data_idx_bug(){
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "ReceiptIdx")
        let request = NSBatchDeleteRequest(fetchRequest: fetch)
        do{
            try persistentContainer.viewContext.execute(request)
        }catch{
            //NSLog("could not delete all accounts data...")
        }
    }
    func getDocumentsDirectory() -> URL {
        let docDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return docDirectory!
    }

    @available(iOS 10.0, *)
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "ReceiptBuddy")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}


//
//  ConfigureTableViewController.swift
//  ReceiptFriend
//
//  Created by THOMAS THOMPSON on 8/12/19.
//  Copyright © 2019 THOMAS THOMPSON. All rights reserved.
//

import UIKit
import MobileCoreServices
import SwiftSpinner
import CommonCrypto
class ConfigureTableViewController: UITableViewController, CurrencySelectorDelegate, AccountInputDelegate, AccountInfoDelegate, BackupDelegate, UIDocumentPickerDelegate, UITextFieldDelegate, MultiPictureDelegate, GeneralToggleDelegate {
    enum SettingsToggle {
        case auto_save
        case auto_fill
        case auto_save_receipts
    }
    func toggled_active(type: SettingsToggle, val: Bool) {
        switch(type){
            case .auto_save:
                self.delegate.set_autosave(value: val)
            case .auto_fill:
                self.delegate.set_autofill(value: val)
            case .auto_save_receipts:
                self.delegate.set_autosave_receipts(val: val)
        }
    }
    
    func switch_toggled(val: Bool) {
        self.delegate.set_multi_picture(val:val)
    }
    
    func select_date() {
        let navCtrl = UINavigationController(rootViewController: self.dateCtrl)
        self.navigationController!.present(navCtrl, animated: true) {}
    }
    
    @IBAction func back_btn_press(_ sender: Any) {
//        //NSLog("back btn pressed")
        self.navigationController?.popViewController(animated: true)
    }
    
    func change_backup_password() {
        let alert = UIAlertController(title: NSLocalizedString("Reset global password for backup", comment:""), message: NSLocalizedString("Please enter a secure password. This will be saved to your keychain for future use. Any and all backups created will use this password. If loading from a previous backup, please use the same password in order to load from that backup. If left blank, a hash will be stored for the password instead.", comment: ""), preferredStyle: .alert)
        alert.addTextField{ textField in
            textField.keyboardType = .default
            textField.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler:{ _ in
            return
        } ))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .default, handler: { [weak alert] _ in
            guard let textField = alert?.textFields!.first else { return }
            var string = String(textField.text!)
            if string == ""{
                string = "Default"
            }
            let bytes = self.delegate.s(string: string)
            //            let data = Data(bytes: bytes, count: bytes.count)
            KeyChain.delete(key: "ReceiptFriendK")
            let status = KeyChain.save(key: "ReceiptFriendK", data: bytes) //delete
            self.delegate.enableAES(key:bytes)
            
//            //NSLog("status: ", status)
            let alert_backup = UIAlertController(title: NSLocalizedString("Warning: Deleting the app will delete the autobackup file", comment:""),message:NSLocalizedString("Autosave places a backup file into the application's document directory. If you need to reinstall the app, make a backup and save it locally to the phone first in a different directory or your icloud account, then go to configure > restore to retrieve your receipts.", comment: ""), preferredStyle: .alert)
            
            alert_backup.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .default, handler: nil))
            
            if let _ = UserDefaults.standard.object(forKey: "AlertBackupS"){
                
            }else{
                self.present(alert_backup, animated: true)
                UserDefaults.standard.set(true, forKey: "AlertBackupS")
            }
        }))
        self.present(alert,animated: true)
    }
    
    func auto_fill_toggle(value: Bool) {
        self.delegate.set_autofill(value: value)
    }
    
    private let q : Double = 48129838144523847192938848191532
    
    func import_backup() {
        self.import_backup_items()
    }
    
    func auto_save_toggle(value:Bool){
        self.delegate.set_autosave(value:value)
    }
    
    @objc func import_completed(_ notification:NSNotification){
        SwiftSpinner.hide()
    }
    
    func create_backup() {
        if delegate.receipts!.count == 0 {
            SwiftSpinner.hide()
            let alert = UIAlertController(title: NSLocalizedString("No receipts have been found to backup", comment: ""), message: NSLocalizedString("Currently are no receipts saved to the system to backup, please input receipts to create a backup.", comment: ""), preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .cancel, handler: nil))
        
            self.present(alert,animated: true)
            return
        }
        
        self.create_backup_items()
    }
    func delete_pressed(cell_id: Int, account_type: Int) {
        if account_type == 0 {
            delegate.accounts?.bank_accounts.remove(at: cell_id)
        }else if account_type == 1 {
            delegate.accounts?.credit_accounts.remove(at: cell_id)
        }else if account_type == 2 {
            delegate.custom_categories?.remove(at: cell_id)
        }
        delegate.save_data_accounts()
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func account_added(account: String, type: Int) {
        if type == 0 {
            let account_input = Account(account_name: account, account_type: "Bank")
            delegate.accounts?.bank_accounts.append(account_input)
        }else if type == 1{
            let account_input = Account(account_name: account, account_type: "Credit")
            delegate.accounts?.credit_accounts.append(account_input)
        }else if type == 2 {
            #if DEBUG
            print("Result is: \(account)")
            #endif
            for i in self.delegate.custom_categories! {
                if i.contains(account) {
                    #if DEBUG
                    print("found already in custom categories")
                    #endif
                }
            }
            self.delegate.custom_categories!.append(account)
            if let data = stringArrayToData(stringArray: self.delegate.custom_categories!){
                if let d_encrypt = self.delegate.encrypt(data: data){
                    UserDefaults.standard.set(d_encrypt, forKey:"CustomCategoryKey")
                }
            }
            category_added()
        }
        delegate.save_data_accounts()
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    func category_added(){
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    private let delegate = UIApplication.shared.delegate as! AppDelegate
    private lazy var currencyCtrl:CurrencyController = {
        return CurrencyController()
    }()
    private lazy var dateCtrl:DateLocaleController = {
        return DateLocaleController()
    }()
    
    func select_currency() {
        let navCtrl = UINavigationController(rootViewController: self.currencyCtrl)
        self.navigationController!.present(navCtrl, animated: true) {}
    }
    
    private var tbKeyboard : UIToolbar?
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField.text! == "None"{
            textField.text! = ""
        }
        
        // if there's no tool bar, create it
        if tbKeyboard == nil {
            tbKeyboard = UIToolbar.init(frame: CGRect.init(x: 0, y: 0,
                                                           width: self.view.frame.size.width, height: 44))

            let done_btn = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: self, action: #selector(doneBtnPress))
            tbKeyboard?.items = [done_btn]
        }
        
        // set the tool bar as this text field's input accessory view
        textField.inputAccessoryView = tbKeyboard
        return true
    }
    @objc func doneBtnPress(){
        self.view.endEditing(true)
    }
    @objc func currency_selected(_ notification:Notification){
        if let currencies = notification.object as? [Currency] {
            delegate.currency = currencies[0].currencyLocal
            delegate.currency_code = currencies[0].currencyCode
            UserDefaults.standard.set(delegate.currency_code, forKey: "CurrencyCode")
            self.tableView.reloadData()
        }
        
        
    }
    @objc func date_selected(_ notification:Notification){
        if let datelocal = notification.object as? Currency {
            let loc = datelocal.currencyLocal
            delegate.date_local = loc
            UserDefaults.standard.set(delegate.date_local?.identifier, forKey: "DateLocale")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.delegate.get_purchased() {

            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
//        self.tableView.contentInset = UIEdgeInsets(top: 0,left: 0,bottom: 50,right: 0)
        self.tableView.dataSource = self
        self.tableView.delegate = self
         self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationItem.backBarButtonItem?.tintColor = .white
        let nib_receipt = UINib(nibName: "ConfigCell", bundle: nil)
        self.tableView.register(nib_receipt, forCellReuseIdentifier: "ConfigCell")
//        self.tableView.isScrollEnabled = false
        
        let nib_receipt_currency = UINib(nibName: "CurrencySelectorCell", bundle: nil)
        self.tableView.register(nib_receipt_currency, forCellReuseIdentifier: "CurrencySelectorCell")
        let nib_receipt_account = UINib(nibName: "AccountInputTableViewCell", bundle: nil)
        self.tableView.register(nib_receipt_account, forCellReuseIdentifier: "AccountInputTableViewCell")
        
        let nib_receipt_account_info = UINib(nibName: "AccountInfoTableViewCell", bundle: nil)
        self.tableView.register(nib_receipt_account_info, forCellReuseIdentifier: "AccountInfoTableViewCell")
        let nib_multi_picture = UINib(nibName: "MultiPicture", bundle: nil)
        self.tableView.register(nib_multi_picture, forCellReuseIdentifier: "MultiPicture")
        let nib_general_toggle = UINib(nibName: "GeneralToggleTableViewCell", bundle: nil)
        self.tableView.register(nib_general_toggle, forCellReuseIdentifier: "GeneralToggleTableViewCell")
        let nib_general_cell = UINib(nibName: "DefaultTableViewCell", bundle: nil)
        self.tableView.register(nib_general_cell, forCellReuseIdentifier: "DefaultTableViewCell")
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.currency_selected(_:)), name: NSNotification.Name(rawValue: "selectedCurrency"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.date_selected(_:)), name: NSNotification.Name(rawValue: "selectedDate"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.import_completed(_:)), name: NSNotification.Name(rawValue: "ImportCompleted"), object: nil)
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    // MARK: - Table view data source
    private var num_sections = 6
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        if self.delegate.in_eea {
//            //NSLog("inside")
            return num_sections + 1
        }
        #if DEBUG
        print("num_sections: \(num_sections)")
        #endif
        return num_sections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch(section){
        case 0:
            return 1
        case 1:
            return 4
        case 2:
            if let n_ = self.delegate.accounts?.get_bank_account_num() {
                return (1 + n_)
            }
            return 1
        case 3:
            if let n_ = self.delegate.accounts?.get_credit_account_num() {
                return (1 + n_)
            }
            return 1
        case 4:
            if let n_ = self.delegate.custom_categories?.count {
                #if DEBUG
                print("number of custom categories: \(self.delegate.custom_categories!.count)")
                #endif
                return (1 + n_)
            }
            return 1
        case 5:
            return 1
        case 6:
            return 1
        case 7:
            return 1
        default:
            break
        }
        return 0
        // #warning Incomplete implementation, return the number of rows
        
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch(section){
        case 0:
            return NSLocalizedString("Export/Import Backup", comment: "")
        case 1:
            return NSLocalizedString("Settings", comment: "")
        case 2:
            return NSLocalizedString("Bank Accounts:", comment: "")
        case 3:
            return NSLocalizedString("Credit Cards Accounts: ", comment: "")
        case 4:
            return NSLocalizedString("Custom Category: ", comment: "")
        case 5:
            return NSLocalizedString("Multi-Picture Mode", comment: "")
        case 6:
            return NSLocalizedString("Ad Settings", comment: "")
        default:
            return ""
        }

    }
    

    func display_alert(urls:[URL]){
        SwiftSpinner.hide()
        let st = NSLocalizedString("the file:",comment:"") + "\(urls[0].lastPathComponent)" +  NSLocalizedString("could not be opened", comment: "")
        let alert = UIAlertController(title: NSLocalizedString("File was either incorrect or corrupt", comment: ""), message: st, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .cancel, handler: nil))
        self.present(alert,animated:false)
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 93.00
        }else{
            return 44.00
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        #if DEBUG
        print("Cell row is: \(indexPath.row) section: \(indexPath.section)")
        #endif
        switch(indexPath.section){
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConfigCell", for: indexPath) as! ConfigCell
            cell.selectionStyle = .none
            cell.delegate = self
            return cell
        case 1:
            switch(indexPath.row){
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: "CurrencySelectorCell", for: indexPath) as! CurrencySelectorCell
                cell.selectionStyle = .none
                cell.delegate = self
                cell.currency_label.text = NSLocalizedString("Currency: ", comment: "") + (delegate.currency_code ?? "")
                return cell
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: "GeneralToggleTableViewCell") as! GeneralToggleTableViewCell
                cell.delegate = self
                cell.selectionStyle = .none
                cell.settings_type = .auto_save
                cell.title.text = NSLocalizedString("Autosave", comment: "")
                if let value = UserDefaults.standard.object(forKey: "AutoSave") as? Bool{
                    cell.toggle_btn.isOn = value
                }
                return cell
            case 2:
                let cell = tableView.dequeueReusableCell(withIdentifier: "GeneralToggleTableViewCell") as! GeneralToggleTableViewCell
                cell.delegate = self
                cell.selectionStyle = .none
                cell.settings_type = .auto_fill
                cell.title.text = NSLocalizedString("Autofill", comment: "")
                if let value_auto = UserDefaults.standard.object(forKey: "AutoFill") as? Bool {
                    cell.toggle_btn.isOn = value_auto
                }
                return cell
            case 3:
                let cell = tableView.dequeueReusableCell(withIdentifier: "GeneralToggleTableViewCell") as! GeneralToggleTableViewCell
                cell.delegate = self
                cell.selectionStyle = .none
                cell.settings_type = .auto_save_receipts
                cell.title.text = NSLocalizedString("Edit Receipt Autosave on Dismiss ", comment: "")
                if let value_auto = UserDefaults.standard.object(forKey: "AutoSaveReceipts") as? Bool {
                    cell.toggle_btn.isOn = value_auto
                }
                return cell
            default:
                break
            }

        case 2:
            
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "AccountInputTableViewCell", for: indexPath) as! AccountInputTableViewCell
                cell.selectionStyle = .none
                cell.delegate = self
                cell.account_field.tag = 0
                cell.account_field.delegate = self
                cell.name_label.text = NSLocalizedString("Bank Name:", comment: "")
                cell.account_type = 0
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "AccountInfoTableViewCell", for: indexPath) as! AccountInfoTableViewCell
                cell.delegate = self
                cell.selectionStyle = .none
                cell.account_name_field.text = self.delegate.accounts?.bank_accounts[indexPath.row - 1].account_name
                cell.cell_id = indexPath.row - 1
                cell.account_type = 0
                return cell
            }
            
        case 3:
            
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "AccountInputTableViewCell", for: indexPath) as! AccountInputTableViewCell
                cell.selectionStyle = .none
                cell.delegate = self
                cell.account_field.delegate = self
                cell.account_field.tag = 1
                cell.name_label.text = NSLocalizedString("Credit Card Name:", comment: "")
                cell.account_type = 1
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "AccountInfoTableViewCell", for: indexPath) as! AccountInfoTableViewCell
                cell.delegate = self
                cell.selectionStyle = .none
                cell.account_name_field.text = self.delegate.accounts?.credit_accounts[indexPath.row - 1].account_name
                cell.cell_id = indexPath.row - 1
                cell.account_type = 1
                return cell
            }
            
        case 4:
            
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "AccountInputTableViewCell", for: indexPath) as! AccountInputTableViewCell
                cell.selectionStyle = .none
                cell.delegate = self
                cell.account_field.delegate = self
                cell.account_field.tag = 2
                cell.name_label.text = NSLocalizedString("Custom Category: ", comment: "")
                cell.account_type = 2
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "AccountInfoTableViewCell", for: indexPath) as! AccountInfoTableViewCell
                cell.delegate = self
                cell.selectionStyle = .none
                cell.account_name_field.text = self.delegate.custom_categories![indexPath.row - 1]
                cell.cell_id = indexPath.row - 1
                cell.account_type = 2
                return cell
            }
            
        case 5:
            #if DEBUG
            print("returning multi-picture")
            #endif
            let cell = tableView.dequeueReusableCell(withIdentifier: "MultiPicture", for: indexPath) as! MultiPicture
            cell.multi_picture_mode_label.text = NSLocalizedString("Multi-Picture", comment: "")
            cell.delegate = self
            cell.selectionStyle = .none
            return cell
            
        case 6:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultTableViewCell", for: indexPath) as! DefaultTableViewCell
            cell.label_inside_cell.text = NSLocalizedString("Ad Privacy", comment: "")
            return cell
            
        default:
            break
        }
        return ConfigCell()
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        //NSLog("selection occured...")
        if indexPath.section == 7 {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "LoadForm"), object: nil, userInfo: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 33.00
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if indexPath.section == 0{
            return .none
        }
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                return .none
            }
        }
        if indexPath.section == 2 {
            if indexPath.row == 0 {
                return .none
            }
        }
        if indexPath.section == 3 {
            if indexPath.row == 0 {
                return .none
            }
        }
        if indexPath.section == 4 {
            if indexPath.row == 0 {
                return .none
            }
        }
        if indexPath.section == 5 {
            if indexPath.row == 0 {
                return .none
            }
        }
        return .delete
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if indexPath.section == 1 {
                if indexPath.row != 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "AccountInfoTableViewCell", for: indexPath) as! AccountInfoTableViewCell
                    cell.delegate?.delete_pressed(cell_id: cell.cell_id, account_type: cell.account_type!)
                }
            }else if indexPath.section == 2 {
                if indexPath.row != 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "AccountInfoTableViewCell", for: indexPath) as! AccountInfoTableViewCell
                    cell.delegate?.delete_pressed(cell_id: cell.cell_id, account_type: cell.account_type!)
                }
            }else if indexPath.section == 3 {
                if indexPath.row != 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "AccountInfoTableViewCell", for: indexPath) as! AccountInfoTableViewCell
                    self.delegate.custom_categories!.remove(at: cell.cell_id)
                    if let data = stringArrayToData(stringArray: self.delegate.custom_categories!){
                        if let d_encrypt = self.delegate.encrypt(data: data){
                            UserDefaults.standard.set(d_encrypt, forKey:"CustomCategoryKey")
                        }
                    }
                }
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == 0 {
            if !textField.text!.isEmpty {
                account_added(account: textField.text!, type: 0)
                textField.text! = ""
            }
            return false
        }else if textField.tag == 1 {
            if !textField.text!.isEmpty {
                account_added(account: textField.text!, type: 1)
                textField.text! = ""
            }
            return false
        }else if textField.tag == 2 {
            if let result = textField.text {
                #if DEBUG
                print("Result is: \(result)")
                #endif
                for i in self.delegate.custom_categories! {
                    if i.contains(result) {
                        #if DEBUG
                        print("found already in custom categories")
                        #endif
                        return true
                    }
                }
                self.delegate.custom_categories!.append(result)
                if let data = stringArrayToData(stringArray: self.delegate.custom_categories!){
                    if let d_encrypt = self.delegate.encrypt(data: data){
                        UserDefaults.standard.set(d_encrypt, forKey:"CustomCategoryKey")
                    }
                }
                textField.text! = ""
                category_added()
                return false
            }
        }
        return false
    }
    
    func create_backup_items(){
        // get the documents directory url
        
        let temp_dir = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
        var objectsToShare : [URL] = [URL]()
        let fileName = NSLocalizedString("backup_receipts", comment: "")
        let fileURL = temp_dir.appendingPathComponent(fileName).appendingPathExtension("recp")
        var keywords = [String]()
        for i in 0 ..< delegate.receipts!.count {
            self.delegate.receipts![i].image = delegate.get_image_data(receipt: delegate.receipts![i])
            if let x = self.delegate.read_key_words(receipt: self.delegate.receipts![i]) {
                keywords.append(x)
            }else{
                keywords.append("")
            }
        }
        
        var receipts : Receipts
        
        if let items = delegate.load_all_items() {
            receipts = Receipts(receipts: self.delegate.receipts!, items: items, bank_accounts:self.delegate.accounts?.bank_accounts ,credit_accounts: delegate.accounts?.credit_accounts, keywords: keywords)
        }else{
            receipts = Receipts(receipts: self.delegate.receipts!, items: nil, bank_accounts:delegate.accounts?.bank_accounts, credit_accounts: delegate.accounts?.credit_accounts, keywords: keywords)
        }
        
        do {
            let data = try PropertyListEncoder().encode(receipts)
           
            if let v  = delegate.encrypt(data: data){
                let archive = try NSKeyedArchiver.archivedData(withRootObject: v, requiringSecureCoding: false)
                try archive.write(to: fileURL)
            }else {
                //NSLog("could not encrypt...")
            }
            
            
            
        } catch {
            //NSLog("Couldn't write file receipt...: \(error.localizedDescription)")
        }
        
        objectsToShare.append(fileURL)
        display_picker(objectsToShare : objectsToShare)
    }
    
    func display_picker(objectsToShare : [URL]){
        let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(urls:objectsToShare, in: .exportToService)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        self.present(documentPicker, animated: true, completion: nil)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ImportCompleted"), object: nil)
        }
    }
    
    private var import_check = false
    func import_backup_items(){
        let alert = UIAlertController(title: NSLocalizedString("Warning: Current receipts will be overwritten", comment: ""), message: NSLocalizedString("Restoration replaces all receipts currently in the system, effectively deleting the receipts, and then replacing them with the backup file. Press yes to continue.", comment: ""), preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: ""), style: .default, handler: { action in
            self.import_check = true
            let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(documentTypes: [kUTTypeItem as String], in: .import)
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            self.present(documentPicker, animated: true, completion: nil)
        }))
        self.present(alert,animated: true)
        
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        if import_check == true {
            import_check = false
            SwiftSpinner.show(NSLocalizedString("Restoring backup...", comment: ""))
            for i in urls{
                if i.pathExtension != "recp" {
                    SwiftSpinner.hide()
                    return
                }
            }
            do{
                let data = try Data(contentsOf: urls[0])
                if let result = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? Data{
                    if let v = self.delegate.decrypt(data:result){
                        do{
                            
                            let final_result = try PropertyListDecoder().decode(Receipts.self, from: v)
                            //Assign constant properties
                            self.delegate.receipts! = final_result.receipts!
                            let keywords = final_result.keywords
                            var idx = 0
                            for i in 0 ..< self.delegate.receipts!.count {
                                self.delegate.receipts![i].id = idx
                                if let result = keywords?[i] {
                                    self.delegate.save_key_words(id: self.delegate.receipts![i].id, key_words: result)
                                }else{
                                    self.delegate.save_key_words(id: self.delegate.receipts![i].id, key_words: "")
                                }
                                
                                idx += 1
                            }
                            for i in 0 ..< self.delegate.receipts!.count {
                                
                                let result = categories.filter({
                                    $0 == self.delegate.receipts![i].category
                                })
                                #if DEBUG
                                print("count is: \(result.count)")
                                #endif
                                if result.count == 0 && self.delegate.receipts![i].category != ""{
                                    self.delegate.custom_categories?.append(self.delegate.receipts![i].category)
                                }
                                
                            }
                            
                            self.delegate.accounts?.bank_accounts = final_result.bank_accounts
                            self.delegate.accounts?.credit_accounts = final_result.credit_accounts
                            //Delete the current data store
                            self.delegate.delete_data_store()
                            self.delegate.idx_receipts = self.delegate.receipts!.last!.id
                            //Save the data to the coredata database
                            self.delegate.saveBulkData(receipt_array: self.delegate.receipts!, images: nil)
                            self.delegate.save_data_accounts()
                            if final_result.items != nil {
                                self.delegate.save_item_data(items: final_result.items!, id: -1)
                            }
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                            }
                            SwiftSpinner.hide()
                        }catch{
                            SwiftSpinner.hide()
                            let alert = UIAlertController(title: NSLocalizedString("Backup could not be loaded", comment: ""), message: NSLocalizedString("Passwords set for backups may not match or file is corrupt", comment: ""), preferredStyle: .alert)
                            
                            alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .cancel, handler: nil))
                            self.present(alert,animated: false)
                            //NSLog("Decode no worky: \(error.localizedDescription)")
                        }
                    }else{
                        let alert = UIAlertController(title: NSLocalizedString("Backup could not be loaded", comment: ""), message: NSLocalizedString("Passwords set for backups may not match or file is corrupt", comment: ""), preferredStyle: .alert)
                        
                        alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .cancel, handler: nil))
                        self.present(alert,animated: false)
                    }
                }
            }catch{
                display_alert(urls: urls)
            }
            
        }
        
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

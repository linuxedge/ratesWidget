//
//  ViewController.swift
//  Rates
//
//  Created by Aaron Serrano on 18/2/17.
//  Copyright © 2017 LinuxEdge. All rights reserved.
//

import UIKit
import SystemConfiguration
import UserNotifications

class ViewController: UIViewController {
    @IBOutlet weak var currentRate: UILabel!
    @IBOutlet weak var hiRate: UILabel!
    @IBOutlet weak var lowRate: UILabel!
    @IBOutlet weak var btnRefresh: UIButton!
    @IBOutlet weak var lblRefresh: UILabel!
    @IBOutlet weak var lblCurrRate: UILabel!
    @IBOutlet weak var progBar: UIActivityIndicatorView!
    @IBOutlet weak var rate: UILabel!

     var ratesURL : String = "https://www.dbs.com.sg/personal/rates-online/foreign-currency-foreign-exchange.page?pid=sg-dbs-pweb-home-span4module-forex-txtmore-"
     var alertMessage : String?
     var currRate : Float = 00.00
     var scheduled = false
     var taskManger = Timer()
     
     override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
          
          initialize()
          progBar.isHidden = true
          btnRefresh.layer.cornerRadius = 5
          btnRefresh.layer.borderWidth = 1
          btnRefresh.layer.borderColor = UIColor.yellow.cgColor
          fetchRates()
          btnRefresh.addTarget(self, action: #selector(self.refreshTapped(_:)), for: .touchDown)

     }
     
     func initialize() {
          self.Logger(log: "Initializing screen..")
          checkRates()
     }

     override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
     }

    
     func refreshTapped(_ button: UIButton) {
     
          currentRate.isHidden = true
          progBar.isHidden = false
          lblCurrRate.text = "Connecting to DBS"
          rate.text = " "
          let when = DispatchTime.now() + 0.2
          DispatchQueue.main.asyncAfter(deadline: when) {
               self.fetchRates()
          }

     }
     
     func fetchRates() {
          
          Logger(log: "Start...")
        
          // Check for Internet Connection
          if self.isInternetAvailable() {
               
               // Set current date and time to Update Date & Time in Widget.
               self.lblRefresh.text = DateFormatter.localizedString(from: NSDate() as Date, dateStyle: .medium , timeStyle: .short)
               
               self.parseHTML()
          } else {
               
               // No Internet Connection - Set Update Label to No Internet
               self.lblRefresh.text = "No Internet"
          }
          
          self.Logger(log: "Widget Invocation Complete...")

     }
     
     func parseHTML() {
          // Parse HTML from DBS Website
          
          self.Logger(log: "Checking DBS FX Rates...")
          guard let myURL = URL(string: self.ratesURL) else {
               self.Logger(log: "Error: \(self.ratesURL) doesn't seem to be a valid URL")
               self.lblRefresh.text = "Invalid URL"
               return
          }
          
          do {
               let myHTMLString = try String(contentsOf: myURL, encoding: .ascii)
               self.Logger(log: "Rates HTML found...")
               let us = myHTMLString
               let range = us.range(of:"(?<=<span>Philippine Peso</span></th><th class=\"column-2 mobile-no-border-red\" data-label=\"Unit\" data-group-label=\"For amounts up to S\\$200,000\">100</th><td class=\"column-3\" data-label=\"Selling TT/OD\">)[^*]+(?=</td><td class=\"column-4 odd\" data-label=\"Buying TT\">0.0000</td><td class=\"column-5 last last-coulmn\" data-label=\"Buying OD\">0.0000</td>\n</tr>\n<tr class=\"odd filter_currency filter_New_Taiwan_Dollar\">)", options:.regularExpression)
               
               if range != nil {
                    rate.text = String(Float(us.substring(with: range!))!)
                    self.currRate = 100 / Float(us.substring(with: range!))!
                    self.checkRates()
               }
               
          } catch let error {
               self.lblRefresh.text = "Parsing Error"
               self.Logger(log: "Parse Error \(error)")
          }
          
          self.Logger(log: "Rates Updated...")
          
     }
     
     func checkRates() {
          // Set values to High and Low
          
          progBar.isHidden = true
          currentRate.isHidden = false
          lblCurrRate.text = "CURRENT RATE"
          self.currentRate.text = String(format: "%.2f", self.currRate)
          
          let hiRateKey = "hiRate"
          let lowRateKey = "lowRate"
          let prevRateKey = "prevRate"
          
          let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as NSArray
          let documentDirectory = paths[0] as! String
          let path = documentDirectory.appending("/Rates.plist")
          let fileManager = FileManager.default
          if (!fileManager.fileExists(atPath: path)) {
               if let bundlePath = Bundle.main.path(forResource: "Rates", ofType: "plist") {
                    let result = NSMutableDictionary(contentsOfFile: bundlePath)
                    self.Logger(log: "Bundle File: \(result?.description)")
                    do{
                         try fileManager.copyItem(atPath: bundlePath, toPath: path)
                    }catch{
                         self.lblRefresh.text = "Fail PList Copy"
                    }
               } else {
                    self.lblRefresh.text = "PList not found"
               }
          }
          
          //let resultDictionary = NSMutableDictionary(contentsOfFile: path)
          
          let myDict = NSDictionary(contentsOfFile: path)
          if let dict = myDict {
               
               let hiRateValue = dict.object(forKey: hiRateKey) as! String?
               let lowRateValue = dict.object(forKey: lowRateKey) as! String?
               let prevRateValue = dict.object(forKey: prevRateKey) as! String?
               
               //hiRateValue = "35.23"
               //lowRateValue = "34.17"
               
               let dict : NSMutableDictionary = [:]
               
               if hiRateValue != " " {
                    let fltHiRate = Float(hiRateValue!)
                    if fltHiRate! < self.currRate {
                         dict.setObject(String(format: "%.2f", self.currRate), forKey: hiRateKey as NSCopying)
                    } else {
                         dict.setObject(String(format: "%.2f", fltHiRate!), forKey: hiRateKey as NSCopying)
                    }
               } else {
                    dict.setObject(String(format: "%.2f", self.currRate), forKey: hiRateKey as NSCopying)
               }
               self.hiRate.text = dict.object(forKey: hiRateKey) as! String?
               
               if lowRateValue != " " || lowRateValue != "00.00" {
                    let fltLowRate = Float(lowRateValue!)
                    if fltLowRate! > self.currRate || fltLowRate! == 00.00 {
                         dict.setObject(String(format: "%.2f", self.currRate), forKey: lowRateKey as NSCopying)
                    } else {
                         dict.setObject(String(format: "%.2f", fltLowRate!), forKey: lowRateKey as NSCopying)
                    }
               } else {
                    dict.setObject(String(format: "%.2f", self.currRate), forKey: lowRateKey as NSCopying)
               }
               self.lowRate.text = dict.object(forKey: lowRateKey) as! String?
               
               self.currentRate.textColor = UIColor(red: 0.243, green: 0.603, blue: 0.643, alpha: 1)
               
               dict.setObject(String(format: "%.2f", self.currRate), forKey: prevRateKey as NSCopying)
               dict.write(toFile: path, atomically: false)
               
          } else {
               let dict : NSMutableDictionary = [:]
               dict.setObject(String(format: "%.2f", self.currRate), forKey: hiRateKey as NSCopying)
               dict.setObject(String(format: "%.2f", self.currRate), forKey: lowRateKey as NSCopying)
               dict.setObject(String(format: "%.2f", self.currRate), forKey: prevRateKey as NSCopying)
               dict.write(toFile: path, atomically: false)
               self.hiRate.text = dict.object(forKey: hiRateKey) as! String?
               self.lowRate.text = dict.object(forKey: lowRateKey) as! String?
          }
          
     }
     
     
     func isInternetAvailable() -> Bool {
          // Internet connection checking
          var zeroAddress = sockaddr_in()
          zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
          zeroAddress.sin_family = sa_family_t(AF_INET)
          
          guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
               $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    SCNetworkReachabilityCreateWithAddress(nil, $0)
               }
          }) else {
               return false
          }
          
          var flags: SCNetworkReachabilityFlags = []
          if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
               return false
          }
          
          let isReachable = flags.contains(.reachable)
          let needsConnection = flags.contains(.connectionRequired)
          
          return (isReachable && !needsConnection)
     }
     
     func Logger(log: String) {
          // Developer logs
          print("DevLog: \(DateFormatter.localizedString(from: NSDate() as Date, dateStyle: .medium , timeStyle: .long))   \(log)" )
     }
     
}


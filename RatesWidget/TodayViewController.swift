//
//  TodayViewController.swift
//  CurrencyMonitorWidget
//
//  Created by Aaron Serrano on 12/2/17.
//  Copyright © 2017 LinuxEdge. All rights reserved.
//
//  Created via XCode 8.2.1 with Development Target of iOS 8.0
//
//  This Widget will display the current exchange rate from DBS Singapore Web Site
//

import UIKit
import NotificationCenter
import SystemConfiguration

class TodayViewController: UIViewController, NCWidgetProviding {
    @IBOutlet weak var currentRate: UILabel!
    @IBOutlet weak var updateTime: UILabel!
    @IBOutlet weak var hiRate: UILabel!
    @IBOutlet weak var loRate: UILabel!
    @IBOutlet weak var progBar: UIActivityIndicatorView!
    @IBOutlet weak var rate: UILabel!
    
    var taskManager = Timer()
    var currRate : Float = 00.00
    var newRate : Float = 00.00
    var ratesURL : String = "https://www.dbs.com.sg/personal/rates-online/foreign-currency-foreign-exchange.page?pid=sg-dbs-pweb-home-span4module-forex-txtmore-"
    let fileName = "CurrencyMonitorRates"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Invokes the main process
        
        self.updateTime.text = "Initializing..."
        progBar.isHidden = true
        fetchRates()
        
    }
    
    func fetchRates() {
        
        Logger(log: "Start...")
        
        // Check for Internet Connection
        if self.isInternetAvailable() {
            
            self.currentRate.isHidden = true
            self.progBar.isHidden = false
            self.updateTime.text = "Connecting to DBS"
            let when = DispatchTime.now() + 0.2
            DispatchQueue.main.asyncAfter(deadline: when) {
                self.parseHTML()
            }
            
            // Set current date and time to Update Date & Time in Widget.
            self.updateTime.text = DateFormatter.localizedString(from: NSDate() as Date, dateStyle: .medium , timeStyle: .short)

        } else {
            
            // No Internet Connection - Set Update Label to No Internet
            self.updateTime.text = "No Internet"
        }
        
        self.Logger(log: "Widget Invocation Complete...")
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapFunction(sender:)))
        self.currentRate.isUserInteractionEnabled = true
        self.currentRate.addGestureRecognizer(tap)
        
    }
    
    func tapFunction(sender:UITapGestureRecognizer) {
        //Reload when tapped
        
        self.fetchRates()

    }
    
    
    func parseHTML() {
        // Parse HTML from DBS Website
        
        self.Logger(log: "Checking DBS FX Rates...")
        guard let myURL = URL(string: self.ratesURL) else {
            self.Logger(log: "Error: \(self.ratesURL) doesn't seem to be a valid URL")
            self.updateTime.text = "Invalid URL"
            return
        }
        
        do {
            let myHTMLString = try String(contentsOf: myURL, encoding: .ascii)
            self.Logger(log: "Rates HTML found...")
            let us = myHTMLString
            let range = us.range(of:"(?<=<span>Philippine Peso</span></th><th class=\"column-2 mobile-no-border-red\" data-label=\"Unit\" data-group-label=\"For amounts up to S\\$200,000\">100</th><td class=\"column-3\" data-label=\"Selling TT/OD\">)[^*]+(?=</td><td class=\"column-4 odd\" data-label=\"Buying TT\">0.0000</td><td class=\"column-5 last last-coulmn\" data-label=\"Buying OD\">0.0000</td>\n</tr>\n<tr class=\"odd filter_currency filter_New_Taiwan_Dollar\">)", options:.regularExpression)
            
            if range != nil {
                self.newRate = Float(us.substring(with: range!))!
                self.currRate = 100 / Float(us.substring(with: range!))!
                self.checkRates()
            }
            
        } catch let error {
            self.updateTime.text = "Parsing Error"
            self.Logger(log: "Parse Error \(error)")
        }
        
        self.Logger(log: "Rates Updated...")
        
    }
    
    
    func checkRates() {
        // Set values to High and Low
        
        self.progBar.isHidden = true
        self.currentRate.isHidden = false
        self.currentRate.text = String(format: "%.2f", self.currRate)
        self.rate.text = String(format: "%.4f", self.newRate)
        
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
                    self.updateTime.text = "Fail PList Copy"
                }
            } else {
                self.updateTime.text = "PList not found"
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
            
            if lowRateValue != " " {
                let fltLowRate = Float(lowRateValue!)
                if fltLowRate! > self.currRate {
                    dict.setObject(String(format: "%.2f", self.currRate), forKey: lowRateKey as NSCopying)
                } else {
                    dict.setObject(String(format: "%.2f", fltLowRate!), forKey: lowRateKey as NSCopying)
                }
            } else {
                dict.setObject(String(format: "%.2f", self.currRate), forKey: lowRateKey as NSCopying)
            }
            self.loRate.text = dict.object(forKey: lowRateKey) as! String?
            
            //if prevRateValue != " " {
            //    let fltPrevRate = Float(prevRateValue!)
            //if fltPrevRate! < self.currRate {
            //        self.currentRate.textColor = UIColor(red: 0.243, green: 0.603, blue: 0.643, alpha: 1)
            //    } else {
            //        self.currentRate.textColor = UIColor(red: 255, green: 233, blue: 0, alpha: 1)
            //    }
            //} else {
            //self.currentRate.textColor = UIColor(red: 0.243, green: 0.603, blue: 0.643, alpha: 1)
            //}
            
            dict.setObject(String(format: "%.2f", self.currRate), forKey: prevRateKey as NSCopying)
            dict.write(toFile: path, atomically: false)
            
        } else {
            let dict : NSMutableDictionary = [:]
            dict.setObject(String(format: "%.2f", self.currRate), forKey: hiRateKey as NSCopying)
            dict.setObject(String(format: "%.2f", self.currRate), forKey: lowRateKey as NSCopying)
            dict.setObject(String(format: "%.2f", self.currRate), forKey: prevRateKey as NSCopying)
            dict.write(toFile: path, atomically: false)
            self.hiRate.text = dict.object(forKey: hiRateKey) as! String?
            self.loRate.text = dict.object(forKey: lowRateKey) as! String?
        }
        
    }
    
    
    func widgetMarginInsets(forProposedMarginInsets defaultMarginInsets: UIEdgeInsets) -> UIEdgeInsets {
        // Sets margin to 0
        return UIEdgeInsetsMake(0, 0, 0, 0)
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(NCUpdateResult.newData)
    }
    
}

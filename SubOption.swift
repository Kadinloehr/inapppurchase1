//
//  SubOption.swift
//  ISAT NEWS
//
//  Created by kadin on 10/17/17.
//  Copyright © 2017 Kadin Loehr. All rights reserved.
//
import Foundation
import StoreKit
//The default new project in Xcode contains already a flag to check if we're in debug or not
//We need to use th default macro in order to do that
#if DEBUG
let isDebug = true
#else
let isDebug = false
#endif

//iTunes server urls
enum ReceiptVaildationItunesURLS:String{
    
    case sandbox = "https://sandbox.itunes.apple.com/verifyReceipt"
    case production = "https://buy.itunes.apple.com/verifyReceipt"
    
    
    
    //Let's adjust our enum so it returns the correct link based on the enviroument
    static var url:URL {
        
        if isDebug{
            
            return URL.init(string: ReceiptVaildationItunesURLS.sandbox.rawValue)!
        }else{
            
            return URL.init(string: ReceiptVaildationItunesURLS.production.rawValue)!
        }
    }
    
    
}



extension ReceiptManager:SKRequestDelegate{
    
    func requestDidFinish(_ request: SKRequest) {
        
        //Now if the refresh request is finished then we need to call our startVaildating function again to start the whole process again. But in order to not stuck in a loop if the receipt never exist we need to add some extra logic
        
        self.StartVaildatingReceipts()
        
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Error refreshing receipt",error.localizedDescription)
    }
}


class ReceiptManager: NSObject {
    
    
    
    override init() {
        super.init()
        
        print("init ReceiptManager")
        
        //This function will be called when we init our ReceiptManager in the StoreManager CLass
        UserDefaults.standard.set(false, forKey: "didRefreshReceipt")
        self.StartVaildatingReceipts()
    }
    
    
    func StartVaildatingReceipts(){
        
        
        if let isExist = try? self.getReceiptURL()?.checkResourceIsReachable(),isExist == true{
            
            do{
                
                let receiptData = try Data(contentsOf: self.getReceiptURL()!)
                
                
                //Start vaildating the receipt with iTunes server
                self.vaildateData(data: receiptData)
                
                print("Receipt exist")
                
            }catch{
                print("Not able to get data from URL")
                
            }
            
        }else{
            guard UserDefaults.standard.bool(forKey: "didRefreshReceipt") == false else {
                print("Stopping after second attempt")
                return
            }
            
            UserDefaults.standard.set(true, forKey: "didRefreshReceipt")
            
            
            //Now if we try to load the receipt from local and for some reason the url doesn't exist, we need to make SKReceiptRefreshRequest we mentioned ealier
            
            
            let receiptRequest = SKReceiptRefreshRequest()
            receiptRequest.delegate = self
            receiptRequest.start()
            
            print("Receipt URL Doesn't exist")
            
        }
        
    }
    
    
    
    
    func getReceiptURL() -> URL? {
        return Bundle.main.appStoreReceiptURL
    }
    
    
    
    func vaildateData(data:Data){
        
        //First we need to encode the data to base64
        let receiptsString = data.base64EncodedString(options: Data.Base64EncodingOptions.init(rawValue: 0))
        
        
        //Now we need to wrap our data with our Secret Shared and then send it to apple server
        var dic:[String:AnyObject] = ["receipt-data":receiptsString as AnyObject]
        
        let sharedSecret = "d41e0399c4ee4fd8baca5718840c1c67" //<< This is my sharedSecret yours is different
        dic["password"] = sharedSecret as AnyObject?
        
        
        //Serialize the dictionary to JSON data
        let json = try! JSONSerialization.data(withJSONObject: dic, options: [])
        
        
        
        //Create a URLRequest
        var urlRequest = URLRequest(url: ReceiptVaildationItunesURLS.url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = json
        
        
        //Let's use the shared URLSession to send the request
        
        let session = URLSession.shared
        
        let task = session.dataTask(with: urlRequest) { (data:Data?, response:URLResponse?, error:Error?) in
            
            if let receiptData = data{
                
                self.handleData(data: receiptData)
                
            }else{
                
                
                print("Error vaildating receipt with itunes connect")
            }
            
            
        }
        
        
        //WE need to tell the task to start
        task.resume()
        
    }
    
    
    
    //Let's create a function handle our retured data
    func handleData(data:Data){
        
        
        //First we need to decode the data back to JSON
        
        guard let json = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary else {
            print("Not able to encode jsonObject")
            return
        }
        
        //Let's check for the status value
        guard let status = json?["status"] as? NSNumber else {return}
        
        
        if status == 0{
            //status OK
            
            //Let's get the receipt dictionary
            
            let receipt = json?["receipt"] as! NSDictionary
            
            
            //Now let's get the In-App purchases
            guard let inApps = receipt["in_app"] as? [NSDictionary] else{
                
                print("No In-App purchases available")
                return
            }
            
            
            //Now we have to loop through each In-App and check for the values we discussed ealier
            
            for inApp in inApps{
                
                
                //Since we will only be interested in subscriptions
                guard let expiryDate = inApp["expires_date_ms"] as? NSString else {
                    //It's not a subscription production since it has no expiry_date_ms field
                    return
                }
                
                _ = (inApp["purchase_date_ms"] as? NSString)?.doubleValue
                
                _ = inApp["product_id"]
                _ = inApp["transaction_id"]
                
                let isTrial = inApp["is_trial_period"] as? NSString
                
                self.checkSubscriptionStatus(date: Date.init(timeIntervalSince1970: expiryDate.doubleValue / 1000))
                self.saveTrial(isTrial: isTrial!.boolValue)
                
            }
            
            
        }else{
            
            print("Error vaildating receipts - data not correct")
        }
        
    }
    
    
    
    
    
}


//Now let's make an extension for the ReceiptManager class which will have our logic for checking the subscription status
extension ReceiptManager{
    
    
    func checkSubscriptionStatus(date:Date){
        
        //In this function we will check for the expiry date of the subscription and see if it is newer than now, if so, then the user is subscribed to this product
        
        let calendar = Calendar.current
        
        let now = Date()
        
        
        let order = calendar.compare(now, to: date, toGranularity: .minute)
        
        
        switch order {
        case .orderedAscending,.orderedSame:
            print("User subscribed")
            self.saveActiveSubscription(date: date)
        case .orderedDescending:
            print("User subscription has expired")
        }
        
    }
    
    
    //Let's make a handy function to tell us only if the user is Subscribed or not
    
    var isSubscribed:Bool{
        
        guard let currentActiveSubscription = UserDefaults.standard.object(forKey: "activeSubscriptionKey") as? Date else{
            return false
        }
        
        //This way we check for the date everytime we call this variable
        return currentActiveSubscription.timeIntervalSince1970 > Date().timeIntervalSince1970 // NOW
        
    }
    
    
    //Now let's make a variable to tell us if the user is on trial period
    
    var isTrial:Bool{
        
        return UserDefaults.standard.bool(forKey: "isUserTrialPeriodKey")
    }
    
}


//This extension will include our UserDefault
extension ReceiptManager{
    
    func saveActiveSubscription(date:Date){
        //In our app example, we will only have one active subscription at a time. So there will be only one subscription either active or not
        UserDefaults.standard.set(date, forKey: "activeSubscriptionKey")
        UserDefaults.standard.synchronize()
        
    }
    
    
    
    func saveTrial(isTrial:Bool){
        
        UserDefaults.standard.set(isTrial, forKey: "isUserTrialPeriodKey")
        UserDefaults.standard.synchronize()
        
    }
}

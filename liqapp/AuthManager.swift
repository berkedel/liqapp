//
//  AuthManager.swift
//  
//
//  Created by Isa Ansharullah on 9/22/16.
//
//

import Foundation
import AFNetworking

class AuthManager: NSObject {
    static let sharedManager = AuthManager()
    
    var sessionManager: AFHTTPSessionManager!
    
    override init() {
        super.init()
        
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.requestCachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData
        
        let _sessionManager = AFHTTPSessionManager(baseURL: Constants.url.baseURL, sessionConfiguration: configuration)
        
        _sessionManager.requestSerializer = AFHTTPRequestSerializer()
        
        _sessionManager.responseSerializer = AFHTTPResponseSerializer()
        
        self.sessionManager = _sessionManager
    }
    
    func authenticateWithCode(parameters: Dictionary<String, AnyObject>, success: () -> Void, failure: (error: APIError) -> ()) {
        self.sessionManager.POST((Constants.url.authURL?.absoluteString)!, parameters: parameters, progress: nil, success: { (task, response) in
                if let actualHeader = (task.response as! NSHTTPURLResponse!).allHeaderFields as? Dictionary<String, AnyObject> {
                    //print(actualHeader)
                    let oAuthToken = OAuthToken(attributes: actualHeader)
                    if (oAuthToken != nil) {
                        success()
                    } else {
                        failure(error: APIError(domain: Constants.Error.authManagerErrorDomain, code: Constants.Error.Code.UnknownError.rawValue, userInfo: nil))
                    }
                }
            }, failure: { (task, error) in
                failure(error: APIError(domain: Constants.Error.authManagerErrorDomain, code: Constants.Error.Code.UnknownError.rawValue, userInfo: nil))
        })
    }
    

}
//
//  APIClient+URLSessionTask.swift
//  liqapp
//
//  Created by Isa Ansharullah on 9/21/16.
//  Copyright © 2016 DuldulStudio. All rights reserved.
//

import Foundation

extension APIClient {
    
    private func dataTask(urlRequest: NSURLRequest, success: () -> Void, failure: (error:APIError) -> ()) -> NSURLSessionTask {
        let task = session.dataTaskWithRequest(urlRequest, completionHandler: { (data, response, error) in
            let serializedResponse: Dictionary<String, AnyObject>? = {
                if let data = data {
                    do {
                        return try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as? Dictionary<String, AnyObject>
                    } catch {
                        return nil
                    }
                }
                return nil
            }()
            if let actualError = error as NSError! {
                dispatch_async(dispatch_get_main_queue(), {
                    let error = APIError(error: actualError)
                    error.responseText = serializedResponse?.description
                    failure(error: error)
                })
            } else if NSHTTPURLResponse.isUnauthorized(response as? NSHTTPURLResponse) {
                //failure(error: error)
            } else if (response as! NSHTTPURLResponse).didFail() {
                let err = APIError(urlResponse: (response as! NSHTTPURLResponse), jsonResponse: serializedResponse!)
                dispatch_async(dispatch_get_main_queue(), {
                    failure(error: err)
                })
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    success()
                })
            }
        })
        lastPerformedTask = task
        return task
    }
    
    private func jsonDataTask(urlRequest: NSURLRequest, success: (Dictionary<String, AnyObject>) -> Void, failure: (error: APIError) -> () ) -> NSURLSessionTask {
//        print(urlRequest)
        let task = session.dataTaskWithRequest(urlRequest, completionHandler: { (data, response, error) in
            dispatch_async(dispatch_get_main_queue(), {
                let httpResponse = response as? NSHTTPURLResponse
                
                // if actual error happens (no internet, timeout, etc.)
                if let actualError = error as NSError!, let actualData = data {
                    let error = APIError(error: actualError)
                    let string = NSString(data: actualData, encoding: NSASCIIStringEncoding)
                    error.responseText = string as? String
                    failure(error: error)
                } else {
                    let code: Int = {
                        if httpResponse == nil {
                            return Constants.Error.Code.UnknownError.rawValue
                        } else {
                            return httpResponse!.statusCode
                        }
                    }()
                    if NSHTTPURLResponse.isUnauthorized(httpResponse) {
                        let error = APIError(domain:Constants.Error.apiClientErrorDomain, code:Constants.Error.Code.UnauthorizedError.rawValue, userInfo: nil)
                        failure(error: error)
                    } else {
                        if let actualData = data as NSData? {
                            if actualData.length == 0 {
                                failure(error:APIError(domain: Constants.Error.apiClientErrorDomain, code: code, userInfo: nil))
                            } else if (response as! NSHTTPURLResponse).didFail() {
                                let err = APIError(domain: Constants.Error.apiClientErrorDomain, code: code, userInfo: nil)
                                failure(error: err)
                            } else {
                                let serialized = try! NSJSONSerialization.JSONObjectWithData(actualData, options: NSJSONReadingOptions.AllowFragments) as? Dictionary<String, AnyObject>
                                
                                if (serialized == nil) {
                                    let array_serialized = try! NSJSONSerialization.JSONObjectWithData(actualData, options: .AllowFragments) as? [Dictionary<String, AnyObject>]
                                    var ser_array_serialized = Dictionary<String, AnyObject>()
                                    ser_array_serialized.updateValue(array_serialized!, forKey: "response")
                                    success(ser_array_serialized)
                                } else {
                                    success(serialized!)
                                }
                            }
                        }
                    }
                }
            })
        })
        lastPerformedTask = task
        return task
    }
    
    func urlSessionTask(method: httpMethod, url: String, parameters: Dictionary<String, AnyObject>? = nil, success: () -> Void, failure: (error: APIError) -> ()) -> NSURLSessionTask {
        let url = NSURL(string: url)
        let urlRequest = NSMutableURLRequest(URL: url!, cachePolicy: .ReturnCacheDataElseLoad, timeoutInterval: 50)
        urlRequest.HTTPMethod = method.rawValue
        
        if let actualParameters = parameters {
            urlRequest.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(actualParameters, options: NSJSONWritingOptions.PrettyPrinted)
        }
        
        // add additional headers
        for (key, value) in self.additionalHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        let task = dataTask(urlRequest, success: success) { (error) in
            if error.code == Constants.Error.Code.UnauthorizedError.rawValue {
                self.validateFullScope {
                    failure(error: APIError(domain: Constants.Error.apiClientErrorDomain, code: Constants.Error.Code.UnknownError.rawValue, userInfo: nil))
                }
            } else {
                failure(error: error)
            }
        }
        
        return task
    }
    
    /**
     GET a request to server that fetches json structures, like list of documents, list of folders.
     :param: url       url to fetch data from
     :param: success   block with json data that has to be inserted to database
     :param: failure   failure block with error that should be sent to present a UIAlertcontroller with API error
     :returns: a task to resume when the request should be started
     */
    func urlSessionJSONTask(url url: String,  success: (Dictionary<String,AnyObject>) -> Void , failure: (error: APIError) -> ()) -> NSURLSessionTask {
        
        let fullURL = NSURL(string: url, relativeToURL: Constants.url.baseURL)
        let urlRequest = NSMutableURLRequest(URL: fullURL!, cachePolicy: .ReturnCacheDataElseLoad, timeoutInterval: 50)
        urlRequest.HTTPMethod = httpMethod.get.rawValue
        for (key, value) in self.additionalHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        let task = jsonDataTask(urlRequest, success: success) { (error) -> () in
            if error.code == Constants.Error.Code.UnauthorizedError.rawValue {
                self.validateFullScope {
                    failure(error: APIError(domain: Constants.Error.apiClientErrorDomain, code: Constants.Error.Code.UnknownError.rawValue, userInfo: nil))
                }
                print(error.responseText)
            } else {
                failure(error: error)
            }
        }
        
        return task
    }
    
    func urlSessionTaskWithNoAuthorizationHeader(method: httpMethod, url: String, parameters: Dictionary<String, AnyObject>? = nil, success: () -> Void, failure: (error: APIError) -> ()) -> NSURLSessionTask {
        let url = NSURL(string: url)
        let urlRequest = NSMutableURLRequest(URL: url!, cachePolicy: .ReturnCacheDataElseLoad, timeoutInterval: 50)
        urlRequest.HTTPMethod = method.rawValue
        urlRequest.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(parameters!, options: NSJSONWritingOptions.PrettyPrinted)
        urlRequest.setValue(nil, forHTTPHeaderField: "Authorization")
        
        let task = dataTask(urlRequest, success: success, failure: failure)
        return task
    }
}
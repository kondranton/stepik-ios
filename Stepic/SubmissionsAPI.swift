//
//  SubmissionsAPI.swift
//  Stepic
//
//  Created by Alexander Karpov on 05.04.17.
//  Copyright © 2017 Alex Karpov. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

class SubmissionsAPI : APIEndpoint {
    let name = "submissions"
    
    @discardableResult fileprivate func retrieve(stepName: String, objectName: String, objectId: Int, isDescending: Bool? = true, page: Int? = 1, userId : Int? = nil, headers: [String: String] = AuthInfo.shared.initialHTTPHeaders, success: @escaping ([Submission], Meta)->Void, error errorHandler: @escaping (String)->Void) -> Request? {
        
        var params : Parameters = [:]
        
        params[objectName] = objectId
        if let desc = isDescending {
            params["order"] = desc ? "desc" : "asc"
        }
        if let p = page {
            params["page"] = p
        }
        if let user = userId {
            params["user"] = user
        }
        
        return Alamofire.request("\(StepicApplicationsInfo.apiURL)/submissions", method: .get, parameters: params, encoding: URLEncoding.default, headers: headers).responseSwiftyJSON({ 
            response in
            
            var error = response.result.error
            var json : JSON = [:]
            if response.result.value == nil {
                if error == nil {
                    error = NSError()
                }
            } else {
                json = response.result.value!
            }
            let response = response.response
            
            if let e = error {
                let d = (e as NSError).localizedDescription
                print(d)
                errorHandler(d)
                return
            }
            
            if response?.statusCode == 200 {
                let meta = Meta(json: json["meta"])
                let submissions = json["submissions"].arrayValue.map({return Submission(json: $0, stepName: stepName)})
                success(submissions, meta)
                return
            } else {
                errorHandler("Response status code is wrong(\(String(describing: response?.statusCode)))")
                return
            }
        })
    }

    @discardableResult func retrieve(stepName: String, attemptId: Int, isDescending: Bool? = true, page: Int? = 1, userId : Int? = nil, headers: [String: String] = AuthInfo.shared.initialHTTPHeaders, success: @escaping ([Submission], Meta)->Void, error errorHandler: @escaping (String)->Void) -> Request? {
        return retrieve(stepName: stepName, objectName: "attempt", objectId: attemptId, isDescending: isDescending, page: page, userId: userId, headers: headers, success: success, error: errorHandler)
    }
    
    @discardableResult func retrieve(stepName: String, stepId: Int, isDescending: Bool? = true, page: Int? = 1, userId : Int? = nil, headers: [String: String] = AuthInfo.shared.initialHTTPHeaders, success: @escaping ([Submission], Meta)->Void, error errorHandler: @escaping (String)->Void) -> Request? {
        return retrieve(stepName: stepName, objectName: "step", objectId: stepId, isDescending: isDescending, page: page, userId: userId, headers: headers, success: success, error: errorHandler)
    }
    
    @discardableResult func retrieve(stepName: String, submissionId: Int, headers: [String: String] = AuthInfo.shared.initialHTTPHeaders, success: @escaping (Submission)->Void, error errorHandler: @escaping (String)->Void) -> Request? {
        
        let params : Parameters = [:]
        
        return Alamofire.request("\(StepicApplicationsInfo.apiURL)/submissions/\(submissionId)", parameters: params, encoding: URLEncoding.default, headers: headers).responseSwiftyJSON( { 
            response in
            
            var error = response.result.error
            var json : JSON = [:]
            if response.result.value == nil {
                if error == nil {
                    error = NSError()
                }
            } else {
                json = response.result.value!
            }
            let response = response.response
            
            if let e = error {
                let d = (e as NSError).localizedDescription
                print(d)
                errorHandler(d)
                return
            }
            
            if response?.statusCode == 200 {
                let submission = Submission(json: json["submissions"][0], stepName: stepName)
                success(submission)
                return
            } else {
                errorHandler("Response status code is wrong(\(String(describing: response?.statusCode)))")
                return
            }
        })
    }
    
    @discardableResult func create(stepName: String, attemptId: Int, reply: Reply, headers: [String: String] = AuthInfo.shared.initialHTTPHeaders, success: @escaping (Submission)->Void, error errorHandler: @escaping (String)->Void) -> Request? {
        
        let params : Parameters = [
            "submission": [
                "attempt" : "\(attemptId)",
                "reply" : reply.dictValue
            ]
        ]
        
        return Alamofire.request("\(StepicApplicationsInfo.apiURL)/submissions", method: .post, parameters: params, encoding: JSONEncoding.default, headers: headers).responseSwiftyJSON({
            response in
            
            var error = response.result.error
            var json : JSON = [:]
            if response.result.value == nil {
                if error == nil {
                    error = NSError()
                }
            } else {
                json = response.result.value!
            }
            let response = response.response
            
            if let e = error {
                let d = (e as NSError).localizedDescription
                print(d)
                errorHandler(d)
                return
            }
            
            if response?.statusCode == 201 {
                let submission = Submission(json: json["submissions"].arrayValue[0], stepName: stepName) 
                success(submission)
                return
            } else {
                errorHandler("Response status code is wrong(\(String(describing: response?.statusCode)))")
                return
            }
        })
    }    

}

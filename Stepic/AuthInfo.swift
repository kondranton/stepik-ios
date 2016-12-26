//
//  AuthInfo.swift
//  Stepic
//
//  Created by Alexander Karpov on 17.09.15.
//  Copyright (c) 2015 Alex Karpov. All rights reserved.
//

import UIKit
import MagicalRecord

class AuthInfo: NSObject {
    static var shared = AuthInfo()
    
    fileprivate let defaults = UserDefaults.standard
        
    fileprivate override init() {
        super.init()
        
        print("initializing AuthInfo with userId \(userId)")
        if let id = userId {
            if let users = User.fetchById(id) {
                let c = users.count
//                if c > 1 {
//                    print("users count > 1, deleting all")
//                    for user in users {
//                        user.MR_deleteEntity()
//                    }
//                    c = 0
//                    CoreDataHelper.instance.save()
//                }
                
                if c == 0 {
                    print("No user with such id found, downloading")
                    ApiDataDownloader.sharedDownloader.getUsersByIds([id], deleteUsers: [], refreshMode: .update, success: {
                        [weak self]
                        users in
                        if let user = users.first {
                            self?.user = user
                            return
                        }
                        print("downloaded user")
                        CoreDataHelper.instance.save()

                        }, failure: {
                            [weak self]
                            _ in
                            print("failed to fetch user")
                            self?.userId = nil
                    })
                }
                
                if c >= 1 {
                    user = users.first
                }
                
            }
        }
    }
        
    fileprivate func setTokenValue(_ newToken: StepicToken?) {
        defaults.setValue(newToken?.accessToken, forKey: "access_token")
        defaults.setValue(newToken?.refreshToken, forKey: "refresh_token")
        defaults.setValue(newToken?.tokenType, forKey: "token_type")
        defaults.setValue(newToken?.expireDate.timeIntervalSince1970, forKey: "expire_date")
        defaults.synchronize()
    }
    
    var token : StepicToken? {
        set(newToken) {
            if newToken == nil || newToken?.accessToken == ""  {
                print("\nsetting new token to nil\n")
                
                //Unregister from notifications
                NotificationRegistrator.sharedInstance.unregisterFromNotifications(completion: {
                    UIThread.performUI{
                        //Delete enrolled information
                        TabsInfo.myCoursesIds = []
                        let c = Course.getAllCourses(enrolled: true)
                        for course in c {
                            course.enrolled = false
                        }
                        
                        Progress.deleteAllStoredProgresses()
                        CoreDataHelper.instance.save()

                        AuthInfo.shared.user = nil
                        
                        AnalyticsHelper.sharedHelper.changeSignIn()
                        self.setTokenValue(newToken)
                    }
                })
            } else {
                print("\nsetting new token -> \(newToken!.accessToken)\n")
                didRefresh = true
                setTokenValue(newToken)
                Session.delete()
            }
        }
        
        get {
            if let accessToken = defaults.value(forKey: "access_token") as? String,
            let refreshToken = defaults.value(forKey: "refresh_token") as? String,
            let tokenType = defaults.value(forKey: "token_type") as? String {
                print("got accessToken \(accessToken)")
                let expireDate = Date(timeIntervalSince1970: defaults.value(forKey: "expire_date") as? TimeInterval ?? 0.0)
                AnalyticsReporter.reportEvent(AnalyticsEvents.Token.requestedNotNilToken, parameters: nil)
                return StepicToken(accessToken: accessToken, refreshToken: refreshToken, tokenType: tokenType, expireDate: expireDate)
            } else {
                return nil
            }
        }
    }
    
    var isAuthorized : Bool {
        return token != nil
    }
    
    var hasUser : Bool {
        return user != nil
    }
    
    var needsToRefreshToken: Bool {
        //TODO: Fix this
        if let token = token {
            return Date().compare(token.expireDate as Date) == ComparisonResult.orderedDescending
        } else {
            return false
        }
    }
    
    var authorizationType : AuthorizationType {
        get {
            if let typeRaw = defaults.value(forKey: "authorization_type") as? Int {
                return AuthorizationType(rawValue: typeRaw)!
            } else {
                return AuthorizationType.none
            }
        }
        
        set(type) {
            defaults.setValue(type.rawValue, forKey: "authorization_type")
            defaults.synchronize()
        }
    }
    
    var didRefresh : Bool = false
    
    var anonymousUserId : Int?
    
    var userId : Int? {
        set(id) {
            if let user = user {
                if user.isGuest {
                    print("setting anonymous user id \(id)")
                    anonymousUserId = id
                    return
                }
            }
            print("setting user id \(id)")
            defaults.setValue(id, forKey: "user_id")
            defaults.synchronize()
        }
        get {
            if let user = user {
                if user.isGuest {
                    print("returning anonymous user id \(anonymousUserId)")
                    return anonymousUserId
                } else {
                    print("returning normal user id \(defaults.value(forKey: "user_id") as? Int)")
                    return defaults.value(forKey: "user_id") as? Int
                }
            } else {
                print("returning normal user id \(defaults.value(forKey: "user_id") as? Int)")
                return defaults.value(forKey: "user_id") as? Int
            }
        }
    }
    
    var user : User? {
        didSet {
            print("\n\ndid set user with id \(user?.id)\n\n")
            userId = user?.id
        }
    }
    
    var initialHTTPHeaders : [String: String] {
        if !AuthInfo.shared.isAuthorized {
            return Session.cookieHeaders
        } else {
            return APIDefaults.headers.bearer
        }
    }
}

enum AuthorizationType: Int {
    case none = 0, password, code
}

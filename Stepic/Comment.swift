//
//  Comment.swift
//  Stepic
//
//  Created by Alexander Karpov on 07.06.16.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import Foundation
import SwiftyJSON

enum UserRole: String {
    case Student = "student", Teacher = "teacher", Staff = "staff"
}

/*
 Comment model, without voting
 */
class Comment: JSONInitializable {
    
    typealias idType = Int
    
    var id: Int
    var parentId: Int?
    var userId: Int
    var userRole: UserRole
    var time: Date
    var lastTime: Date
    var text: String
    var replyCount: Int
    var isDeleted: Bool
    var targetStepId: Int
    var repliesIds : [Int]
    var isPinned: Bool
    var voteId: String
    var epicCount: Int
    var abuseCount: Int
    var userInfo: UserInfo!
    var vote: Vote!
    
    func initialize(_ json: JSON) {
        id = json["id"].intValue
        parentId = json["parent"].int
        userId = json["user"].intValue
        userRole = UserRole(rawValue: json["user_role"].stringValue) ?? .Student
        time = Parser.sharedParser.dateFromTimedateJSON(json["time"])!
        lastTime = Parser.sharedParser.dateFromTimedateJSON(json["last_time"])!
        text = json["text"].stringValue
        replyCount = json["reply_count"].intValue
        isDeleted = json["is_deleted"].boolValue
        targetStepId = json["target"].intValue
        repliesIds = json["replies"].arrayValue.flatMap{
            return $0.int
        }
        isPinned = json["is_pinned"].boolValue
        voteId = json["vote"].stringValue
        epicCount = json["epic_count"].intValue
        abuseCount = json["abuse_count"].intValue
    }
    
    required init(json: JSON) {
        id = json["id"].intValue
        parentId = json["parent"].int
        userId = json["user"].intValue
        userRole = UserRole(rawValue: json["user_role"].stringValue) ?? .Student
        time = Parser.sharedParser.dateFromTimedateJSON(json["time"])!
        lastTime = Parser.sharedParser.dateFromTimedateJSON(json["last_time"])!
        text = json["text"].stringValue
        replyCount = json["reply_count"].intValue
        isDeleted = json["is_deleted"].boolValue
        targetStepId = json["target"].intValue
        repliesIds = json["replies"].arrayValue.flatMap{
            return $0.int
        }
        isPinned = json["is_pinned"].boolValue    
        voteId = json["vote"].stringValue
        epicCount = json["epic_count"].intValue
        abuseCount = json["abuse_count"].intValue
    }
    
    func update(json: JSON) {
        initialize(json)
    }
    
    func hasEqualId(json: JSON) -> Bool {
        return id == json["id"].intValue
    }
    
//    
//    init(sampleId: Int) {
//        id = sampleId
//        parentId = nil
//        userId = 10
//        userRole = .Student
//        time = NSDate()
//        lastTime = NSDate()
//        
//        let latexStrings = [
//            "Here is a simple LaTeX $x^2 + 3*x - 10/(y*z^3)$",
//            "A bit easier $x$ and it became really long long long long looooooong long long long long",
//            "The best string with LaTeX $(x*a*b + 2*x/(z^2))/(200*y^6 + x/z)$",
//        ]
//        
//        text = latexStrings[min(sampleId, 2)]
//        replyCount = 0
//        isDeleted = false
//        targetStepId = 0
//        repliesIds = []
//        isPinned = false
//    }
}

struct CommentPostable {
    var parent: Int?
    var target: Int
    var text: String
    
    init(parent: Int? = nil, target: Int, text: String) {
        self.parent = parent
        self.target = target
        self.text = text
    }
    
    var json: [String: AnyObject] {
        var dict : [String: AnyObject] = [
            "target" : target as AnyObject,
            "text" : text as AnyObject
        ]
        if let p = parent {
            dict["parent"] = p as AnyObject?
        }
        
        return dict
    }
}

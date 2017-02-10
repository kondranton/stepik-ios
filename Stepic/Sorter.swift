//
//  Sorter.swift
//  Stepic
//
//  Created by Alexander Karpov on 26.10.15.
//  Copyright © 2015 Alex Karpov. All rights reserved.
//

import Foundation

struct Sorter {
    static func sort<T : JSONInitializable>(_ array : [T], byIds ids: [Int], canMissElements: Bool = false) -> [T] {
        var res : [T] = []
        
        for id in ids {
            let elements = array.filter({return $0.id == id})
            if elements.count == 1 {
                res += [elements[0]]
            } else {
                //TODO : Maybe should throw exception here
                if !canMissElements { 
                    print("Something went wrong") 
                }
            }
        }
        
        return res
    }
    
    static func sort(_ array : [CoursePlainEntity], byIds ids: [Int], canMissElements: Bool = false) -> [CoursePlainEntity] {
        var res : [CoursePlainEntity] = []
        
        for id in ids {
            let elements = array.filter({return $0.id == id})
            if elements.count == 1 {
                res += [elements[0]]
            } else {
                //TODO : Maybe should throw exception here
                if !canMissElements { 
                    print("Something went wrong") 
                }
            }
        }
        
        return res
    }
    
    static func sort(_ array: [Progress], byIds ids: [String]) -> [Progress] {
        var res : [Progress] = []
        
        for id in ids {
            let elements = array.filter({return $0.id == id})
            if elements.count == 1 {
                res += [elements[0]]
            } else {
                //TODO : Maybe should throw exception here
                print("Something went wrong")
            }
        }
        
        return res
    }
    
    static func sort(_ assignments : [Assignment], steps : [Step]) -> [Assignment] {
        
        var res : [Assignment] = []

        for step in steps {
            let elements = assignments.filter({return $0.stepId == step.id})
            if elements.count == 1 {
                res += [elements[0]]
            } else {
                //TODO : Maybe should throw exception here
                print("Something went wrong")
            }
        }
        
        return res
    }
}

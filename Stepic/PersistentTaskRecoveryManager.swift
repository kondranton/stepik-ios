//
//  PersistentTaskRecoveryManager.swift
//  Stepic
//
//  Created by Alexander Karpov on 06.05.16.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import Foundation

/*
 Strategy class for recovering the correct task from store
 */
class PersistentTaskRecoveryManager : PersistentRecoveryManager {
    override func recoverObjectFromDictionary(_ dictionary: [String : Any]) -> DictionarySerializable? {
        let typeStringOrNil = dictionary["type"] as? String
        if let type = ExecutableTaskType(rawValue: typeStringOrNil ?? "") {
            
            switch type {
            case .deleteDevice:
                return  DeleteDeviceExecutableTask(dictionary: dictionary)
            case .postViews:
                return PostViewsExecutableTask(dictionary: dictionary)
            }
            
        } else {
            return nil
        }
    }
    
    func recoverTask(name: String) -> Executable? {
        return recoverObjectWithKey(name) as? Executable
    }
    
    func writeTask(_ task: Executable & DictionarySerializable, name: String) {
        return writeObjectWithKey(name, object: task)
    }
}

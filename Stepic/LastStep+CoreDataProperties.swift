//
//  LastStep+CoreDataProperties.swift
//  Stepic
//
//  Created by Alexander Karpov on 13.03.17.
//  Copyright © 2017 Alex Karpov. All rights reserved.
//

import Foundation
import CoreData

extension LastStep {
    
    @NSManaged var managedId: String?
    @NSManaged var managedStepId: NSNumber?
    @NSManaged var managedUnitId: NSNumber?
    
    @NSManaged var managedCourse: Course?
    
    class var oldEntity : NSEntityDescription {
        return NSEntityDescription.entity(forEntityName: "LastStep", in: CoreDataHelper.instance.context)!
    }
    
    convenience init() {
        self.init(entity: LastStep.oldEntity, insertInto: CoreDataHelper.instance.context)
    }
    
    var id : String {
        set (newId){
            self.managedId = newId
        }
        get {
            if managedId == nil {
                print("Requested LastStep id when it is nil")
            }
            return managedId ?? "-1"
        }
    }
    
    var stepId : Int? {
        set(newId){
            self.managedStepId = newId as NSNumber? 
        }
        get {
            return managedStepId?.intValue
        }
    }
    
    var unitId : Int? {
        set(newId){
            self.managedUnitId = newId as NSNumber?
        }
        get {
            return managedUnitId?.intValue
        }
    }
    
}

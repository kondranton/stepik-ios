//
//  Course.swift
//  
//
//  Created by Alexander Karpov on 25.09.15.
//
//

import Foundation
import CoreData
import SwiftyJSON

@objc
class Course: NSManagedObject, JSONInitializable {

// Insert code here to add functionality to your managed object subclass
    
    typealias idType = Int
    
    convenience required init(json: JSON) {
        self.init()
        initialize(json)
    }

    func initialize(_ json: JSON) {
        id = json["id"].intValue
        title = json["title"].stringValue
        courseDescription = json["description"].stringValue
        coverURLString = "\(StepicApplicationsInfo.stepicURL)" + json["cover"].stringValue
        
        beginDate = Parser.sharedParser.dateFromTimedateJSON(json["begin_date_source"])
        endDate = Parser.sharedParser.dateFromTimedateJSON(json["last_deadline"])
        
        enrolled = json["enrollment"].int != nil
        featured = json["is_featured"].boolValue
        isPublic = json["is_public"].boolValue

        summary = json["summary"].stringValue
        workload = json["workload"].stringValue
        introURL = json["intro"].stringValue
        format = json["course_format"].stringValue
        audience = json["target_audience"].stringValue
        certificate = json["certificate"].stringValue
        requirements = json["requirements"].stringValue
        slug = json["slug"].string
        progressId = json["progress"].string
        lastStepId = json["last_step"].string
        sectionsArray = json["sections"].arrayObject as! [Int]
        instructorsArray = json["instructors"].arrayObject as! [Int]
        if let _ = json["intro_video"].null {
            introVideo = nil
        } else {
            introVideo = Video(json: json["intro_video"])
        }
    }
    
    func hasEqualId(json: JSON) -> Bool {
        return id == json["id"].intValue
    }
    
    var metaInfo : String {
        //percent of completion = n_steps_passed/n_steps
        if let p = self.progress {
            
            let percentage = p.numberOfSteps != 0 ? Int(Double(p.numberOfStepsPassed) / Double(p.numberOfSteps) * 100) : 100
            return "\(NSLocalizedString("PassedPercent", comment: "")) \(percentage)%"
//            return "Выполнение курса: " + "\(percentage)%"
        } else {
            return ""
        }
    }
    
    var metaInfoContainer : CourseMetainfoContainer {
        var metaArr = [CourseMetainfoEntity]()
        
//        if summary != "" {
//            metaArr += [CourseMetainfoEntity(title: NSLocalizedString("Summary", comment: ""), subtitle: summary)]
//        }
//        if courseDescription != "" {
//            metaArr += [CourseMetainfoEntity(title: NSLocalizedString("Description", comment: ""), subtitle: courseDescription)]
//        }
        if workload != "" {
            metaArr += [CourseMetainfoEntity(title: NSLocalizedString("Workload", comment: ""),subtitle: workload)]
        }
        if certificate != "" {
            metaArr += [CourseMetainfoEntity(title: NSLocalizedString("Certificate", comment: ""), subtitle: certificate)]
        }
        if audience != "" {
            metaArr += [CourseMetainfoEntity(title: NSLocalizedString("Audience", comment: ""), subtitle: audience)]
        }
        if format != "" {
            metaArr += [CourseMetainfoEntity(title: NSLocalizedString("Format", comment: ""), subtitle: format)]
        }
//        if requirements != "" {
//            metaArr += [CourseMetainfoEntity(title: NSLocalizedString("Requirements", comment: ""), subtitle: requirements)]
//        }
//        
        return CourseMetainfoContainer(courseId: id, metainfo: metaArr)
    }
    
    var nearestDeadlines: (nearest: Date?, second: Date?)? {
        guard sections.count > 0 else {
            return nil
        }
        
        var deadlinesSet = Set<TimeInterval>()
        for section in sections {
            if let soft = section.softDeadline {
                deadlinesSet.insert(soft.timeIntervalSince1970)
            }
            if let hard = section.hardDeadline {
                deadlinesSet.insert(hard.timeIntervalSince1970)
            }
        }
        
        let deadlines = deadlinesSet.sorted()
        
        for (index, deadline) in deadlines.enumerated() {
            if deadline > Date().timeIntervalSince1970 {
                if index + 1 < deadlines.count {
                    return (nearest: Date(timeIntervalSince1970: deadline), second: Date(timeIntervalSince1970: deadlines[index + 1]))
                } else {
                    return (nearest: Date(timeIntervalSince1970: deadline), second: nil)
                }
            }
        }
        
        return (nearest: nil, second: nil)
    }
    
    
    func update(json: JSON) {
        initialize(json)
    }
    
        
//    func loadLastStep(success: @escaping ((Void) -> Void)) {
//        guard let id = self.lastStepId else { 
//            return 
//        }
//        _ = ApiDataDownloader.lastSteps.retrieve(ids: [id], success: {
//            [weak self]
//            lastSteps in
//            
//            self?.changeLastStepTo(lastStep: lastSteps.first!)
//            success()
//        }, error: {
//            error in
//            print("error while loading last step")
//        })
//    }
    
    func loadAllInstructors(success: @escaping ((Void) -> Void)) {
        _ = ApiDataDownloader.users.retrieve(ids: self.instructorsArray, existing: self.instructors, refreshMode: .update, success: {
            users in
            self.instructors = Sorter.sort(users, byIds: self.instructorsArray)
            CoreDataHelper.instance.save()
            success()  
            }, error : {
                error in
                print("error while loading section")
        })
    }
    
    func loadAllSections(success: @escaping ((Void) -> Void), error errorHandler : @escaping ((Void) -> Void), withProgresses: Bool = true) {
        
        if sectionsArray.count == 0 {
            success()
            return
        }
        
        let requestSectionsCount = 50
        var dimCount = 0
        var idsArray = Array<Array<Int>>()
        for (index, sectionId) in self.sectionsArray.enumerated() {
            if index % requestSectionsCount == 0 {
                idsArray.append(Array<Int>())
                dimCount += 1
            }
            idsArray[dimCount - 1].append(sectionId)
        }
        
//            let sectionsToDownload = idsArray.count
        var downloadedSections = [Section]()
        
        let idsDownloaded : ([Section]) -> (Void) = {
            secs in
            downloadedSections.append(contentsOf: secs)
            if downloadedSections.count == self.sectionsArray.count {
                self.sections = Sorter.sort(downloadedSections, byIds: self.sectionsArray)
                CoreDataHelper.instance.save()
                success()
            }
        }
        
        var wasError = false
        let errorWhileDownloading : (Void) -> (Void) = {
            if !wasError {
                wasError = true
                errorHandler()
            }
        }
        
        for ids in idsArray {
            _ = ApiDataDownloader.sections.retrieve(ids: ids, existing: self.sections, refreshMode: .update, success: {
                secs in
                if withProgresses { 
                    self.loadProgressesForSections(sections: secs, success: {
                        idsDownloaded(secs)
                    }, error: {
                        errorWhileDownloading()
                    }) 
                } else {
                    idsDownloaded(secs)
                }
            }, error : {
                error in
                print("error while loading section")
                errorWhileDownloading()
            })
        }
    }
    
        
    func loadProgressesForSections(sections: [Section], success completion: @escaping ((Void)->Void), error errorHandler : @escaping ((Void)->Void)) {
        var progressIds : [String] = []
        var progresses : [Progress] = []
        for section in sections {
            if let progressId = section.progressId {
                progressIds += [progressId]
            }

            if let progress = section.progress {
                progresses += [progress]
            }
        }
        
        if progressIds.count == 0 {
            completion()
            return
        }
        
//        print("progress ids array -> \(progressIds)")
        _ = ApiDataDownloader.progresses.retrieve(ids: progressIds, existing: progresses, refreshMode: .update, success: { 
            (newProgresses) -> Void in
            progresses = Sorter.sort(newProgresses, byIds: progressIds)
            
            if progresses.count == 0 {
                CoreDataHelper.instance.save()
                completion()
                return
            }
            
            var progressCnt = 0
            for i in 0 ..< sections.count {
                if sections[i].progressId == progresses[progressCnt].id {
                    sections[i].progress = progresses[progressCnt]
                }
                progressCnt += 1
                if progressCnt == progresses.count {
                    break
                }
            }
            CoreDataHelper.instance.save()
            completion()
        }, error: { 
            (error) -> Void in
            print("Error while downloading progresses")
            errorHandler()
        })
    }
    
    class func getCourses(_ ids: [Int], featured: Bool? = nil, enrolled: Bool? = nil, isPublic: Bool? = nil) throws -> [Course] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Course")
        let descriptor = NSSortDescriptor(key: "managedId", ascending: false)
        
        let idPredicates = ids.map{
            return NSPredicate(format: "managedId == %@", $0 as NSNumber)
        }
        let idCompoundPredicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.or, subpredicates: idPredicates)

        var nonIdPredicates = [NSPredicate]()
        if let f = featured {
            nonIdPredicates += [NSPredicate(format: "managedFeatured == %@", f as NSNumber)]
        }
        
        if let e = enrolled {
            nonIdPredicates += [NSPredicate(format: "managedEnrolled == %@", e as NSNumber)]
        }
        
        if let p = isPublic {
            nonIdPredicates += [NSPredicate(format: "managedPublic == %@", p as NSNumber)]
        }
        
        let nonIdCompoundPredicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: nonIdPredicates)
        
        let predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: [idCompoundPredicate, nonIdCompoundPredicate])
        request.predicate = predicate
        request.sortDescriptors = [descriptor]
        
        do {
            let results = try CoreDataHelper.instance.context.fetch(request) 
            return results as! [Course]
        }
        catch {
            throw FetchError.requestExecution
        }
    }
    
    
    
    class func getAllCourses(enrolled : Bool? = nil) -> [Course] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Course")
        var predicate = NSPredicate(value: true)

        if let e = enrolled {
            let p = NSPredicate(format: "managedEnrolled == %@", e as NSNumber)
            predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: [predicate, p])
        }
        
        request.predicate = predicate
        do {
            let results = try CoreDataHelper.instance.context.fetch(request)
            return results as! [Course]
        }
        catch {
            print("Error while getting courses")
            return []
//            throw FetchError.RequestExecution
        }
    }
    
//    func changeLastStepTo(lastStep: LastStep?) {
//        let objectToDelete = self.lastStep
//        self.lastStep = lastStep
//        if let deletingObject = objectToDelete { 
//            CoreDataHelper.instance.deleteFromStore(deletingObject, save: true)
//        }
//    }
}

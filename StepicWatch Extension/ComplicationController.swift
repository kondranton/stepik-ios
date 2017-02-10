//
//  ComplicationController.swift
//  StepicWatch Extension
//
//  Created by Alexander Zimin on 19/12/2016.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import ClockKit
import WatchKit

extension String {
  func substring(with range: Range<Int>) -> String {
    let beginIndex = self.index(self.startIndex, offsetBy: range.lowerBound)
    let endIndex = self.index(self.startIndex, offsetBy: range.upperBound)
    return self.substring(with: beginIndex..<endIndex)
  }
}


class ComplicationController: NSObject, CLKComplicationDataSource {


  var dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd.MM EE hh:mm"
    return dateFormatter
  }()

    // I ASSUME IT'S SORTED BY DATE
    var deadlines = [Date: String]() // time: topic
  
    let NoDeadlines = Localizables.noDeadlines
  
    func fetchDeadlinesFromUD() -> [Date: String] {

      var dealines: [Date: String] = [:]
      var counter: [Date: Int] = [:]

      if let mainContainer = WKExtension.shared().delegate as? ExtensionDelegate {
        print(mainContainer.courses) // ← Get courses, let's extract deadlines and return
        for course in mainContainer.courses {
          for date in course.deadlineDates {
            let name = course.name
            if dealines[date] != nil {
               counter[date]! += 1
              dealines[date]! = "\(Localizables.coursesCnt): \(counter[date]!)"
            } else {
              dealines[date] = "❌" + name
              counter[date] = 1
            }
          }
        }
      }

      return dealines
    }
  
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.forward])
    }
    
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
      let currentDate = Date()
      handler(currentDate)
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
      let currentDate = Date()
      let endDate =
        currentDate.addingTimeInterval(TimeInterval(2 * 24 * 60 * 60))
      handler(endDate)
    }
  
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Call the handler with the current timeline entry
        deadlines = fetchDeadlinesFromUD()

        if complication.family == .modularLarge {
          var entry: CLKComplicationTimelineEntry!
          if let first = deadlines.keys.sorted().first {
            let timeString = dateFormatter.string(from: first)
            entry = createTimeLineEntry(headerText: timeString, bodyText: deadlines[first] ?? NoDeadlines, date: first)
          } else {
            entry = createEmptyTimeLineEntity()
          }
          handler(entry)
        } else {
          handler(nil)
        }
    }

  func createEmptyTimeLineEntity(date: Date = Date()) -> CLKComplicationTimelineEntry {
    return createTimeLineEntry(headerText: "--:--", bodyText: NoDeadlines, date: date)
  }
  
  func createTimeLineEntry(headerText: String, bodyText: String, date: Date) -> CLKComplicationTimelineEntry {
    
    let template = CLKComplicationTemplateModularLargeStandardBody()
    let clock = UIImage(named: "clock")
    
    template.headerImageProvider =
      CLKImageProvider(onePieceImage: clock!)
    template.headerTextProvider = CLKSimpleTextProvider(text: headerText)
    template.body1TextProvider = CLKSimpleTextProvider(text: bodyText)
    
    let entry = CLKComplicationTimelineEntry(date: date,
                                             complicationTemplate: template)
    
    return(entry)
  }
  
    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries prior to the given date
        handler(nil)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date
      deadlines = fetchDeadlinesFromUD()
      var timeLineEntryArray = [CLKComplicationTimelineEntry]()

      var lastDate = date
      // Right after the first deadline we will show the next one
      for key in deadlines.keys.sorted() {
        if key.compare(date) == ComparisonResult.orderedAscending {
          continue
        }

        let timeString = dateFormatter.string(from: key)
        
        let entry = createTimeLineEntry(headerText: timeString, bodyText: deadlines[key] ?? NoDeadlines, date: key)
        lastDate = key.addingTimeInterval(1)
        
        timeLineEntryArray.append(entry)
      }

      if timeLineEntryArray.count != 0 {
        let entity = createEmptyTimeLineEntity(date: lastDate)
        timeLineEntryArray.append(entity)
      }

      handler(timeLineEntryArray)
    }
    
    // MARK: - Placeholder Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
      let template = CLKComplicationTemplateModularLargeStandardBody()
      let clock = UIImage(named: "clock")
      
      template.headerImageProvider =
        CLKImageProvider(onePieceImage: clock!)
      
      template.headerTextProvider =
        CLKSimpleTextProvider(text: Localizables.coursesStepik)
      template.body1TextProvider =
        CLKSimpleTextProvider(text: Localizables.deadlines)
      
      handler(template)
    }
  
}

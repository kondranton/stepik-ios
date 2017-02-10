//
//  ExtensionDelegate.swift
//  StepticWatchesApp Extension
//
//  Created by Alexander Zimin on 17/12/2016.
//  Copyright © 2016 Alexander Zimin. All rights reserved.
//

import WatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
	
  var courses: [CoursePlainEntity] = []
  
  func fetchCourses() {
    if let data = UserDefaults.standard.object(forKey: WatchSessionSender.Name.Courses.rawValue) {
      self.courses = Array<CoursePlainEntity>.fromData(data: data as! Data)
    }
  }
  
  func scheduleNextBackgroundRefresh() {
    let prefferedDate = Date(timeIntervalSinceNow: (1 * 60 * 60))
    let userInfo: [String: Any] = ["lastUpdated": Date(),
                                  "reason": "New deadlines update"]
    WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: prefferedDate, userInfo: userInfo as NSSecureCoding) { error in
      if let error = error {
        print("Error scheduling next refresh: \(error.localizedDescription)")
      }
    }
  }
  
  func updateComplication() {
    let complicationServer = CLKComplicationServer.sharedInstance()
    for complication in (complicationServer.activeComplications ?? []) {
      complicationServer.reloadTimeline(for: complication)
    }
  }
  
	func applicationDidFinishLaunching() {
		// Perform any final initialization of your application.
		
		WatchSessionManager.sharedManager.startSession()
    fetchCourses()
	}
	
	func applicationDidBecomeActive() {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}
	
	func applicationWillResignActive() {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, etc.
	}
	
	func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
		// Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
		for task in backgroundTasks {
			// Use a switch statement to check the task type
			switch task {
			case let backgroundTask as WKApplicationRefreshBackgroundTask:
				// Be sure to complete the background task once you’re done.
        scheduleNextBackgroundRefresh()
        updateComplication()
        backgroundTask.setTaskCompleted()
			case let snapshotTask as WKSnapshotRefreshBackgroundTask:
				// Snapshot tasks have a unique completion call, make sure to set your expiration date
				snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
			case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
				// Be sure to complete the connectivity task once you’re done.
				connectivityTask.setTaskCompleted()
			case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
				// Be sure to complete the URL session task once you’re done.
				urlSessionTask.setTaskCompleted()
			default:
				// make sure to complete unhandled task types
				task.setTaskCompleted()
			}
		}
	}
	
}

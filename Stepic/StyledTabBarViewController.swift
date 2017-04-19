//
//  StyledTabBarViewController.swift
//  Stepic
//
//  Created by Alexander Karpov on 03.09.16.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import UIKit

class StyledTabBarViewController: UITabBarController {

    
    var titles = [
        NSLocalizedString("MyCourses", comment: ""),
        NSLocalizedString("FindCourses", comment: ""),
        NSLocalizedString("Downloads", comment: ""),
        NSLocalizedString("Certificates", comment: "")
    ]
    
    var eventNames = [
        AnalyticsEvents.Tabs.myCoursesClicked,
        AnalyticsEvents.Tabs.findCoursesClicked,
        AnalyticsEvents.Tabs.downloadsClicked,
        AnalyticsEvents.Tabs.certificatesClicked
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UICustomizer.sharedCustomizer.setStepicTabBar(tabBar)
        
        if !StepicApplicationsInfo.doesAllowCourseUnenrollment {
            titles.remove(at: 1)
            eventNames.remove(at: 1)
        }
        
        if let items = tabBar.items {
            for (index, item) in items.enumerated() {
                item.title = titles[index]
            }
        }
        delegate = self
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    func getEventNameForTabIndex(index: Int) -> String? {
        return eventNames[index]
    }
    
}

extension StyledTabBarViewController : UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if let selectedIndex = tabBarController.viewControllers?.index(of: viewController) {
            if let eventName = getEventNameForTabIndex(index: selectedIndex) {
                AnalyticsReporter.reportEvent(eventName, parameters: nil)
            }
        }
    }
}

//
//  SectionsViewController.swift
//  Stepic
//
//  Created by Alexander Karpov on 08.10.15.
//  Copyright © 2015 Alex Karpov. All rights reserved.
//

import UIKit
import DownloadButton
import DZNEmptyDataSet

class SectionsViewController: UIViewController, ShareableController, UIViewControllerPreviewingDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    let refreshControl = UIRefreshControl()
    var didRefresh = false
    var course : Course! 
    
    var moduleId: Int?
    var parentShareBlock : ((UIActivityViewController) -> (Void))? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        LastStepGlobalContext.context.course = course
        
        self.navigationItem.title = course.title
        tableView.tableFooterView = UIView()
        self.navigationItem.backBarButtonItem?.title = " "
        
        let shareBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.action, target: self, action: #selector(SectionsViewController.shareButtonPressed(_:)))
        let infoBtn = UIButton(type: UIButtonType.infoDark)
        infoBtn.addTarget(self, action: #selector(SectionsViewController.infoButtonPressed(_:)), for: UIControlEvents.touchUpInside)
        let infoBarButtonItem = UIBarButtonItem(customView: infoBtn)
        self.navigationItem.rightBarButtonItems = [shareBarButtonItem, infoBarButtonItem]
        
        tableView.register(UINib(nibName: "SectionTableViewCell", bundle: nil), forCellReuseIdentifier: "SectionTableViewCell")

        refreshControl.addTarget(self, action: #selector(SectionsViewController.refreshSections), for: .valueChanged)
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        refreshControl.layoutIfNeeded()        
        refreshControl.beginRefreshing()
        refreshSections()

        tableView.emptyDataSetDelegate = self
        tableView.emptyDataSetSource = self
        
        if #available(iOS 9.0, *) {
            if(traitCollection.forceTouchCapability == .available) {
                registerForPreviewing(with: self, sourceView: view)
            }
        }
    }
    
    var url : String {
        if let slug = course?.slug {
            return StepicApplicationsInfo.stepicURL + "/course/" + slug + "/syllabus/"
        } else {
            return ""
        }
    }
    
    func shareButtonPressed(_ button: UIBarButtonItem) {
        share(popoverSourceItem: button, popoverView: nil, fromParent: false)
    }
    
    func infoButtonPressed(_ button: UIButton) {
        self.performSegue(withIdentifier: "showCourse", sender: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.backBarButtonItem?.title = " "
        tableView.reloadData()
        if(self.refreshControl.isRefreshing) {
            let offset = self.tableView.contentOffset
            self.refreshControl.endRefreshing()
            self.refreshControl.beginRefreshing()
            self.tableView.contentOffset = offset
        }
    }
    
    var emptyDatasetState : EmptyDatasetState = .empty {
        didSet {
            UIThread.performUI{
                self.tableView.reloadEmptyDataSet()
            }
        }
    }
    
    func refreshSections() {
        didRefresh = false
        emptyDatasetState = .refreshing
        course.loadAllSections(success: {
            UIThread.performUI({
                self.refreshControl.endRefreshing()
                self.emptyDatasetState = EmptyDatasetState.empty
                self.tableView.reloadData()
                if let m = self.moduleId {
                    if (1...self.course.sectionsArray.count ~= m) && (self.isReachable(section: m - 1)) { 
                        self.showSection(section: m - 1) 
                    }
                }
            })
            self.didRefresh = true
        }, error: {
            //TODO: Handle error type in section downloading
            UIThread.performUI({
                self.refreshControl.endRefreshing()
                self.emptyDatasetState = EmptyDatasetState.connectionError
                self.tableView.reloadData()
                if let m = self.moduleId {
                    if (1...self.course.sectionsArray.count ~= m) && self.isReachable(section: m - 1) { 
                        self.showSection(section: m - 1) 
                    }
                }
            })
            self.didRefresh = true
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showCourse" {
            let dvc = segue.destination as! CoursePreviewViewController
            dvc.course = course
            dvc.hidesBottomBarWhenPushed = true
        }
        if segue.identifier == "showUnits" {
            let dvc = segue.destination as! UnitsViewController
            dvc.section = course.sections[sender as! Int]
            dvc.hidesBottomBarWhenPushed = true
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    func showExamAlert(cancel cancelAction: @escaping ((Void)->Void)) {
        let alert = UIAlertController(title: NSLocalizedString("ExamTitle", comment: ""), message: NSLocalizedString("ShowExamInWeb", comment: ""), preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Open", comment: ""), style: .default, handler: {
            [weak self]
            action in
            if let s = self {
                WebControllerManager.sharedManager.presentWebControllerWithURLString(s.url + "?from_mobile_app=true", inController: s, withKey: "exam", allowsSafari: true, backButtonStyle: .close)
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: {
            action in
            cancelAction()
        }))
        
        self.present(alert, animated: true, completion: {})
    }
    
    func isReachable(section: Int) -> Bool {
        return (course.sections[section].isActive || course.sections[section].testSectionAction != nil) && (course.sections[section].progressId != nil || course.sections[section].isExam)
    }
    
    func showSection(section sectionId: Int) {
        let section = course.sections[sectionId] 
        if section.isExam {
            showExamAlert(cancel: {})
            return
        }
        
        performSegue(withIdentifier: "showUnits", sender: sectionId)
    }
    
    func share(popoverSourceItem: UIBarButtonItem?, popoverView: UIView?, fromParent: Bool) {
        AnalyticsReporter.reportEvent(AnalyticsEvents.Syllabus.shared, parameters: nil)
        let shareBlock: ((UIActivityViewController) -> (Void))? = parentShareBlock
        let url = self.url
        
        DispatchQueue.global(qos: .background).async {
            [weak self] in
            
            let shareVC = SharingHelper.getSharingController(url)
            shareVC.popoverPresentationController?.barButtonItem = popoverSourceItem
            shareVC.popoverPresentationController?.sourceView = popoverView
            DispatchQueue.main.async {
                [weak self] in
                if !fromParent {
                    self?.present(shareVC, animated: true, completion: nil)
                } else {
                    shareBlock?(shareVC)
                }
            }
        }
    }
    
    @available(iOS 9.0, *)
    override var previewActionItems: [UIPreviewActionItem] {
        let shareItem = UIPreviewAction(title: NSLocalizedString("Share", comment: ""), style: .default, handler: {
            [weak self]
            action, vc in
            self?.share(popoverSourceItem: nil, popoverView: nil, fromParent: true)
        })
        return [shareItem]
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        let locationInTableView = tableView.convert(location, from: self.view)
        
        guard let indexPath = tableView.indexPathForRow(at: locationInTableView) else {
            return nil
        }
        
        guard indexPath.row < course.sections.count else {
            return nil
        }
        
        guard let cell = tableView.cellForRow(at: indexPath) as? SectionTableViewCell else {
            return nil
        }
        
        guard tableView(tableView, shouldHighlightRowAt: indexPath) else {
            return nil
        }
        
        if #available(iOS 9.0, *) {
            previewingContext.sourceRect = cell.frame
        } else {
            return nil
        }
        
        guard let unitsVC = ControllerHelper.instantiateViewController(identifier: "UnitsViewController") as? UnitsViewController else {
            return nil
        }
        AnalyticsReporter.reportEvent(AnalyticsEvents.PeekNPop.Section.peeked)
        unitsVC.section = course.sections[indexPath.row]
        unitsVC.parentShareBlock = {
            [weak self]
            shareVC in
            AnalyticsReporter.reportEvent(AnalyticsEvents.PeekNPop.Section.shared)
            shareVC.popoverPresentationController?.sourceView = cell
            self?.present(shareVC, animated: true, completion: nil)
        }
        return unitsVC
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        AnalyticsReporter.reportEvent(AnalyticsEvents.PeekNPop.Section.popped)
        show(viewControllerToCommit, sender: self)
    }

}

extension SectionsViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        showSection(section: indexPath.row)
        //        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return SectionTableViewCell.heightForCellInSection(course.sections[indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return isReachable(section: indexPath.row)
    }
    
}

extension SectionsViewController : UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return course.sections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SectionTableViewCell", for: indexPath) as! SectionTableViewCell
        
        cell.initWithSection(course.sections[indexPath.row], delegate: self)
        
        return cell
    }
}

extension SectionsViewController : PKDownloadButtonDelegate {
    
    fileprivate func askForRemove(okHandler ok: @escaping (Void)->Void, cancelHandler cancel: @escaping (Void)->Void) {
        let alert = UIAlertController(title: NSLocalizedString("RemoveVideoTitle", comment: ""), message: NSLocalizedString("RemoveVideoBody", comment: ""), preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Remove", comment: ""), style: UIAlertActionStyle.destructive, handler: {
            action in
            ok()
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: UIAlertActionStyle.cancel, handler: {
            action in
            cancel()
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    fileprivate func storeSection(_ section: Section, downloadButton: PKDownloadButton!) {
        section.storeVideos(
            progress: {
            progress in
            UIThread.performUI({downloadButton.stopDownloadButton?.progress = CGFloat(progress)})
            }, completion: {
                if section.isCached {
                    UIThread.performUI({downloadButton.state = .downloaded})
                } else {
                    UIThread.performUI({downloadButton.state = .startDownload})
                }            
            }, error: {
                error in
                UIThread.performUI({downloadButton.state = PKDownloadButtonState.startDownload})
        })
    }
    
    func downloadButtonTapped(_ downloadButton: PKDownloadButton!, currentState state: PKDownloadButtonState) {
        if !didRefresh {
            //TODO : Add alert
            print("wait until the section is refreshed")
            return
        }
        
        switch (state) {
        case PKDownloadButtonState.startDownload : 
            
            AnalyticsReporter.reportEvent(AnalyticsEvents.Section.cache, parameters: nil)

            if !ConnectionHelper.shared.isReachable {
                Messages.sharedManager.show3GDownloadErrorMessage(inController: self.navigationController!)
                print("Not reachable to download")
                return
            }
            
            if course.sections[downloadButton.tag].units.count != 0 {
                UIThread.performUI({downloadButton.state = PKDownloadButtonState.downloading})
                storeSection(course.sections[downloadButton.tag], downloadButton: downloadButton)
            } else {
                UIThread.performUI({downloadButton.state = PKDownloadButtonState.pending})
                course.sections[downloadButton.tag].loadUnits(success: {
                    UIThread.performUI({downloadButton.state = PKDownloadButtonState.downloading})
                    self.storeSection(self.course.sections[downloadButton.tag], downloadButton: downloadButton)
                }, error: {
                    print("Error while downloading section's units")
                })
            }
            break
            
        case PKDownloadButtonState.downloading :
            
            AnalyticsReporter.reportEvent(AnalyticsEvents.Section.cancel, parameters: nil)

            downloadButton.state = PKDownloadButtonState.pending

            course.sections[downloadButton.tag].cancelVideoStore(completion: {
                DispatchQueue.main.async(execute: {
                    downloadButton.pendingView?.stopSpin()
                    downloadButton.state = PKDownloadButtonState.startDownload
                })    
            })
            break
            
        case PKDownloadButtonState.downloaded :

            askForRemove(okHandler: {
                AnalyticsReporter.reportEvent(AnalyticsEvents.Section.delete, parameters: nil)

                downloadButton.state = PKDownloadButtonState.pending
                
                self.course.sections[downloadButton.tag].removeFromStore(completion: {
                    DispatchQueue.main.async(execute: {
                        downloadButton.pendingView?.stopSpin()
                        downloadButton.state = PKDownloadButtonState.startDownload
                    })   
                })
                }, cancelHandler: {
                    DispatchQueue.main.async(execute: {
                        downloadButton.pendingView?.stopSpin()
                        downloadButton.state = PKDownloadButtonState.downloaded
                    })   
            })
            break
            
        case PKDownloadButtonState.pending: 
            break
        }
    }
}

extension SectionsViewController : DZNEmptyDataSetSource {
    
    func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
        switch emptyDatasetState {
        case .empty:
            return Images.emptyCoursesPlaceholder
        case .connectionError:
            return Images.noWifiImage.size250x250
        case .refreshing:
            return Images.emptyCoursesPlaceholder
        }
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        var text : String = ""
        switch emptyDatasetState {
        case .empty:
            text = NSLocalizedString("EmptyTitle", comment: "")
            break
        case .connectionError:
            text = NSLocalizedString("ConnectionErrorTitle", comment: "")
            break
        case .refreshing:
            text = NSLocalizedString("Refreshing", comment: "")
            break
        }
        
        let attributes = [NSFontAttributeName: UIFont.boldSystemFont(ofSize: 18.0),
            NSForegroundColorAttributeName: UIColor.darkGray]
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        var text : String = ""
        
        switch emptyDatasetState {
        case .empty:
            text = NSLocalizedString("PullToRefreshSectionsDescription", comment: "")
            break
        case .connectionError:
            text = NSLocalizedString("PullToRefreshSectionsDescription", comment: "")
            break
        case .refreshing:
            text = NSLocalizedString("RefreshingDescription", comment: "")
            break
        }
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .center
        
        let attributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 14.0),
            NSForegroundColorAttributeName: UIColor.lightGray,
            NSParagraphStyleAttributeName: paragraph]
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView!) -> UIColor! {
        return UIColor.white
    }
    
    func verticalOffset(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
        //        print("offset -> \((self.navigationController?.navigationBar.bounds.height) ?? 0 + UIApplication.sharedApplication().statusBarFrame.height)")
        return 44
    }
}

extension SectionsViewController : DZNEmptyDataSetDelegate {
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView!) -> Bool {
        return true
    }
}

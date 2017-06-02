//
//  UnitsViewController.swift
//  Stepic
//
//  Created by Alexander Karpov on 09.10.15.
//  Copyright © 2015 Alex Karpov. All rights reserved.
//

import UIKit
import DownloadButton
import DZNEmptyDataSet

class UnitsViewController: UIViewController, ShareableController, UIViewControllerPreviewingDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    /*
     There are 2 ways of instantiating the controller
     1) a Section object
     2) a Unit id - used for instantiation via navigation by LastStep
     */
    var section : Section?
    var unitId: Int?
    
    var didRefresh = false
    let refreshControl = UIRefreshControl()

    var parentShareBlock : ((UIActivityViewController) -> (Void))? = nil

    fileprivate func updateTitle() {
        self.navigationItem.title = section?.title ?? NSLocalizedString("Module", comment: "")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateTitle()
        self.navigationItem.backBarButtonItem?.title = " "

        tableView.tableFooterView = UIView()
                
        tableView.register(UINib(nibName: "UnitTableViewCell", bundle: nil), forCellReuseIdentifier: "UnitTableViewCell")
        
        let shareBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.action, target: self, action: #selector(UnitsViewController.shareButtonPressed(_:)))
        self.navigationItem.rightBarButtonItem = shareBarButtonItem

        
        
        refreshControl.addTarget(self, action: #selector(UnitsViewController.refreshUnits), for: .valueChanged)
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        refreshControl.layoutIfNeeded()
        
        tableView.emptyDataSetDelegate = self
        tableView.emptyDataSetSource = self
        refreshControl.beginRefreshing()
        
        refreshUnits() 

        if #available(iOS 9.0, *) {
            if(traitCollection.forceTouchCapability == .available) {
                registerForPreviewing(with: self, sourceView: view)
            }
        }
    }

    var url : String? {
        guard let section = section else { 
            return nil 
        }
        if let slug = section.course?.slug,  
            let module = section.course?.sectionsArray.index(of: section.id) {
            return StepicApplicationsInfo.stepicURL + "/course/" + slug + "/syllabus?module=\(module + 1)"
        } else {
            return nil
        }
    }
    
    func shareButtonPressed(_ button: UIBarButtonItem) {
        guard let url = self.url else {
            return
        }
        AnalyticsReporter.reportEvent(AnalyticsEvents.Units.shared, parameters: nil)
        DispatchQueue.global(qos: .background).async {
            let shareVC = SharingHelper.getSharingController(url)
            shareVC.popoverPresentationController?.barButtonItem = button
            DispatchQueue.main.async {
                self.present(shareVC, animated: true, completion: nil)
            }
        }
    }
    
    func share(popoverSourceItem: UIBarButtonItem?, popoverView: UIView?, fromParent: Bool) {
        guard let url = self.url else {
            return
        }
        AnalyticsReporter.reportEvent(AnalyticsEvents.Units.shared, parameters: nil)
        let shareBlock: ((UIActivityViewController) -> (Void))? = parentShareBlock

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
    
    func getSectionByUnit(id: Int) {
        //Search for unit by its id locally
        emptyDatasetState = .refreshing
        if let localUnit = Unit.getUnit(id: id) {
            if let localSection = localUnit.section {
                self.section = localSection
                if let index = section?.unitsArray.index(of: id) {
                    currentlyDisplayingUnitIndex = index
                }
                refreshUnits()
                return
            }
            loadUnit(id: id, localUnit: localUnit)
        }
        
        loadUnit(id: id)
    }
    
    func loadUnit(id: Int, localUnit: Unit? = nil) {
        emptyDatasetState = .refreshing
        _ = ApiDataDownloader.units.retrieve(ids: [id], existing: (localUnit != nil) ? [localUnit!] : [], refreshMode: .update, success: {
            units in
            guard let unit = units.first else { return }
            let localSection = try! Section.getSections(unit.sectionId).first
            _ = ApiDataDownloader.sections.retrieve(ids: [unit.sectionId], existing: (localSection != nil) ? [localSection!] : [], refreshMode: .update, success: {
                [weak self]
                sections in
                guard let section = sections.first else { return }
                unit.section = section
                self?.section = section
                self?.refreshUnits()
            }, error: {
                error in
                UIThread.performUI({
                    self.refreshControl.endRefreshing()
                    self.emptyDatasetState = EmptyDatasetState.connectionError
                })
                self.didRefresh = true
            })
        }, error: {
            error in
            UIThread.performUI({
                self.refreshControl.endRefreshing()
                self.emptyDatasetState = EmptyDatasetState.connectionError
            })
            self.didRefresh = true
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.backBarButtonItem?.title = " "
        tableView.reloadData()
        if (self.refreshControl.isRefreshing) {
            let offset = self.tableView.contentOffset
            self.refreshControl.endRefreshing()
            self.refreshControl.beginRefreshing()
            self.tableView.contentOffset = offset
        }
        
        if let section = section {
            section.loadProgressesForUnits(units: section.units, completion: {
                UIThread.performUI({
                    self.tableView.reloadData()
                })
            })
        }
    }
    
    var emptyDatasetState : EmptyDatasetState = .empty {
        didSet {
            UIThread.performUI{
                self.tableView.reloadEmptyDataSet()
            }
        }
    }

    func refreshUnits() {
        
        guard section != nil else {
            if let id = unitId {
                getSectionByUnit(id: id) 
            }
            return
        }
        
        emptyDatasetState = .refreshing

        updateTitle()
        
        didRefresh = false
        section?.loadUnits(success: {
            UIThread.performUI({
                self.refreshControl.endRefreshing()
                self.tableView.reloadData()
                self.emptyDatasetState = EmptyDatasetState.empty
            })
            self.didRefresh = true
        }, error: {
            UIThread.performUI({
                self.refreshControl.endRefreshing()
                self.emptyDatasetState = EmptyDatasetState.connectionError
            })
            self.didRefresh = true
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    


    // MARK: - Navigation

    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let section = section else {
            return
        }
        
        if segue.identifier == "showSteps" || segue.identifier == "replaceSteps" {
            let dvc = segue.destination as! LessonViewController
            dvc.hidesBottomBarWhenPushed = true
            if let stepsPresentation = sender as? StepsPresentation {
                
                var stepId : Int? = nil
                var startStepId: Int = 0
                
                let index = stepsPresentation.index
                if stepsPresentation.isLastStep {
                    if let l = section.units[index].lesson {
                        startStepId = l.stepsArray.count - 1
                        stepId = l.stepsArray.last
                    }
                }
                
                dvc.initObjects = (lesson: section.units[index].lesson!, startStepId: startStepId, context: .unit)
                dvc.initIds = (stepId: stepId, unitId: section.units[index].id)
                
                dvc.sectionNavigationDelegate = self
                currentlyDisplayingUnitIndex = index
                dvc.navigationRules = (prev: index != 0, next: index < section.units.count - 1)
            }
        }
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    
    var currentlyDisplayingUnitIndex: Int?
    
    func selectUnitAtIndex(_ index: Int, isLastStep: Bool = false, replace: Bool = false) {
        performSegue(withIdentifier: replace ? "replaceSteps" : "showSteps", sender: StepsPresentation(index: index, isLastStep: isLastStep))       
    }
    
    func clearAllSelection() {
        if let selectedRows = tableView.indexPathsForSelectedRows {
            for indexPath in selectedRows {
                tableView.deselectRow(at: indexPath, animated: false)
            }
        }
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        guard let units = section?.units else {
            return nil
        }
        
        let locationInTableView = tableView.convert(location, from: self.view)
        
        guard let indexPath = tableView.indexPathForRow(at: locationInTableView) else {
            return nil
        }
        
        guard indexPath.row < units.count else {
            return nil
        }
        
        guard let cell = tableView.cellForRow(at: indexPath) as? UnitTableViewCell else {
            return nil
        }

        if #available(iOS 9.0, *) {
            previewingContext.sourceRect = cell.frame
        } else {
            return nil
        }
        
        guard let stepsVC = ControllerHelper.instantiateViewController(identifier: "LessonViewController") as? LessonViewController else {
            return nil
        }
        
        guard let lesson = units[indexPath.row].lesson else {
            return nil
        }
        
        AnalyticsReporter.reportEvent(AnalyticsEvents.PeekNPop.Lesson.peeked)
        stepsVC.initObjects = (lesson: lesson, startStepId: 0, context: .unit)
        stepsVC.parentShareBlock = {
            [weak self]
            shareVC in
            AnalyticsReporter.reportEvent(AnalyticsEvents.PeekNPop.Lesson.shared)
            shareVC.popoverPresentationController?.sourceView = cell
            self?.present(shareVC, animated: true, completion: nil)
        }
        return stepsVC
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        show(viewControllerToCommit, sender: self)
        AnalyticsReporter.reportEvent(AnalyticsEvents.PeekNPop.Lesson.popped)
    }
}

class StepsPresentation {
    var index: Int
    var isLastStep: Bool
    init(index: Int, isLastStep: Bool) {
        self.index = index
        self.isLastStep = isLastStep
    }
}

extension UnitsViewController : SectionNavigationDelegate {
    func displayNext() {        
        guard let section = section else {
            return 
        }
        if let uIndex = currentlyDisplayingUnitIndex {
            if uIndex + 1 < section.units.count {
                selectUnitAtIndex(uIndex + 1, replace: true)
            }
        }
    }
    
    func displayPrev() {
        if let uIndex = currentlyDisplayingUnitIndex {
            if uIndex - 1 >= 0 {
                selectUnitAtIndex(uIndex - 1, isLastStep: true, replace: true)
            }
        }        
    }
}

extension UnitsViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectUnitAtIndex((indexPath as NSIndexPath).row)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = section else {
            return 0
        } 
        return UnitTableViewCell.heightForCellWithUnit(section.units[(indexPath as NSIndexPath).row])
    }
    
}

extension UnitsViewController : UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let ssection = self.section else {
            return 0
        }
        return ssection.units.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UnitTableViewCell", for: indexPath) as! UnitTableViewCell
        
        guard let section = section else {
            return cell
        }
        
        cell.initWithUnit(section.units[(indexPath as NSIndexPath).row], delegate: self)
        
        return cell
    }
}

extension UnitsViewController : PKDownloadButtonDelegate {
    
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
    
    fileprivate func storeLesson(_ lesson: Lesson?, downloadButton: PKDownloadButton!) {
        lesson?.storeVideos(progress: {
            progress in
            UIThread.performUI({downloadButton.stopDownloadButton?.progress = CGFloat(progress)})
            }, completion: {
                downloaded, cancelled in 
                if cancelled == 0 { 
                    UIThread.performUI({downloadButton.state = PKDownloadButtonState.downloaded})
                } else {
                    UIThread.performUI({downloadButton.state = PKDownloadButtonState.startDownload})
                }
            }, error:  {
                error in
                UIThread.performUI({downloadButton.state = PKDownloadButtonState.startDownload})
        })
    }
    
    func downloadButtonTapped(_ downloadButton: PKDownloadButton!, currentState state: PKDownloadButtonState) {
        
        if !didRefresh {
            //TODO : Add alert
            print("wait until the lesson is refreshed")
            return
        }
        
        guard let section = section else {
            return
        }

        
        switch (state) {
        case PKDownloadButtonState.startDownload : 
            
            AnalyticsReporter.reportEvent(AnalyticsEvents.Unit.cache, parameters: nil)
            
            if !ConnectionHelper.shared.isReachable {
                Messages.sharedManager.show3GDownloadErrorMessage(inController: self.navigationController!)
                print("Not reachable to download")
                return
            }
            
            downloadButton.state = PKDownloadButtonState.downloading
            
            if section.units[downloadButton.tag].lesson?.steps.count != 0 {
                storeLesson(section.units[downloadButton.tag].lesson, downloadButton: downloadButton)
            } else {
                section.units[downloadButton.tag].lesson?.loadSteps(completion: {
                    self.storeLesson(section.units[downloadButton.tag].lesson, downloadButton: downloadButton)
                })
            }
            break
            
        case PKDownloadButtonState.downloading :
            AnalyticsReporter.reportEvent(AnalyticsEvents.Unit.cancel, parameters: nil)

            downloadButton.state = PKDownloadButtonState.pending
            downloadButton.pendingView?.startSpin()

            section.units[downloadButton.tag].lesson?.cancelVideoStore(completion: {
                DispatchQueue.main.async(execute: {
                    downloadButton.pendingView?.stopSpin()
                    downloadButton.state = PKDownloadButtonState.startDownload
                })
            })
            break
            
        case PKDownloadButtonState.downloaded :
        
        
            AnalyticsReporter.reportEvent(AnalyticsEvents.Unit.delete, parameters: nil)

            downloadButton.state = PKDownloadButtonState.pending
            downloadButton.pendingView?.startSpin()
            askForRemove(okHandler: {
                section.units[downloadButton.tag].lesson?.removeFromStore(completion: {
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

extension UnitsViewController : DZNEmptyDataSetSource {
    
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
            text = NSLocalizedString("PullToRefreshUnitsTitle", comment: "")
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
            text = NSLocalizedString("PullToRefreshUnitsDescription", comment: "")
            break
        case .connectionError:
            text = NSLocalizedString("PullToRefreshUnitsDescription", comment: "")
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

extension UnitsViewController : DZNEmptyDataSetDelegate {
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView!) -> Bool {
        return true
    }
}

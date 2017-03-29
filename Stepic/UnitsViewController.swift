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

class UnitsViewController: UIViewController {

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

    fileprivate func updateTitle() {
        self.navigationItem.title = section?.title ?? NSLocalizedString("Module", comment: "")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateTitle()
        self.navigationItem.backBarButtonItem?.title = " "

        tableView.tableFooterView = UIView()
                
        tableView.register(UINib(nibName: "UnitTableViewCell", bundle: nil), forCellReuseIdentifier: "UnitTableViewCell")
        
        
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
        // Do any additional setup after loading the view.
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
        _ = ApiDataDownloader.sharedDownloader.getUnitsByIds([id], deleteUnits: (localUnit != nil) ? [localUnit!] : [], refreshMode: .update, success: {
            units in
            guard let unit = units.first else { return }
            let localSection = try! Section.getSections(unit.sectionId).first
            _ = ApiDataDownloader.sharedDownloader.getSectionsByIds([unit.sectionId], existingSections: (localSection != nil) ? [localSection!] : [], refreshMode: .update, success: {
                [weak self]
                sections in
                guard let section = sections.first else { return }
                unit.section = section
                self?.section = section
                self?.refreshUnits()
            }, failure: {
                error in
                UIThread.performUI({
                    self.refreshControl.endRefreshing()
                    self.emptyDatasetState = EmptyDatasetState.connectionError
                })
                self.didRefresh = true
            })
        }, failure: {
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
            let dvc = segue.destination as! StepsViewController
            dvc.hidesBottomBarWhenPushed = true
            if let stepsPresentation = sender as? StepsPresentation {
                
                let index = stepsPresentation.index
                if stepsPresentation.isLastStep {
                    if let l = section.units[index].lesson {
                        dvc.startStepId = l.stepsArray.count - 1
                    }
                }
                dvc.lesson = section.units[index].lesson
                dvc.sectionNavigationDelegate = self
                dvc.unitId = section.units[index].id
                currentlyDisplayingUnitIndex = index
                dvc.shouldNavigateToPrev = index != 0
                dvc.shouldNavigateToNext = index < section.units.count - 1
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

//
//  DiscussionsViewController.swift
//  Stepic
//
//  Created by Alexander Karpov on 08.06.16.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import UIKit
import SDWebImage
import DZNEmptyDataSet

enum DiscussionsEmptyDataSetState {
    case Error, Empty, None
}

enum SeparatorType {
    case Small, Big, None
}

struct DiscussionsCellInfo {
    var comment: Comment?
    var loadRepliesFor: Comment?
    var loadDiscussions: Bool?
    var separatorType: SeparatorType = .None
    
    init(comment: Comment, separatorType: SeparatorType) {
        self.comment = comment
        self.separatorType = separatorType
    }
    
    init(loadRepliesFor: Comment) {
        self.loadRepliesFor = loadRepliesFor
    }
    
    init(loadDiscussions: Bool) {
        self.loadDiscussions = loadDiscussions
    }
}

class DiscussionsViewController: UIViewController {

    var discussionProxyId: String!
    var target: Int!
    
    @IBOutlet weak var tableView: UITableView!
    
    var refreshControl : UIRefreshControl? = UIRefreshControl()
    
    var cellsInfo = [DiscussionsCellInfo]()
    
    var emptyDatasetState : DiscussionsEmptyDataSetState = .None {
        didSet {
            tableView.reloadEmptyDataSet()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        print("did load")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self
        emptyDatasetState = .None
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 44.0
        
        tableView.tableFooterView = UIView()
        
        tableView.registerNib(UINib(nibName: "DiscussionTableViewCell", bundle: nil), forCellReuseIdentifier: "DiscussionTableViewCell")
        tableView.registerNib(UINib(nibName: "LoadMoreTableViewCell", bundle: nil), forCellReuseIdentifier: "LoadMoreTableViewCell")
        
        self.title = NSLocalizedString("Discussions", comment: "")
        
        let writeCommentItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Compose, target: self, action: #selector(DiscussionsViewController.writeCommentPressed))
        self.navigationItem.rightBarButtonItem = writeCommentItem
        
        refreshControl?.addTarget(self, action: #selector(DiscussionsViewController.reloadDiscussions), forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl ?? UIView())
        refreshControl?.beginRefreshing()
        reloadDiscussions()
    }

    struct DiscussionIds {
        var all = [Int]()
        var loaded = [Int]()
        
        var leftToLoad : Int {
            return all.count - loaded.count
        }
    }
    
    struct Replies {
        var loaded = [Int : [Comment]]()
        
        func leftToLoad(comment: Comment) -> Int {
            if let loadedCount = loaded[comment.id]?.count {
                return comment.repliesIds.count - loadedCount
            } else {
                return comment.repliesIds.count
            }
        }
    }
    
    var discussionIds = DiscussionIds()
    var replies = Replies()
    var userInfos = [Int: UserInfo]()
    var discussions = [Comment]()
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func writeCommentPressed() {
        presentWriteCommentController(parent: nil)
    }
    
    func resetData(withReload: Bool) {
        discussionIds = DiscussionIds()
        replies = Replies()
        userInfos = [Int: UserInfo]()
        discussions = [Comment]()
        cellForDiscussionId = [:]
        
        if withReload {
            self.reloadTableData()
        }
    }
    
    let discussionLoadingInterval = 10
    let repliesLoadingInterval = 10
    
    func getNextDiscussionIdsToLoad() -> [Int] {
        let startIndex = discussionIds.loaded.count
        return Array(discussionIds.all[startIndex ..< startIndex + min(discussionLoadingInterval, discussionIds.leftToLoad)])
    }
    
    func getNextReplyIdsToLoad(section: Int) -> [Int] {
        if discussions.count <= section {
            return []
        } 
        let discussion = discussions[section]

        return getNextReplyIdsToLoad(discussion)
    }
    
    func getNextReplyIdsToLoad(discussion: Comment) -> [Int] {
        let loadedIds : [Int] = replies.loaded[discussion.id]?.map({return $0.id}) ?? []
        let loadedReplies = Set<Int>(loadedIds)
        var res : [Int] = []
        
        for replyId in discussion.repliesIds {
            if !loadedReplies.contains(replyId) {
                res += [replyId]
                if res.count == repliesLoadingInterval {
                    return res
                }
            }
        }
        return res
    }
    
    func loadDiscussions(ids: [Int], success: (Void -> Void)? = nil) {
        self.emptyDatasetState = .None
        ApiDataDownloader.comments.retrieve(ids, success: 
            {
                [weak self]
                retrievedDiscussions, retrievedUserInfos in 
                
                if let s = self {
                    //get superDiscussions (those who have no parents)
                    let superDiscussions = Sorter.sort(retrievedDiscussions.filter({$0.parentId == nil}), byIds: ids, canMissElements: true)
                
                    s.discussionIds.loaded += ids
                    s.discussions += superDiscussions
                    
                    for (userId, info) in retrievedUserInfos {
                        s.userInfos[userId] = info
                    }
                    
                    var changedDiscussionIds = Set<Int>()
                    //get all replies
                    for reply in retrievedDiscussions.filter({$0.parentId != nil}) {
                        if let parentId = reply.parentId {
                            if s.replies.loaded[parentId] == nil {
                                s.replies.loaded[parentId] = []
                            }
                            s.replies.loaded[parentId]? += [reply]
                            changedDiscussionIds.insert(parentId)
                        }
                    }
                    
                    //TODO: Possibly should sort all changed reply values 
                    for discussionId in changedDiscussionIds {
                        if let index = s.discussions.indexOf({$0.id == discussionId}) {
                            s.replies.loaded[discussionId]! = Sorter.sort(s.replies.loaded[discussionId]!, byIds: s.discussions[index].repliesIds, canMissElements: true)
                        }
                    }
                                        
                    success?()
                }
            }, error: {
                [weak self]
                errorString in
                print(errorString)
                self?.emptyDatasetState = .Error
                UIThread.performUI {
                    [weak self] in
                    self?.refreshControl?.endRefreshing()
                }
            }
        )
    }
    
    func reloadTableData() {
        //TODO: Create comments list here, then reload tableView data
        cellsInfo = []
        for discussion in discussions {
            cellsInfo.append(DiscussionsCellInfo(comment: discussion, separatorType: .Small))
            for reply in replies.loaded[discussion.id] ?? [] {
                cellsInfo.append(DiscussionsCellInfo(comment: reply, separatorType: .Small))
            }
            
            let left = replies.leftToLoad(discussion)
            if left > 0 {
                cellsInfo.append(DiscussionsCellInfo(loadRepliesFor: discussion))
            } else {
                cellsInfo[cellsInfo.count - 1].separatorType = .Big
            }
        }
        
        if discussionIds.leftToLoad > 0 {
            cellsInfo.append(DiscussionsCellInfo(loadDiscussions: true))
        }
        
        UIThread.performUI({
            [weak self] in
            if self?.cellsInfo.count == 0 {                
                self?.tableView.emptyDataSetSource = self
                self?.emptyDatasetState = .Empty
            } else {
                self?.tableView.emptyDataSetSource = nil
            }
            self?.tableView.reloadData()
        })
    }
    
    
    var isReloading: Bool = false
    
    func reloadDiscussions() {
        emptyDatasetState = .None
        if isReloading {
            return
        }
        resetData(false)
        isReloading = true
        ApiDataDownloader.discussionProxies.retrieve(discussionProxyId, success: 
            {
                [weak self] 
                discussionProxy in
                self?.discussionIds.all = discussionProxy.discussionIds
                if let discussionIdsToLoad = self?.getNextDiscussionIdsToLoad() {
                    self?.loadDiscussions(discussionIdsToLoad, success: 
                        {            
                            [weak self] in
                            UIThread.performUI {
                                self?.refreshControl?.endRefreshing()
                                self?.reloadTableData()
                                self?.isReloading = false
                            }
                        }
                    )
                }
            }, error: {
                [weak self]
                errorString in
                print(errorString)
                self?.isReloading = false
                self?.emptyDatasetState = .Error
                self?.reloadTableData()
                UIThread.performUI {
                    [weak self] in
                    self?.refreshControl?.endRefreshing()
                }
            }
        )
    }
    
    func isShowMoreEnabledForSection(section: Int) -> Bool {
        if discussions.count <= section  {
            return false
        }
        
        let discussion = discussions[section]
        return replies.leftToLoad(discussion) > 0 
    }
    
    func isShowMoreDiscussionsEnabled() -> Bool {
        return discussionIds.leftToLoad > 0
    }
    
    func handleSelectDiscussion(comment: Comment, cell: UITableViewCell? = nil, completion: (Void->Void)?) {
        let alert = DiscussionAlertConstructor.getReplyAlert({
            [weak self] in
            self?.presentWriteCommentController(parent: comment.parentId ?? comment.id)
        })
        
        if let popoverController = alert.popoverPresentationController, 
            let c = cell {
            popoverController.sourceView = c.contentView
            popoverController.sourceRect = c.contentView.bounds
        }
        
        self.presentViewController(alert, animated: true, completion: {
            completion?()
        })
    }
    
    func presentWriteCommentController(parent parent: Int?) {
        if let writeController = ControllerHelper.instantiateViewController(identifier: "WriteCommentViewController", storyboardName: "DiscussionsStoryboard") as? WriteCommentViewController {
            writeController.parent = parent
            writeController.target = target
            writeController.delegate = self
            navigationController?.pushViewController(writeController, animated: true)
        }
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    //TODO: Think when to reload this value
    var cellForDiscussionId = [Int: DiscussionTableViewCell]()
}

extension DiscussionsViewController : UITableViewDelegate {
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        print("CGFLoat min -> \(CGFloat.min)")
        return CGFloat.min
    }
    
    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.min
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        print("did select row at indexPath \(indexPath)")
        if let comment = cellsInfo[indexPath.row].comment {            
            let cell = tableView.cellForRowAtIndexPath(indexPath)
            handleSelectDiscussion(comment, cell: cell, completion: {
                [weak self] in
                UIThread.performUI { 
                    self?.tableView.deselectRowAtIndexPath(indexPath, animated: true) 
                }
            })
        }
        
        if let loadRepliesFor = cellsInfo[indexPath.row].loadRepliesFor {
            let idsToLoad = getNextReplyIdsToLoad(loadRepliesFor)
            loadDiscussions(idsToLoad, success: {
                [weak self] in
                UIThread.performUI {
//                    self?.tableView.beginUpdates()
                    //TODO: Change to animated reload
                    self?.reloadTableData()
//                    self?.tableView.endUpdates()
                    self?.tableView.deselectRowAtIndexPath(indexPath, animated: true)
                }
            })

        }
        
        if let shouldLoadDiscussions = cellsInfo[indexPath.row].loadDiscussions {
            let idsToLoad = getNextDiscussionIdsToLoad()
            loadDiscussions(idsToLoad, success: {
                [weak self] in
                UIThread.performUI {
                    if let s = self {
//                        s.tableView.beginUpdates()
                        self?.reloadTableData()
//                        s.tableView.endUpdates()
                        self?.tableView.deselectRowAtIndexPath(indexPath, animated: true)
                    }
                }
            })
        }
    }
}

extension DiscussionsViewController : UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellsInfo.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        print("cell for row \(indexPath.row)")
                
        if let comment = cellsInfo[indexPath.row].comment {
            
            if let cell = cellForDiscussionId[comment.id] {
                print("cell is cached")
                if cell.separatorType != cellsInfo[indexPath.row].separatorType {
                    cell.separatorType = cellsInfo[indexPath.row].separatorType
                    cellForDiscussionId[comment.id] = cell
                }
                return cell
            }
            
            print("comment cell")
            let cell = NSBundle.mainBundle().loadNibNamed("DiscussionTableViewCell", owner: self, options: nil)[0]  as!  DiscussionTableViewCell

            if let user = userInfos[comment.userId] {
                cell.initWithComment(comment, user: user, separatorType: cellsInfo[indexPath.row].separatorType) 
                cell.heightUpdateBlock = {
                    [weak self] in
                    dispatch_async(dispatch_get_main_queue(), {
                        print("height update block for \(indexPath.row)")
                        self?.tableView.beginUpdates()                            
                        self?.tableView.endUpdates()
                    })
                }
                cellForDiscussionId[comment.id] = cell
            } 
            return cell
        } 
        
        if let loadRepliesFor = cellsInfo[indexPath.row].loadRepliesFor {
            print("load replies cell")
            let cell = NSBundle.mainBundle().loadNibNamed("LoadMoreTableViewCell", owner: self, options: nil)[0]  as! LoadMoreTableViewCell
            cell.showMoreLabel.text = NSLocalizedString("ShowMoreReplies", comment: "")
            return cell
        }
        
        if let loadDiscussions = cellsInfo[indexPath.row].loadDiscussions {
            print("load discussions cell")
            let cell = NSBundle.mainBundle().loadNibNamed("LoadMoreTableViewCell", owner: self, options: nil)[0]  as! LoadMoreTableViewCell
            cell.showMoreLabel.text = NSLocalizedString("ShowMoreReplies", comment: "")
            return cell
        }
        
        return UITableViewCell()
    }
}

extension DiscussionsViewController : WriteCommentDelegate {
    func didWriteComment(comment: Comment, userInfo: UserInfo) {
        print(comment.parentId)
        userInfos[userInfo.id] = userInfo
        if let parentId = comment.parentId {
            //insert row in an existing section
            if let section = discussions.indexOf({$0.id == parentId}) {
                discussions[section].repliesIds += [comment.id]
                if replies.loaded[parentId] == nil {
                    replies.loaded[parentId] = []
                }
                replies.loaded[parentId]! += [comment]
//                tableView.beginUpdates()
                reloadTableData()
//                let p = NSIndexPath(forRow: replies.loaded[parentId]!.count - 1, inSection: section)
//                tableView.insertRowsAtIndexPaths([p], withRowAnimation: .Automatic)
//                tableView.endUpdates()
            }
        } else {
            //insert section
            discussionIds.all.insert(comment.id, atIndex: 0)
            discussionIds.loaded.insert(comment.id, atIndex: 0)
            discussions.insert(comment, atIndex: 0)
//            tableView.beginUpdates()
            reloadTableData()
//            let index = NSIndexSet(index: 0)
//            tableView.insertSections(index, withRowAnimation: .Automatic)
//            tableView.endUpdates()
        }
    }
}

extension DiscussionsViewController : DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    func imageForEmptyDataSet(scrollView: UIScrollView!) -> UIImage! {
        switch emptyDatasetState {
        case .Empty:
            return Images.noCommentsWhite.size200x200
        case .Error:
            return Images.noWifiImage.white
        case .None:
            return Images.noCommentsWhite.size200x200
        }
    }
    
    func titleForEmptyDataSet(scrollView: UIScrollView!) -> NSAttributedString! {
        var text : String = ""
        switch emptyDatasetState {
        case .Empty:
            text = NSLocalizedString("NoDiscussionsTitle", comment: "")
            break
        case .Error:
            text = NSLocalizedString("ConnectionErrorTitle", comment: "")
            break
        case .None:
            text = ""
            break
        }
        
        let attributes = [NSFontAttributeName: UIFont.boldSystemFontOfSize(18.0),
                          NSForegroundColorAttributeName: UIColor.darkGrayColor()]
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    func descriptionForEmptyDataSet(scrollView: UIScrollView!) -> NSAttributedString! {
        var text : String = ""
        
        switch emptyDatasetState {
        case .Empty:
            text = NSLocalizedString("NoDiscussionsDescription", comment: "")
            break
        case .Error:
            text = NSLocalizedString("ConnectionErrorPullToRefresh", comment: "")
            break
        case .None: 
            text = NSLocalizedString("RefreshingDiscussions", comment: "")
            break
        }
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .ByWordWrapping
        paragraph.alignment = .Center
        
        let attributes = [NSFontAttributeName: UIFont.systemFontOfSize(14.0),
                          NSForegroundColorAttributeName: UIColor.lightGrayColor(),
                          NSParagraphStyleAttributeName: paragraph]
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    func verticalOffsetForEmptyDataSet(scrollView: UIScrollView!) -> CGFloat {
        //        print("offset -> \((self.navigationController?.navigationBar.bounds.height) ?? 0 + UIApplication.sharedApplication().statusBarFrame.height)")
        return 0
    }
    
    func emptyDataSetShouldAllowScroll(scrollView: UIScrollView!) -> Bool {
        return true
    }
}

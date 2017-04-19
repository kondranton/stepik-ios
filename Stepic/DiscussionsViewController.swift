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
    case error, empty, none
}

enum SeparatorType {
    case small, big, none
}

struct DiscussionsCellInfo {
    var comment: Comment?
    var loadRepliesFor: Comment?
    var loadDiscussions: Bool?
    var separatorType: SeparatorType = .none
    
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
    
    var emptyDatasetState : DiscussionsEmptyDataSetState = .none {
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
        emptyDatasetState = .none
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 44.0
        
        tableView.tableFooterView = UIView()
        
        tableView.register(UINib(nibName: "DiscussionTableViewCell", bundle: nil), forCellReuseIdentifier: "DiscussionTableViewCell")
        tableView.register(UINib(nibName: "LoadMoreTableViewCell", bundle: nil), forCellReuseIdentifier: "LoadMoreTableViewCell")
        tableView.register(UINib(nibName: "DiscussionWebTableViewCell", bundle: nil), forCellReuseIdentifier: "DiscussionWebTableViewCell")
        
        self.title = NSLocalizedString("Discussions", comment: "")
        
        let writeCommentItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.compose, target: self, action: #selector(DiscussionsViewController.writeCommentPressed))
        self.navigationItem.rightBarButtonItem = writeCommentItem
        
        refreshControl?.addTarget(self, action: #selector(DiscussionsViewController.reloadDiscussions), for: .valueChanged)
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
        
        func leftToLoad(_ comment: Comment) -> Int {
            if let loadedCount = loaded[comment.id]?.count {
                return comment.repliesIds.count - loadedCount
            } else {
                return comment.repliesIds.count
            }
        }
    }
    
    var discussionIds = DiscussionIds()
    var replies = Replies()
    var discussions = [Comment]()
    var votes = [String: Vote]()
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    func writeCommentPressed() {
        if !AuthInfo.shared.isAuthorized {
            RoutingManager.auth.routeFrom(controller: self, success: {
                [weak self] in
                if let s = self {
                    s.presentWriteCommentController(parent: nil)
                }
            }, cancel: nil)
            return
        } else {
            presentWriteCommentController(parent: nil)
        }

    }
    
    func resetData(_ withReload: Bool) {
        discussionIds = DiscussionIds()
        replies = Replies()
        discussions = [Comment]()
        estimatedHeightForDiscussionId = [:]
        
        if withReload {
            self.reloadTableData()
        }
    }
    
    let discussionLoadingInterval = 20
    let repliesLoadingInterval = 20
    
    func getNextDiscussionIdsToLoad() -> [Int] {
        let startIndex = discussionIds.loaded.count
        return Array(discussionIds.all[startIndex ..< startIndex + min(discussionLoadingInterval, discussionIds.leftToLoad)])
    }
    
    func getNextReplyIdsToLoad(_ section: Int) -> [Int] {
        if discussions.count <= section {
            return []
        } 
        let discussion = discussions[section]

        return getNextReplyIdsToLoad(discussion)
    }
    
    func getNextReplyIdsToLoad(_ discussion: Comment) -> [Int] {
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
    
    
    
    func loadDiscussions(_ ids: [Int], success: ((Void) -> Void)? = nil) {
        self.emptyDatasetState = .none
        
        //TODO: Check if token should be refreshed before that request
        performRequest({
            _ = ApiDataDownloader.comments.retrieve(ids, success: {
                [weak self]
                retrievedDiscussions in 
                
                if let s = self {
                    //get superDiscussions (those who have no parents)
                    let superDiscussions = Sorter.sort(retrievedDiscussions.filter({$0.parentId == nil}), byIds: ids, canMissElements: true)
                
                    s.discussionIds.loaded += ids
                    s.discussions += superDiscussions
                    
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
                        if let index = s.discussions.index(where: {$0.id == discussionId}) {
                            s.replies.loaded[discussionId]! = Sorter.sort(s.replies.loaded[discussionId]!, byIds: s.discussions[index].repliesIds, canMissElements: true)
                        }
                    }
                                        
                    success?()
                }
            }, error: {
                [weak self]
                errorString in
                print(errorString)
                self?.emptyDatasetState = .error
                UIThread.performUI {
                    [weak self] in
                    self?.refreshControl?.endRefreshing()
                }
            }
            )
        }, error: {
            [weak self] 
            error in
            guard let s = self else { return }
            if error == PerformRequestError.noAccessToRefreshToken {
                AuthInfo.shared.token = nil
                RoutingManager.auth.routeFrom(controller: s, success: {
                    [weak self] in 
                    self?.reloadDiscussions()
                }, cancel: nil)
            }
        })
    }
    
    func reloadTableData(_ emptyState: DiscussionsEmptyDataSetState = .empty) {
        //TODO: Create comments list here, then reload tableView data
        cellsInfo = []
        for discussion in discussions {
            let c = DiscussionsCellInfo(comment: discussion, separatorType: .small)
            cellsInfo.append(c)
//            constructDiscussionCell(c)
            
            for reply in replies.loaded[discussion.id] ?? [] {
                let c = DiscussionsCellInfo(comment: reply, separatorType: .small)
                cellsInfo.append(c)
//                constructDiscussionCell(c)
            }
            
            let left = replies.leftToLoad(discussion)
            if left > 0 {
                cellsInfo.append(DiscussionsCellInfo(loadRepliesFor: discussion))
            } else {
                cellsInfo[cellsInfo.count - 1].separatorType = .big
            }
        }
        
        if discussionIds.leftToLoad > 0 {
            cellsInfo.append(DiscussionsCellInfo(loadDiscussions: true))
        }
        
        UIThread.performUI({
            [weak self] in
            if self?.cellsInfo.count == 0 {                
                self?.tableView.emptyDataSetSource = self
                self?.emptyDatasetState = emptyState
            } else {
                self?.tableView.emptyDataSetSource = nil
            }
            self?.tableView.reloadData()
        })
    }
    
    
    var isReloading: Bool = false
    
    func reloadDiscussions() {
        emptyDatasetState = .none
        if isReloading {
            return
        }
        resetData(false)
        isReloading = true
        
        performRequest({
            [weak self] in
            if let discussionProxyId = self?.discussionProxyId {
                _ = ApiDataDownloader.discussionProxies.retrieve(discussionProxyId, success: 
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
                        self?.reloadTableData(.error)
                        UIThread.performUI {
                            [weak self] in
                            self?.refreshControl?.endRefreshing()
                        }
                    }
                )
            }
        }, error:  {
            [weak self]
            error in
            guard let s = self else { return }
            
            self?.isReloading = false
            self?.reloadTableData(.error)
            UIThread.performUI {
                [weak self] in
                self?.refreshControl?.endRefreshing()
            }
            
            if error == PerformRequestError.noAccessToRefreshToken {
                AuthInfo.shared.token = nil
                RoutingManager.auth.routeFrom(controller: s, success: {
                    [weak self] in 
                    self?.reloadDiscussions()
                }, cancel: nil)
            }
            
        })
    }
    
    func isShowMoreEnabledForSection(_ section: Int) -> Bool {
        if discussions.count <= section  {
            return false
        }
        
        let discussion = discussions[section]
        return replies.leftToLoad(discussion) > 0 
    }
    
    func isShowMoreDiscussionsEnabled() -> Bool {
        return discussionIds.leftToLoad > 0
    }
    
    func setLiked(_ comment: Comment, cell: UITableViewCell) {
        if let c = cell as? DiscussionTableViewCell {
            if let value = comment.vote.value {
                let vToSet : VoteValue? = (value == VoteValue.Epic) ? nil : .Epic
                let v = Vote(id: comment.vote.id, value: vToSet)
                performRequest({
                    _ = ApiDataDownloader.votes.update(v, success: 
                        {
                            vote in
                            comment.vote = vote
                            switch value {
                            case .Abuse: 
                                comment.abuseCount -= 1
                                comment.epicCount += 1
                                c.setLiked(true, likesCount: comment.epicCount)
                                AnalyticsReporter.reportEvent(AnalyticsEvents.Discussion.liked, parameters: nil)
                                
                            case .Epic:
                                comment.epicCount -= 1
                                c.setLiked(false, likesCount: comment.epicCount)
                                AnalyticsReporter.reportEvent(AnalyticsEvents.Discussion.unliked, parameters: nil)
                            }
                        }, error: {
                            errorMsg in
                            print(errorMsg)
                    })
                }, error: {
                    [weak self] 
                    error in
                    guard let s = self else { return }
                    if error == PerformRequestError.noAccessToRefreshToken {
                        AuthInfo.shared.token = nil
                        RoutingManager.auth.routeFrom(controller: s, success: {
                            [weak self] in 
                            self?.reloadDiscussions()
                        }, cancel: nil)
                    }
                })

            } else {
                let v = Vote(id: comment.vote.id, value: .Epic)
                performRequest({
                    _ = ApiDataDownloader.votes.update(v, success: 
                        {
                            vote in
                            comment.vote = vote
                            comment.epicCount += 1
                            c.setLiked(true, likesCount: comment.epicCount)
                            AnalyticsReporter.reportEvent(AnalyticsEvents.Discussion.liked, parameters: nil)
                        }, error: {
                            errorMsg in
                            print(errorMsg)
                        }
                    )
                }, error: {
                    [weak self] 
                    error in
                    guard let s = self else { return }
                    if error == PerformRequestError.noAccessToRefreshToken {
                        AuthInfo.shared.token = nil
                        RoutingManager.auth.routeFrom(controller: s, success: {
                            [weak self] in 
                            self?.reloadDiscussions()
                        }, cancel: nil)
                    }
                })
            }
        }
    }
    
    func setAbused(_ comment: Comment, cell: UITableViewCell) {
        if let c = cell as? DiscussionTableViewCell {
            if let value = comment.vote.value {
                let v = Vote(id: comment.vote.id, value: .Abuse)
                performRequest({
                    _ = ApiDataDownloader.votes.update(v, success: 
                        {
                            vote in
                            comment.vote = vote
                            switch value {
                            case .Abuse: 
                                break
                            case .Epic:
                                comment.epicCount -= 1
                                comment.abuseCount += 1
                                c.setLiked(false, likesCount: comment.epicCount)
                                AnalyticsReporter.reportEvent(AnalyticsEvents.Discussion.abused, parameters: nil)
                            }
                        }, error: {
                            errorMsg in
                            print(errorMsg)
                    })
                }, error: {
                    [weak self] 
                    error in
                    guard let s = self else { return }
                    if error == PerformRequestError.noAccessToRefreshToken {
                        AuthInfo.shared.token = nil
                        RoutingManager.auth.routeFrom(controller: s, success: {
                            [weak self] in 
                            self?.reloadDiscussions()
                        }, cancel: nil)
                    }
                })

            } else {
                let v = Vote(id: comment.vote.id, value: .Abuse)
                performRequest({
                    _ = ApiDataDownloader.votes.update(v, success: 
                        {
                            vote in
                            comment.vote = vote
                            comment.abuseCount += 1
                            AnalyticsReporter.reportEvent(AnalyticsEvents.Discussion.abused, parameters: nil)
                            
                        }, error: {
                            errorMsg in
                            print(errorMsg)
                        }
                    )
                }, error: {
                    [weak self] 
                    error in
                    guard let s = self else { return }
                    if error == PerformRequestError.noAccessToRefreshToken {
                        AuthInfo.shared.token = nil
                        RoutingManager.auth.routeFrom(controller: s, success: {
                            [weak self] in 
                            self?.reloadDiscussions()
                        }, cancel: nil)
                    }
                })
            }
        }
    }
    
    func handleSelectDiscussion(_ comment: Comment, cell: UITableViewCell, completion: ((Void)->Void)?) {
        let alert = DiscussionAlertConstructor.getCommentAlert(comment, 
            replyBlock: {
                [weak self] in
                guard let s = self else { return }
                if !AuthInfo.shared.isAuthorized {
                    RoutingManager.auth.routeFrom(controller: s, success: {
                        [weak self] in
                        self?.presentWriteCommentController(parent: comment.parentId ?? comment.id)
                    }, cancel: nil)
                } else {
                    self?.presentWriteCommentController(parent: comment.parentId ?? comment.id)
                }
            }, likeBlock: {
                [weak self] in
                guard let s = self else { return }
                if !AuthInfo.shared.isAuthorized {
                    RoutingManager.auth.routeFrom(controller: s, success: {
                        [weak self] in
                        self?.setLiked(comment, cell: cell)
                    }, cancel: nil)
                } else {
                    self?.setLiked(comment, cell: cell)
                }
            }, abuseBlock:  {
                [weak self] in
                guard let s = self else { return }
                if !AuthInfo.shared.isAuthorized {
                    RoutingManager.auth.routeFrom(controller: s, success: {
                        [weak self] in
                        self?.setAbused(comment, cell: cell)
                    }, cancel: nil)
                } else {
                    self?.setAbused(comment, cell: cell)
                }
            }, openURLBlock:  {
                [weak self] 
                url in     
                if let s = self {
                    WebControllerManager.sharedManager.presentWebControllerWithURL(url, inController: s, withKey: "external link", allowsSafari: true, backButtonStyle: BackButtonStyle.close)
                }
            }
        )
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = cell
            popoverController.sourceRect = cell.bounds
        }
        
//        alert.view.layoutIfNeeded()
        
        self.present(alert, animated: true, completion: {
            completion?()
        })
    }
    
    func presentWriteCommentController(parent: Int?) {
        if let writeController = ControllerHelper.instantiateViewController(identifier: "WriteCommentViewController", storyboardName: "DiscussionsStoryboard") as? WriteCommentViewController {
            writeController.parentId = parent
            writeController.target = target
            writeController.delegate = self
            navigationController?.pushViewController(writeController, animated: true)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    //TODO: Think when to reload this value
    
    var estimatedHeightForDiscussionId = [Int: CGFloat]()
    var webViewHeightForDiscussionId = [Int: CGFloat]()
}

extension DiscussionsViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if let comment = cellsInfo[(indexPath as NSIndexPath).row].comment {         
            if let est = estimatedHeightForDiscussionId[comment.id] {
                return est
            }
        }
        return 44
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let comment = cellsInfo[(indexPath as NSIndexPath).row].comment {            
            let cell = tableView.cellForRow(at: indexPath)
            if let c = cell {
                handleSelectDiscussion(comment, cell: c, completion: {
                    [weak self] in
                    UIThread.performUI { 
                        self?.tableView.deselectRow(at: indexPath, animated: true) 
                    }
                })
            }
        }
        
        if let loadRepliesFor = cellsInfo[(indexPath as NSIndexPath).row].loadRepliesFor {
            let idsToLoad = getNextReplyIdsToLoad(loadRepliesFor)
            if let c = tableView.cellForRow(at: indexPath) as? LoadMoreTableViewCell {
                c.isUpdating = true
                self.tableView.deselectRow(at: indexPath, animated: true)
                loadDiscussions(idsToLoad, success: 
                    {
                        [weak self] in
                        UIThread.performUI {
                            //TODO: Change to animated reload
                            self?.reloadTableData()
                            c.isUpdating = false
                        }
                    })
            }

        }
        
        if cellsInfo[(indexPath as NSIndexPath).row].loadDiscussions != nil {
            let idsToLoad = getNextDiscussionIdsToLoad()
            if let c = tableView.cellForRow(at: indexPath) as? LoadMoreTableViewCell {
                c.isUpdating = true
                self.tableView.deselectRow(at: indexPath, animated: true)
                loadDiscussions(idsToLoad, success: 
                    {
                        [weak self] in
                        UIThread.performUI {
                            //TODO: Change to animated reload
                            self?.reloadTableData()
                            c.isUpdating = false
                        }
                    })
            }
        }
    }
}

extension DiscussionsViewController : UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellsInfo.count
    }
    
    @objc(tableView:willDisplayCell:forRowAtIndexPath:) func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        print("will display cell for \((indexPath as NSIndexPath).row)")
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        print("cell for row \((indexPath as NSIndexPath).row)")
                
        if let comment = cellsInfo[(indexPath as NSIndexPath).row].comment {
            
//            if !TagDetectionUtil.isWebViewSupportNeeded(comment.text) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "DiscussionTableViewCell", for: indexPath) as! DiscussionTableViewCell

                cell.initWithComment(comment, separatorType: cellsInfo[(indexPath as NSIndexPath).row].separatorType) 
                
                return cell
//            } else {
//                let cell = tableView.dequeueReusableCellWithIdentifier("DiscussionWebTableViewCell", forIndexPath: indexPath) as! DiscussionWebTableViewCell
//                
//                if let user = userInfos[comment.userId] {
//                    if let h = webViewHeightForDiscussionId[comment.id]  {
//                        cell.webContainerViewHeight.constant = h
//                    } else {
//
//                        cell.heightUpdateBlock = {
//                            [weak self] 
//                            height, webViewHeight in
//                            self?.webViewHeightForDiscussionId[comment.id] = webViewHeight
//                            print("height update block for \(indexPath.row) with height \(height)")
//                            dispatch_async(dispatch_get_main_queue(), {
//                                [weak self] in
//                                if self?.estimatedHeightForDiscussionId[comment.id] < height {
//                                    self?.tableView.beginUpdates()
//                                    self?.estimatedHeightForDiscussionId[comment.id] = height
//                                    self?.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
//                                    self?.tableView.endUpdates()
//                                }
//                            })
//                        }
//                    }
//                    cell.initWithComment(comment, user: user, separatorType: cellsInfo[indexPath.row].separatorType) 
//                } 
//                return cell
//
//            }
        } 
        
        if let loadRepliesFor = cellsInfo[(indexPath as NSIndexPath).row].loadRepliesFor {
            print("load replies cell")
            let cell = tableView.dequeueReusableCell(withIdentifier: "LoadMoreTableViewCell", for: indexPath) as! LoadMoreTableViewCell
            cell.showMoreLabel.text = "\(NSLocalizedString("ShowMoreReplies", comment: "")) (\(replies.leftToLoad(loadRepliesFor)))"
            return cell
        }
        
        if cellsInfo[(indexPath as NSIndexPath).row].loadDiscussions != nil {
            print("load discussions cell")
            let cell = tableView.dequeueReusableCell(withIdentifier: "LoadMoreTableViewCell", for: indexPath) as! LoadMoreTableViewCell
            cell.showMoreLabel.text = "\(NSLocalizedString("ShowMoreDiscussions", comment: "")) (\(discussionIds.leftToLoad))"
            return cell
        }
        
        return UITableViewCell()
    }
}

extension DiscussionsViewController : WriteCommentDelegate {
    func didWriteComment(_ comment: Comment) {
        print(comment.parentId ?? "")
        if let parentId = comment.parentId {
            //insert row in an existing section
            if let section = discussions.index(where: {$0.id == parentId}) {
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
            discussionIds.all.insert(comment.id, at: 0)
            discussionIds.loaded.insert(comment.id, at: 0)
            discussions.insert(comment, at: 0)
//            tableView.beginUpdates()
            reloadTableData()
//            let index = NSIndexSet(index: 0)
//            tableView.insertSections(index, withRowAnimation: .Automatic)
//            tableView.endUpdates()
        }
    }
}

extension DiscussionsViewController : DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
        switch emptyDatasetState {
        case .empty:
            return Images.noCommentsWhite.size200x200
        case .error:
            return Images.noWifiImage.white
        case .none:
            return Images.noCommentsWhite.size200x200
        }
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        var text : String = ""
        switch emptyDatasetState {
        case .empty:
            text = NSLocalizedString("NoDiscussionsTitle", comment: "")
            break
        case .error:
            text = NSLocalizedString("ConnectionErrorTitle", comment: "")
            break
        case .none:
            text = ""
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
            text = NSLocalizedString("NoDiscussionsDescription", comment: "")
            break
        case .error:
            text = NSLocalizedString("ConnectionErrorPullToRefresh", comment: "")
            break
        case .none: 
            text = NSLocalizedString("RefreshingDiscussions", comment: "")
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
    
    func verticalOffset(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
        //        print("offset -> \((self.navigationController?.navigationBar.bounds.height) ?? 0 + UIApplication.sharedApplication().statusBarFrame.height)")
        return 0
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView!) -> Bool {
        return true
    }
}

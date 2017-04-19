//
//  RateAppViewController.swift
//  Stepic
//
//  Created by Alexander Karpov on 07.04.17.
//  Copyright © 2017 Alex Karpov. All rights reserved.
//

import UIKit
import MessageUI
import Presentr
import FLKAutoLayout

class RateAppViewController: UIViewController {

    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var laterButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    
    @IBOutlet weak var centerViewWidth: NSLayoutConstraint!
    
    @IBOutlet var starImageViews: [UIImageView]!
    
    @IBOutlet weak var buttonsContainerHeight: NSLayoutConstraint!
    
    var lessonProgress : String? = nil
    
    var defaultAnalyticsParams : [String: Any] {
        if let progress = lessonProgress {
            return ["lesson_progress": progress]
        } else {
            return [:]
        }
    }
    
    enum AfterRateActionType {
        case appStore, email
    }
    
    var buttonState : AfterRateActionType? = nil {
        didSet {
            guard buttonState != nil else {
                return
            }
            
            switch buttonState! {
            case .appStore:
                rightButton.titleLabel?.text = NSLocalizedString("AppStore", comment: "")
                rightButton.setTitle(NSLocalizedString("AppStore", comment: ""), for: .normal)
                rightButton.setTitleColor(UIColor.stepicGreenColor(), for: .normal)
                break
            case .email:
                rightButton.titleLabel?.text = NSLocalizedString("Email", comment: "")
                rightButton.setTitle(NSLocalizedString("Email", comment: ""), for: .normal)
                rightButton.setTitleColor(UIColor.errorRedColor(), for: .normal)
                break
            }
        }
    }
    
    var bottomLabelWidth : NSLayoutConstraint? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        centerViewWidth.constant = 0.5
        buttonsContainerHeight.constant = 0

        laterButton.setTitle(NSLocalizedString("Later", comment: ""), for: .normal)
        topLabel.text = NSLocalizedString("HowWouldYouRateStepik", comment: "")
        bottomLabel.text = ""
        
        bottomLabelWidth = bottomLabel.constrainWidth("<=\(UIScreen.main.bounds.width - 48)").first as? NSLayoutConstraint
        
        for star in starImageViews {
            print(star.tag)
            let tapG = UITapGestureRecognizer(target: self, action: #selector(RateAppViewController.didTap(_:)))
            star.isUserInteractionEnabled = true
            star.image = Images.star.empty
            star.highlightedImage = Images.star.filled
            star.addGestureRecognizer(tapG)
        }
        
        // Do any additional setup after loading the view.
    }

    func didTap(_ recognizer: UITapGestureRecognizer) {
        guard let tappedIndex = recognizer.view?.tag else {
            return
        }
        
        for star in starImageViews {
            if star.tag <= tappedIndex {
                star.isHighlighted = true
            }
            star.isUserInteractionEnabled = false
        }
        
        topLabel.text = NSLocalizedString("ThankYou", comment: "")
        let rating = tappedIndex + 1
        
        var params = defaultAnalyticsParams
        params["rating"] = rating
        AnalyticsReporter.reportEvent(AnalyticsEvents.Rate.rated, parameters: params)
        
        if rating < 4 {
            buttonState = .email
            bottomLabel.text = NSLocalizedString("PleaseLeaveFeedbackEmail", comment: "")
        } else {
            buttonState = .appStore
            bottomLabel.text = NSLocalizedString("PleaseLeaveFeedbackAppstore", comment: "")
        }
        
        buttonsContainerHeight.constant = 48
        
        self.view.frame = CGRect(origin: self.view.frame.origin, size: CGSize(width: self.view.frame.width, height: self.view.frame.height + 48.0))
        UIView.animate(withDuration: 0.2, animations: {
            [weak self] in
            self?.view.layoutIfNeeded()
        })
    }
    
    func showEmail() {
        
        AnalyticsReporter.reportEvent(AnalyticsEvents.Rate.Negative.email, parameters: defaultAnalyticsParams)
        
        if !MFMailComposeViewController.canSendMail() {
            //TODO: Present alert that mail is not supported on this device
            self.dismiss(animated: true, completion: nil)
            return
        }

        
        let composeVC = MFMailComposeViewController()
        composeVC.mailComposeDelegate = self
        
        composeVC.setToRecipients(["support@stepik.org"])
        composeVC.setSubject("Feedback about the Stepik iOS App")
        composeVC.setMessageBody("", isHTML: false)
        self.customPresentViewController(mailPresenter, viewController: composeVC, animated: true, completion: nil)

    }
    
    func showAppStore() {
        AnalyticsReporter.reportEvent(AnalyticsEvents.Rate.Positive.appstore, parameters: defaultAnalyticsParams)
        guard let appStoreURL = URL(string: "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=1064581926&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software&action=write-review") else {
            return
        }
        UIApplication.shared.openURL(appStoreURL)
        self.dismiss(animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func laterButtonPressed(_ sender: UIButton) {
        RoutingManager.rate.pressedShowLater()
        self.dismiss(animated: true, completion: nil)
        
        guard buttonState != nil else {
            return
        }
        switch buttonState! {
        case .appStore:
            AnalyticsReporter.reportEvent(AnalyticsEvents.Rate.Positive.later, parameters: defaultAnalyticsParams)
            break
        case .email:
            AnalyticsReporter.reportEvent(AnalyticsEvents.Rate.Negative.later, parameters: defaultAnalyticsParams)
            break
        }
    }

    @IBAction func rightButtonPressed(_ sender: UIButton) {
        guard buttonState != nil else {
            return
        }
        RoutingManager.rate.neverShow()
        switch buttonState! {
        case .appStore:
            showAppStore()
            break
        case .email:
            showEmail()
            break
        }
    }
    
    let mailPresenter : Presentr = {
        let width = ModalSize.sideMargin(value: 0)
        let height = ModalSize.sideMargin(value: 0)
        let center = ModalCenterPosition.center
        let customType = PresentationType.custom(width: width, height: height, center: center)
        
        let presenter = Presentr(presentationType: customType)
        presenter.roundCorners = false
        return presenter
    }()
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        bottomLabelWidth?.constant = UIScreen.main.bounds.height - 48
    }

}

extension RateAppViewController : MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult, error: Error?) {
        switch result {
        case .cancelled, .failed, .saved:
            AnalyticsReporter.reportEvent(AnalyticsEvents.Rate.Negative.Email.cancelled, parameters: defaultAnalyticsParams)
        case .sent:
            AnalyticsReporter.reportEvent(AnalyticsEvents.Rate.Negative.Email.success, parameters: defaultAnalyticsParams)
        }
        
        controller.dismiss(animated: true, completion: {
            [weak self] in
            self?.dismiss(animated: true, completion: nil)
        })
    }
}

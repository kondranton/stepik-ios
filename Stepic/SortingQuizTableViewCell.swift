//
//  SortingQuizTableViewCell.swift
//  Stepic
//
//  Created by Alexander Karpov on 27.01.16.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import UIKit

class SortingQuizTableViewCell: UITableViewCell {

    @IBOutlet weak var textContainerView: UIView!

    var optionLabel: StepikLabel?
    var optionWebView: FullHeightWebView?

    var webViewHelper: CellWebViewHelper?

    override func awakeFromNib() {
        super.awakeFromNib()
        self.selectionStyle = UITableViewCellSelectionStyle.none

        contentView.backgroundColor = UIColor.clear
    }

    func initLabel() {
        guard optionLabel == nil else { return }
        optionLabel = StepikLabel()
        guard let optionLabel = optionLabel else { return }

        optionLabel.numberOfLines = 0
        optionLabel.font = UIFont(name: "ArialMT", size: 16)
        optionLabel.lineBreakMode = NSLineBreakMode.byTruncatingTail
        optionLabel.baselineAdjustment = UIBaselineAdjustment.alignBaselines
        optionLabel.textAlignment = NSTextAlignment.natural
        optionLabel.backgroundColor = UIColor.clear
        textContainerView.addSubview(optionLabel)
        optionLabel.alignTop("0", leading: "8", bottom: "0", trailing: "-8", toView: textContainerView)
        optionLabel.isHidden = true
    }

    func initWebView() {
        guard optionWebView == nil else { return }
        optionWebView = FullHeightWebView()
        guard let optionWebView = optionWebView else { return }
        textContainerView.addSubview(optionWebView)
        optionWebView.align(toView: textContainerView)
        webViewHelper = CellWebViewHelper(webView: optionWebView)
        optionWebView.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        optionWebView?.isHidden = true
        optionLabel?.isHidden = true
    }

    var sortable: Bool = true

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    class func getHeightForText(text: String, width: CGFloat, sortable: Bool) -> CGFloat {
        return max(27, StepikLabel.heightForLabelWithText(text, lines: 0, fontName: "ArialMT", fontSize: 16, width: width - (sortable  ? 60 : 16))) + 17
    }
}

extension SortingQuizTableViewCell {

    //All optimization logics is now encapsulated here
    func setHTMLText(_ text: String, width: CGFloat, finishedBlock: @escaping (CGFloat) -> Void) {
        if TagDetectionUtil.isWebViewSupportNeeded(text) {
            initWebView()
            optionWebView?.isHidden = false
            webViewHelper?.mathJaxFinishedBlock = {
                [weak self] in
                self?.layoutIfNeeded()
                if let webView = self?.optionWebView {
                    webView.invalidateIntrinsicContentSize()
                    finishedBlock(17 + webView.contentHeight)
                }
            }
            webViewHelper?.setTextWithTeX(text)
        } else {
            initLabel()
            optionLabel?.setTextWithHTMLString(text)
            optionLabel?.isHidden = false
            let height = SortingQuizTableViewCell.getHeightForText(text: text, width: width, sortable: self.sortable)
            finishedBlock(height)
        }
    }
}

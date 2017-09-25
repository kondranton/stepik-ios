//
//  LaTeXTextView.swift
//  Stepic
//
//  Created by Ostrenkiy on 23.09.17.
//  Copyright © 2017 Alex Karpov. All rights reserved.
//

import Foundation
import FLKAutoLayout

class LaTeXTextView: NibInitializableView {

    enum State {
        case plain, web
    }

    var state: State = .plain {
        didSet(oldState) {
            switch oldState {
            case .plain:
                label.removeFromSuperview()
                label.removeConstraints(label.constraints)
            case .web:
                webView.removeFromSuperview()
                webView.removeConstraints(webView.constraints)
            }

            switch state {
            case .plain:
                view.addSubview(label)
                label.alignTop("0", leading: "8", bottom: "0", trailing: "-8", toView: self.view)
                view.layoutSubviews()
                break
            case .web:
                view.addSubview(webView)
                webView.align(toView: self.view)
                view.layoutSubviews()
                break
            }
        }
    }

    let webView: FullHeightWebView = FullHeightWebView()
    let label: StepikLabel = StepikLabel()
    var webViewHelper: CellWebViewHelper!
    var updateHeightBlock: (() -> Void)?

    var text: String? {
        didSet {
            let unwrappedText = text ?? ""
            if TagDetectionUtil.isWebViewSupportNeeded(unwrappedText) {
                setWeb(text: unwrappedText)
            } else {
                setPlain(text: unwrappedText)
            }
        }
    }

    private func setPlain(text: String) {
        state = .plain
        label.text = text
        print("Added label LaTeXTextView subview with text -> \(text)")
        self.view.invalidateIntrinsicContentSize()
    }

    private func setWeb(text: String) {
        state = .web
        webViewHelper?.mathJaxFinishedBlock = {
            [weak self] in
            if let webView = self?.webView {
                webView.constrainHeight("\(webView.contentHeight)")
                self?.updateHeightBlock?()
            }
        }
        webViewHelper?.setTextWithTeX(text)
    }

    override var nibName: String {
        return "LaTeXTextView"
    }

    override func setupSubviews() {
        webViewHelper = CellWebViewHelper(webView: webView)

        label.numberOfLines = 0
        label.font = UIFont(name: "ArialMT", size: 16)
        label.lineBreakMode = NSLineBreakMode.byTruncatingTail
        label.baselineAdjustment = UIBaselineAdjustment.alignBaselines
        label.textAlignment = NSTextAlignment.natural
        label.backgroundColor = UIColor.clear
    }

    override var intrinsicContentSize: CGSize {
        switch state {
        case .plain:
            print("intrinsic content size for label with text: \(label.text) \n size -> \(label.intrinsicContentSize) screen width -> \(UIScreen.main.bounds.width)")
            return label.intrinsicContentSize
        case .web:
            return webView.intrinsicContentSize
        }
    }
}

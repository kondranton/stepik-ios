//
//  ChoiceQuizTableViewCell.swift
//  Stepic
//
//  Created by Alexander Karpov on 20.01.16.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import UIKit
import BEMCheckBox

class ChoiceQuizTableViewCell: UITableViewCell {

    @IBOutlet weak var checkBox: BEMCheckBox!
    @IBOutlet weak var choiceWebView: UIWebView!
    @IBOutlet weak var webViewHeight: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        choiceWebView.scrollView.scrollEnabled = false
        checkBox.onAnimationType = .Fill
        checkBox.animationDuration = 0.3
        contentView.backgroundColor = UIColor.clearColor()
        // Initialization code
    }

    private func getContentHeight(webView : UIWebView) -> Int {
        return Int(webView.stringByEvaluatingJavaScriptFromString("document.body.scrollHeight;") ?? "0") ?? 0
    }
    
    //Method sets text and returns the method which returns current cell height according to the 
    func setTextWithTeX(text: String) -> (Void->Int) {
        let scriptsString = "\(Scripts.localTexScript)"
        let html = HTMLBuilder.sharedBuilder.buildHTMLStringWith(head: scriptsString, body: text, width: Int(UIScreen.mainScreen().bounds.width) - 52)
        choiceWebView.loadHTMLString(html, baseURL: NSURL(fileURLWithPath: NSBundle.mainBundle().bundlePath))
        
        return {
            [unowned self]
            Void in
            let h = self.getContentHeight(self.choiceWebView)
//            self.webViewHeight.constant = CGFloat(h)
            return h + 17
        }
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    deinit{
        print("did deinit cell")
    }
    
}

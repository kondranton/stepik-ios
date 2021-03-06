//
//  LabelExtension.swift
//  Stepic
//
//  Created by Alexander Karpov on 01.10.15.
//  Copyright © 2015 Alex Karpov. All rights reserved.
//

import UIKit

extension UILabel {
    func setTextWithHTMLString(_ htmlText: String) {
        guard let encodedData = htmlText.data(using: .unicode) else {
            self.text = ""
            return
        }

        guard let attributedDescription = try? NSMutableAttributedString(data: encodedData, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType], documentAttributes: nil) else {
            self.text = ""
            return
        }

        self.text = attributedDescription.string
    }

    class func heightForLabelWithText(_ text: String, lines: Int, fontName: String, fontSize: CGFloat, width: CGFloat, html: Bool = false, alignment: NSTextAlignment = NSTextAlignment.natural) -> CGFloat {

        let label = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude))

        label.numberOfLines = lines

        if html {
            label.setTextWithHTMLString(text)
        } else {
            label.text = text
        }

        label.font = UIFont(name: fontName, size: fontSize)
        label.lineBreakMode = NSLineBreakMode.byTruncatingTail
        label.baselineAdjustment = UIBaselineAdjustment.alignBaselines
        label.textAlignment = alignment
        label.sizeToFit()

        return label.bounds.height
    }

    class func heightForLabelWithText(_ text: String, lines: Int, standardFontOfSize size: CGFloat, width: CGFloat, html: Bool = false, alignment: NSTextAlignment = NSTextAlignment.natural) -> CGFloat {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude))

        label.numberOfLines = lines

        if html {
            label.setTextWithHTMLString(text)
        } else {
            label.text = text
        }

        label.font = UIFont.systemFont(ofSize: size)
        label.lineBreakMode = NSLineBreakMode.byTruncatingTail
        label.baselineAdjustment = UIBaselineAdjustment.alignBaselines
        label.textAlignment = alignment
        label.sizeToFit()

//        print(label.bounds.height)
        return label.bounds.height
    }
}

extension CGSize {
    func sizeByDelta(dw: CGFloat, dh: CGFloat) -> CGSize {
        return CGSize(width: self.width + dw, height: self.height + dh)
    }
}

class WiderLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        return super.intrinsicContentSize.sizeByDelta(dw: 10, dh: 0)
    }
}

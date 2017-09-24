//
//  ChoiceQuizTableViewCell.swift
//  Stepic
//
//  Created by Alexander Karpov on 06.06.16.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import UIKit
import BEMCheckBox
import FLKAutoLayout

class ChoiceQuizTableViewCell: UITableViewCell {

    @IBOutlet weak var checkBox: BEMCheckBox!
    @IBOutlet weak var textView: LaTeXTextView!

    override func awakeFromNib() {
        super.awakeFromNib()
        checkBox.onAnimationType = .fill
        checkBox.animationDuration = 0.3
        contentView.backgroundColor = UIColor.clear
        checkBox.onTintColor = UIColor.mainDark
        checkBox.onFillColor = UIColor.mainDark
        checkBox.tintColor = UIColor.mainDark
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    class func getHeightForText(text: String, width: CGFloat) -> CGFloat {
        return max(27, StepikLabel.heightForLabelWithText(text, lines: 0, fontName: "ArialMT", fontSize: 16, width: width - 68)) + 17
    }
}

extension ChoiceQuizTableViewCell {

    //All optimization logics is now encapsulated here
    func setHTMLText(_ text: String, width: CGFloat, finishedBlock: @escaping () -> Void) {
        textView.updateHeightBlock = finishedBlock
        textView.text = text
    }
}

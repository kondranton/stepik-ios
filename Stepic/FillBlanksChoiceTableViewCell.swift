//
//  FillBlanksChoiceTableViewCell.swift
//  Stepic
//
//  Created by Alexander Karpov on 11.02.17.
//  Copyright © 2017 Alex Karpov. All rights reserved.
//

import UIKit

class FillBlanksChoiceTableViewCell: UITableViewCell {
    
    @IBOutlet weak var optionLabel: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    
    let selectAnswerString: String = NSLocalizedString("FillBlanksSelectAnswerString", comment: "")
    let selectButtonString: String = NSLocalizedString("FillBlanksSelectButtonString", comment: "")
    var selectedAction : ((Void) -> Void)? = nil
    
    @IBAction func selectPressed(_ sender: UIButton) {
        selectedAction?()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        contentView.backgroundColor = UIColor.clear
        backgroundColor = UIColor.clear
        
        optionLabel.text = selectAnswerString
        selectButton.setTitle(selectButtonString, for: .normal)
        
        optionLabel.numberOfLines = 0
        optionLabel.font = UIFont(name: "ArialMT", size: 16)
        optionLabel.lineBreakMode = NSLineBreakMode.byTruncatingTail
        optionLabel.baselineAdjustment = UIBaselineAdjustment.alignBaselines
        optionLabel.textAlignment = NSTextAlignment.natural
        optionLabel.backgroundColor = UIColor.clear
        optionLabel.textColor = UIColor.gray
    }

    func setOption(text: String?) {
        if text != nil {
            optionLabel.text = text
            optionLabel.textColor = UIColor.black
        } else {
            optionLabel.text = selectAnswerString
            optionLabel.textColor = UIColor.gray
        }
    }
    
    class func getHeight(text: String, width w: CGFloat) -> CGFloat {
        let buttonWidth : CGFloat = 62
        let buttonToLabelDistance : CGFloat = 8
        return max(27, UILabel.heightForLabelWithText(text, lines: 0, fontName: "ArialMT", fontSize: 16, width: w -  24 - buttonWidth - buttonToLabelDistance)) + 17
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        
        // Configure the view for the selected state
    }
    
}

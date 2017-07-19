//
//  CodeSuggestionTableViewCell.swift
//  Stepic
//
//  Created by Ostrenkiy on 08.07.17.
//  Copyright © 2017 Alex Karpov. All rights reserved.
//

import UIKit

class CodeSuggestionTableViewCell: UITableViewCell {

    @IBOutlet weak var suggestionLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    func setSuggestion(_ suggestion: String, prefixLength: Int) {
        let boldCourier = UIFont(name: "Courier-Bold", size: 11)!
        let regularCourier = UIFont(name: "Courier", size: 11)!
        let attributedSuggestion = NSMutableAttributedString(string: suggestion, attributes: [NSFontAttributeName: regularCourier])
        attributedSuggestion.addAttributes([NSFontAttributeName: boldCourier], range: NSMakeRange(0, prefixLength))
        suggestionLabel.attributedText = attributedSuggestion
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}

//
//  SectionTableViewCell.swift
//  Stepic
//
//  Created by Alexander Karpov on 08.10.15.
//  Copyright © 2015 Alex Karpov. All rights reserved.
//

import UIKit
import DownloadButton

class SectionTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var datesLabel: UILabel!
    @IBOutlet weak var progressView: UIView!
        
    @IBOutlet weak var downloadButton: PKDownloadButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        progressView.setRoundedBounds(width: 0)
        UICustomizer.sharedCustomizer.setCustomDownloadButton(downloadButton)
        // Initialization code
    }

    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    fileprivate class func getTextFromSection(_ section: Section) -> String {
        var text = ""
        if section.beginDate != nil { 
            text = "\n\(NSLocalizedString("BeginDate", comment: "")): \(section.beginDate!.getStepicFormatString())"
        }
        if section.softDeadline != nil {
            text = "\(text)\n\(NSLocalizedString("SoftDeadline", comment: "")): \(section.softDeadline!.getStepicFormatString())"
        }
        if section.hardDeadline != nil {
            text = "\(text)\n\(NSLocalizedString("HardDeadline", comment: "")): \(section.hardDeadline!.getStepicFormatString())"
        }
        return text
    }
    
    class func heightForCellInSection(_ section: Section) -> CGFloat {
        let titleText = "\(section.position). \(section.title)"
        let datesText = SectionTableViewCell.getTextFromSection(section)
        return 32 + UILabel.heightForLabelWithText(titleText, lines: 0, standardFontOfSize: 14, width: UIScreen.main.bounds.width - 117) + (datesText == "" ? 0 : 8 + UILabel.heightForLabelWithText(datesText, lines: 0, standardFontOfSize: 14, width: UIScreen.main.bounds.width - 117))
    }
    
    func updateDownloadButton(_ section: Section) {
        if section.isCached { 
            self.downloadButton.state = .downloaded
        } else if section.isDownloading { 
            
//            print("update download button while downloading")
            self.downloadButton.state = .downloading
            self.downloadButton.stopDownloadButton?.progress = CGFloat(section.goodProgress)
        
            
            section.storeProgress = {
                prog in
                UIThread.performUI({self.downloadButton.stopDownloadButton?.progress = CGFloat(prog)})
            }
            
            section.storeCompletion = {
                if section.isCached {
                    UIThread.performUI({self.downloadButton.state = .downloaded})
                } else {
                    UIThread.performUI({self.downloadButton.state = .startDownload})
                }
            }
            
        } else {
            self.downloadButton.state = .startDownload
        }
    }
    
    func initWithSection(_ section: Section, delegate : PKDownloadButtonDelegate) {
        titleLabel.text = "\(section.position). \(section.title)"
        
        datesLabel.text = SectionTableViewCell.getTextFromSection(section)
        
        progressView.backgroundColor = UIColor.gray
        if let passed = section.progress?.isPassed {
            if passed {
                progressView.backgroundColor = UIColor.stepicGreenColor()
            }
        }
                
        updateDownloadButton(section)
        
        downloadButton.tag = section.position - 1
        downloadButton.delegate = delegate
        
        if (!section.isActive && section.testSectionAction == nil) || section.progressId == nil {
            titleLabel.isEnabled = false
            datesLabel.isEnabled = false
            downloadButton.isHidden = true
        } else {
            titleLabel.isEnabled = true
            datesLabel.isEnabled = true
            downloadButton.isHidden = false
        }
    }
    
}

//
//  VideoDownloadDelegate.swift
//  Stepic
//
//  Created by Alexander Karpov on 16.11.15.
//  Copyright © 2015 Alex Karpov. All rights reserved.
//

import Foundation
import DownloadButton

protocol VideoDownloadDelegate: class {
    func didDownload(_ video: Video, cancelled: Bool)
    func didGetError(_ video: Video)
}

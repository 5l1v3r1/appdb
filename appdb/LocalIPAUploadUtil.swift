//
//  LocalIPAUploadUtil.swift
//  appdb
//
//  Created by ned on 04/05/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import Alamofire

class LocalIPAUploadUtil {
    
    fileprivate var request: Alamofire.UploadRequest?
    
    var isPaused: Bool {
        return paused
    }
    
    var lastCachedFraction: Float = 0.0
    var lastCachedProgress: String = "Waiting...".localized()
    
    fileprivate var paused: Bool = false
    
    var onPause: (() -> ())?
    var onProgress: ((Float, String) -> ())?
    var onCompletion: (() -> ())?
    
    init(_ request: Alamofire.UploadRequest) {
        self.request = request
        
        self.request?.uploadProgress { p in
            let readString = Global.humanReadableSize(bytes: p.completedUnitCount)
            let totalString = Global.humanReadableSize(bytes: p.totalUnitCount)
            let percentage = Int(p.fractionCompleted * 100)
            self.lastCachedProgress = "Uploading %@ of %@ (%@%)".localizedFormat(readString, totalString, percentage)
            self.lastCachedFraction = Float(p.fractionCompleted)
            self.onProgress?(self.lastCachedFraction, self.lastCachedProgress)
        }
        
        self.request?.responseJSON { _ in
            self.request = nil
            self.onCompletion?()
        }
    }
    
    func pause() {
        guard let request = request else { return }
        guard !paused else { return }
        request.suspend()
        paused = true
        onPause?()
    }
    
    func resume() {
        guard let request = request else { return }
        request.resume()
        paused = false
    }
    
    func stop() {
        guard let request = request else { return }
        request.cancel()
        paused = false
    }
    
}

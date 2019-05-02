//
//  RecordButton.swift
//
//  Copyright (c) 2018-present patrick piemonte (http://patrickpiemonte.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit
import Foundation
import RPCircularProgress

/// quick hacky progress "button"
public class RecordButton: UIView {
    
    internal lazy var _recordIndicatorProgressBackground: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    internal lazy var _recordIndicatorProgress: RPCircularProgress = {
        let indicatorProgress = RPCircularProgress()
        indicatorProgress.roundedCorners = false
        indicatorProgress.thicknessRatio = 1
        indicatorProgress.trackTintColor = UIColor.white
        indicatorProgress.progressTintColor = UIColor.red
        indicatorProgress.isUserInteractionEnabled = false
        return indicatorProgress
    }()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = true
        self.backgroundColor = .clear
        
        self._recordIndicatorProgressBackground.isUserInteractionEnabled = false
        self._recordIndicatorProgressBackground.frame = self.bounds.insetBy(dx: 10.0, dy: 10.0)
        self._recordIndicatorProgressBackground.layer.cornerRadius = self._recordIndicatorProgressBackground.frame.size.height * 0.5
        self._recordIndicatorProgressBackground.layer.borderWidth = 2.0
        self._recordIndicatorProgressBackground.layer.borderColor = UIColor.white.cgColor
        
        self._recordIndicatorProgressBackground.center = self.center
        self.addSubview(self._recordIndicatorProgressBackground)
        
        self._recordIndicatorProgress.frame = self._recordIndicatorProgressBackground.bounds
        self._recordIndicatorProgress.center = self.center
        self.addSubview(self._recordIndicatorProgress)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }
    
}

extension RecordButton {
    
    public func startRecordingAnimation() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            self._recordIndicatorProgress.transform = CGAffineTransform(scaleX: 1.65, y: 1.65)
        }) { (completed: Bool) in
        }
    }
    
    public func stopRecordingAnimation() {
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut, animations: {
            self._recordIndicatorProgress.transform = .identity
        }) { (completed: Bool) in
        }
    }
    
    public func updateProgress(progress: Float, animated: Bool) {
        self._recordIndicatorProgress.updateProgress(CGFloat(progress), animated: animated, completion: nil)
    }
    
    public func reset() {
        self._recordIndicatorProgress.transform = .identity
        self._recordIndicatorProgress.updateProgress(0)
    }
    
}

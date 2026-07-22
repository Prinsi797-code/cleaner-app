//
//  CircularProgressView.swift
//  Cleanify
//
//  Created by Aniket Dhandhukiya on 14/07/26.
//

import UIKit

class CircularProgressView: UIView {
    
    var strokeWidth: CGFloat = 8 {
        didSet {
            trackLayer.lineWidth = strokeWidth
            progressLayer.lineWidth = strokeWidth
            setNeedsLayout()
        }
    }
    
    var trackColor: UIColor = .systemGray5 {
        didSet {
            trackLayer.strokeColor = trackColor.cgColor
        }
    }
    
    var progressColor: [UIColor] = [.systemBlue] {
        didSet {
            updateGradientColors()
        }
    }
    
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let gradientLayer = CAGradientLayer()
    
    private var progress: Double = 0.0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // Setup track layer
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = trackColor.cgColor
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)
        
        // Setup progress layer (used as a mask for the gradient)
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.black.cgColor // Color doesn't matter for mask, only opacity
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0.0
        
        // Setup gradient layer
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        updateGradientColors()
        layer.addSublayer(gradientLayer)
        
        // Apply progress layer mask to the gradient
        gradientLayer.mask = progressLayer
    }
    
    private func updateGradientColors() {
        gradientLayer.colors = progressColor.map { $0.cgColor }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Center the layers
        trackLayer.frame = bounds
        gradientLayer.frame = bounds
        progressLayer.frame = bounds
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - strokeWidth) / 2
        
        // Angle starts at top (-90 degrees / -pi/2)
        let startAngle = -CGFloat.pi / 2
        let endAngle = 3 * CGFloat.pi / 2
        
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }
    
    func setProgress(_ progress: Double, animated: Bool, duration: TimeInterval = 0.4) {
        let clamped = max(0.0, min(1.0, progress))
        self.progress = clamped
        
        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.strokeEnd
            animation.toValue = clamped
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            progressLayer.add(animation, forKey: "progressAnim")
            progressLayer.strokeEnd = clamped
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer.removeAnimation(forKey: "progressAnim")
            progressLayer.strokeEnd = clamped
            CATransaction.commit()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            trackLayer.strokeColor = trackColor.cgColor
            updateGradientColors()
        }
    }
}


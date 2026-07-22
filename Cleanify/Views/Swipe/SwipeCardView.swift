//
//  SwipeCardView.swift
//  Cleanify
//

import UIKit
import Photos
import AVFoundation

protocol SwipeCardDelegate: AnyObject {
    func cardDidSwipeLeft(_ card: SwipeCardView)
    func cardDidSwipeRight(_ card: SwipeCardView)
    func cardDidSwipeDown(_ card: SwipeCardView)
}

class SwipeCardView: UIView {
    
    weak var delegate: SwipeCardDelegate?
    var asset: PHAsset?
    
    private let imageView = UIImageView()
    private let trashOverlay = UIView()
    private let keepOverlay = UIView()
    private let trashIcon = UIImageView(image: UIImage(systemName: "trash.fill"))
    private let keepIcon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let durationLabel = UILabel()
    
    private let videoContainerView = UIView()
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var shouldPlay = false
    private var loopObserver: NSObjectProtocol?
    
    private var panGesture: UIPanGestureRecognizer!
    private var originalPoint: CGPoint = .zero
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 24
        layer.masksToBounds = false
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 24
        addSubview(imageView)
        
        videoContainerView.translatesAutoresizingMaskIntoConstraints = false
        videoContainerView.layer.cornerRadius = 24
        videoContainerView.clipsToBounds = true
        addSubview(videoContainerView)
        
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        durationLabel.textColor = .white
        durationLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        durationLabel.layer.cornerRadius = 6
        durationLabel.clipsToBounds = true
        durationLabel.textAlignment = .center
        durationLabel.isHidden = true
        addSubview(durationLabel)
        
        // Trash Overlay (Red)
        trashOverlay.translatesAutoresizingMaskIntoConstraints = false
        trashOverlay.backgroundColor = UIColor.systemRed.withAlphaComponent(0.6)
        trashOverlay.alpha = 0
        trashOverlay.layer.cornerRadius = 24
        addSubview(trashOverlay)
        
        trashIcon.translatesAutoresizingMaskIntoConstraints = false
        trashIcon.tintColor = .white
        trashOverlay.addSubview(trashIcon)
        
        // Keep Overlay (Green)
        keepOverlay.translatesAutoresizingMaskIntoConstraints = false
        keepOverlay.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.6)
        keepOverlay.alpha = 0
        keepOverlay.layer.cornerRadius = 24
        addSubview(keepOverlay)
        
        keepIcon.translatesAutoresizingMaskIntoConstraints = false
        keepIcon.tintColor = .white
        keepOverlay.addSubview(keepIcon)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            videoContainerView.topAnchor.constraint(equalTo: topAnchor),
            videoContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            videoContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            durationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            durationLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            durationLabel.heightAnchor.constraint(equalToConstant: 24),
            
            trashOverlay.topAnchor.constraint(equalTo: topAnchor),
            trashOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            trashOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            trashOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            trashIcon.centerXAnchor.constraint(equalTo: trashOverlay.centerXAnchor),
            trashIcon.centerYAnchor.constraint(equalTo: trashOverlay.centerYAnchor),
            trashIcon.widthAnchor.constraint(equalToConstant: 80),
            trashIcon.heightAnchor.constraint(equalToConstant: 80),
            
            keepOverlay.topAnchor.constraint(equalTo: topAnchor),
            keepOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            keepOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            keepOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            keepIcon.centerXAnchor.constraint(equalTo: keepOverlay.centerXAnchor),
            keepIcon.centerYAnchor.constraint(equalTo: keepOverlay.centerYAnchor),
            keepIcon.widthAnchor.constraint(equalToConstant: 80),
            keepIcon.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        updateShadows()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateShadows()
        }
    }
    
    private func updateShadows() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.4 : 0.2
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
    }
    
    func configure(with asset: PHAsset, imageManager: PHCachingImageManager) {
        self.asset = asset
        cleanupPlayer()
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        
        let targetSize = CGSize(width: UIScreen.main.bounds.width * 1.5, height: UIScreen.main.bounds.height * 1.5)
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
        
        if asset.mediaType == .video {
            durationLabel.isHidden = false
            durationLabel.text = formatDuration(asset.duration)
            
            let videoOptions = PHVideoRequestOptions()
            videoOptions.isNetworkAccessAllowed = true
            videoOptions.deliveryMode = .automatic
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: videoOptions) { [weak self] playerItem, _ in
                guard let self = self, let item = playerItem else { return }
                DispatchQueue.main.async {
                    self.setupPlayer(with: item)
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func setupPlayer(with item: AVPlayerItem) {
        player = AVPlayer(playerItem: item)
        player?.isMuted = true // Muted by default to avoid abrupt noise
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = videoContainerView.bounds
        if let playerLayer = playerLayer {
            videoContainerView.layer.addSublayer(playerLayer)
        }
        
        if shouldPlay {
            player?.play()
        }
        
        loopObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = videoContainerView.bounds
    }
    
    func playVideo() {
        shouldPlay = true
        player?.play()
    }
    
    func pauseVideo() {
        shouldPlay = false
        player?.pause()
    }
    
    func cleanupPlayer() {
        shouldPlay = false
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil
        if let loopObserver = loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
            self.loopObserver = nil
        }
    }
    
    private func setupGesture() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: superview)
        
        switch gesture.state {
        case .began:
            originalPoint = center
        case .changed:
            // Check for explicit swipe down for Undo
            if translation.y > 100 && abs(translation.x) < 50 {
                // Visualize undo intent? Maybe fade out slightly
            }
            
            let rotationStrength = min(translation.x / 320, 1)
            let rotationAngle = (CGFloat.pi / 8) * rotationStrength
            
            let transform = CGAffineTransform(translationX: translation.x, y: translation.y)
                .rotated(by: rotationAngle)
            
            self.transform = transform
            
            let alpha = abs(translation.x) / 100
            if translation.x > 0 {
                keepOverlay.alpha = min(alpha, 1)
                trashOverlay.alpha = 0
            } else {
                trashOverlay.alpha = min(alpha, 1)
                keepOverlay.alpha = 0
            }
            
        case .ended, .cancelled:
            if translation.y > 150 && abs(translation.x) < 80 {
                resetCard()
                delegate?.cardDidSwipeDown(self)
            } else if translation.x > 120 {
                swipeRightAction()
            } else if translation.x < -120 {
                swipeLeftAction()
            } else {
                resetCard()
            }
        default:
            break
        }
    }
    
    func swipeLeftAction() {
        let finishPoint = CGPoint(x: -UIScreen.main.bounds.width, y: center.y)
        animateSwipe(to: finishPoint, rotation: -CGFloat.pi / 4) { [weak self] in
            guard let self = self else { return }
            self.delegate?.cardDidSwipeLeft(self)
        }
    }
    
    func swipeRightAction() {
        let finishPoint = CGPoint(x: UIScreen.main.bounds.width * 2, y: center.y)
        animateSwipe(to: finishPoint, rotation: CGFloat.pi / 4) { [weak self] in
            guard let self = self else { return }
            self.delegate?.cardDidSwipeRight(self)
        }
    }
    
    private func animateSwipe(to point: CGPoint, rotation: CGFloat, completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.center = point
            self.transform = CGAffineTransform(rotationAngle: rotation)
            if point.x > 0 {
                self.keepOverlay.alpha = 1
            } else {
                self.trashOverlay.alpha = 1
            }
        }) { _ in
            completion()
        }
    }
    
    func resetCard() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            self.center = self.originalPoint
            self.transform = .identity
            self.trashOverlay.alpha = 0
            self.keepOverlay.alpha = 0
        }, completion: nil)
    }
}

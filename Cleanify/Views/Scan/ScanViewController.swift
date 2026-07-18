//
//  ScanViewController.swift
//  Cleanify
//
//  Created by Hevin on 14/07/26.
//

import UIKit
import Photos
import Contacts
import AudioToolbox

class ScanViewController: UIViewController {

    // Palette
    private let accentBlue = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
    private let accentPurple = UIColor(red: 168/255, green: 85/255, blue: 247/255, alpha: 1.0)
    private let accentPink = UIColor(red: 236/255, green: 72/255, blue: 153/255, alpha: 1.0)
    private let accentOrange = UIColor(red: 251/255, green: 146/255, blue: 60/255, alpha: 1.0)
    private let accentGreen = UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0)

    // Scrollable Container for Small Screens Support
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Title label
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    // Full-screen ambient background tint (remains on view level)
    private let backgroundGradientLayer = CAGradientLayer()

    // Concentric blue rings
    private let ringsContainerView = UIView()
    private let innerRingLayer = CAShapeLayer()
    private let middleRingLayer = CAShapeLayer()
    private let outerRingLayer = CAShapeLayer()

    // Original Large Scan Button (scaled up slightly)
    private let scanButton = UIButton(type: .custom)
    private let buttonGradientLayer = CAGradientLayer()
    
    // StackView inside button to center content perfectly in all states
    private let buttonStackView = UIStackView()
    private let scanIcon = UIImageView()
    private let scanTextLabel = UILabel()

    // Horizontal bottom metrics (revealed after scan)
    private let metricsStackView = UIStackView()
    private let usedMetric = MetricView(title: "Used", color: UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0))
    private let availableMetric = MetricView(title: "Available", color: UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0))
    private let reclaimableMetric = MetricView(title: "Reclaimable", color: UIColor(red: 251/255, green: 146/255, blue: 60/255, alpha: 1.0))

    // Progress Ring overlay for active scanning state
    private let progressRing = CircularProgressView()
    private let statusStackView = UIStackView()
    private let shieldIcon = UIImageView()
    private let statusLabel = UILabel()

    // Scan results card (hidden until scan finishes)
    private let resultsContainer = UIStackView()
    private let scoreHeaderLabel = UILabel()
    private let cardsRow = UIStackView()

    private let photoResultCard = SubScoreCard(title: "Photos", score: "--", color: .systemGreen, icon: "photo.stack.fill")
    private let videoResultCard = SubScoreCard(title: "Videos", score: "--", color: .systemOrange, icon: "video.fill")
    private let contactResultCard = SubScoreCard(title: "Contacts", score: "--", color: .systemPurple, icon: "person.crop.circle.fill")

    private let scanAgainButton = UIButton(type: .system)
    
    // Swipe Feature Banner
    private let swipePromoBanner = SwipePromoBannerView()

    // State
    private var isScanning = false
    
    // Smooth Scan Progress State
    private var targetProgress: CGFloat = 0.0
    private var minTimeProgress: CGFloat = 0.0
    private var visualProgressTimer: Timer?
    private var visualProgress: CGFloat = 0.0
    
    // Real Data Properties
    private var realHealthScore = 100
    
    private var ringsTopConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTheme()
        setupUI()
        setupConstraints()
        resetToIdleState()
        
        // Data was loaded by SplashViewController before this screen appears
        let hasData = !PhotoScanManager.shared.allPhotos.isEmpty || !VideoScanManager.shared.allVideos.isEmpty || !ContactScanManager.shared.allContacts.isEmpty
        
        if hasData {
            showCachedResults()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds

        // Keep the button's gradient + shadow perfectly in sync with its actual bounds
        // so the fill and glow always stay a clean circle, even if layout changes.
        buttonGradientLayer.frame = scanButton.bounds
        buttonGradientLayer.cornerRadius = scanButton.bounds.width / 2
        scanButton.layer.shadowPath = UIBezierPath(ovalIn: scanButton.bounds).cgPath
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAuraRotation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        if targetProgress >= 1.0 {
            updateDashboardStats()
        }
    }


    private func setupTheme() {
        view.backgroundColor = .systemBackground

        backgroundGradientLayer.colors = [
            accentBlue.withAlphaComponent(0.10).cgColor,
            UIColor.systemBackground.cgColor
        ]
        backgroundGradientLayer.locations = [0, 0.55]
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        swipePromoBanner.translatesAutoresizingMaskIntoConstraints = false
        swipePromoBanner.isHidden = true
        swipePromoBanner.alpha = 0
        swipePromoBanner.delegate = self
        contentView.addSubview(swipePromoBanner)
        
        titleLabel.text = "Scan Cleanify"
        
        titleLabel.font = UIFont.roundedFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subtitleLabel.text = "Analyze storage and clean junk files."
        subtitleLabel.font = UIFont.roundedFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        setupRings()
        
        progressRing.translatesAutoresizingMaskIntoConstraints = false
        progressRing.strokeWidth = 12
        progressRing.trackColor = .systemGray6
        progressRing.progressColor = [accentBlue, accentPurple]
        progressRing.isHidden = true
        contentView.addSubview(progressRing)

                                
        scanButton.layer.cornerRadius = 90
        scanButton.clipsToBounds = false

        buttonGradientLayer.frame = CGRect(x: 0, y: 0, width: 180, height: 180)
        buttonGradientLayer.colors = [
            UIColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 1.0).cgColor,
            UIColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1.0).cgColor
        ]
        buttonGradientLayer.locations = [0, 1]
        buttonGradientLayer.cornerRadius = 90
        buttonGradientLayer.masksToBounds = true // clip the fill into a clean circle
        scanButton.layer.insertSublayer(buttonGradientLayer, at: 0)

        // Button Shadow (glow) — shaped as a circle so the glow matches the button
        scanButton.layer.shadowColor = accentBlue.cgColor
        scanButton.layer.shadowOpacity = 0.6
        scanButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        scanButton.layer.shadowRadius = 24
        scanButton.layer.shadowPath = UIBezierPath(
            ovalIn: CGRect(x: 0, y: 0, width: 180, height: 180)
        ).cgPath
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        scanButton.addTarget(self, action: #selector(didTapScanButton), for: .touchUpInside)
        contentView.addSubview(scanButton)

        // Vertical stack view inside button to align icon and text correctly
        buttonStackView.axis = .vertical
        buttonStackView.alignment = .center
        buttonStackView.spacing = 10
        buttonStackView.isUserInteractionEnabled = false
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        scanButton.addSubview(buttonStackView)

        // Inside button content
        scanIcon.image = UIImage(systemName: "viewfinder")
        scanIcon.tintColor = .white
        scanIcon.contentMode = .scaleAspectFit
        scanIcon.translatesAutoresizingMaskIntoConstraints = false
        buttonStackView.addArrangedSubview(scanIcon)

        scanTextLabel.textColor = .white
        scanTextLabel.textAlignment = .center
        scanTextLabel.numberOfLines = 0
        scanTextLabel.translatesAutoresizingMaskIntoConstraints = false
        buttonStackView.addArrangedSubview(scanTextLabel)

        // Bottom stats layout row (revealed after scan)
        metricsStackView.axis = .horizontal
        metricsStackView.spacing = 16
        metricsStackView.distribution = .fillEqually
        metricsStackView.translatesAutoresizingMaskIntoConstraints = false
        metricsStackView.isHidden = true
        metricsStackView.alpha = 0
        contentView.addSubview(metricsStackView)

        metricsStackView.addArrangedSubview(usedMetric)
        metricsStackView.addArrangedSubview(availableMetric)
        metricsStackView.addArrangedSubview(reclaimableMetric)

        // Scanning Status Logger
        statusStackView.axis = .horizontal
        statusStackView.spacing = 8
        statusStackView.alignment = .center
        statusStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusStackView)
        
        shieldIcon.image = UIImage(systemName: "checkmark.shield")
        shieldIcon.tintColor = accentBlue
        shieldIcon.contentMode = .scaleAspectFit
        shieldIcon.translatesAutoresizingMaskIntoConstraints = false
        statusStackView.addArrangedSubview(shieldIcon)
        
        statusLabel.text = "Tap the scan button to start scanning your iPhone"
        statusLabel.textColor = .secondaryLabel
        statusLabel.font = UIFont.roundedFont(ofSize: 13, weight: .medium)
        statusLabel.textAlignment = .left
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusStackView.addArrangedSubview(statusLabel)

        // Results Card Row Setup
        resultsContainer.axis = .vertical
        resultsContainer.spacing = 16
        resultsContainer.alignment = .fill
        resultsContainer.translatesAutoresizingMaskIntoConstraints = false
        resultsContainer.isHidden = true
        resultsContainer.alpha = 0
        contentView.addSubview(resultsContainer)

        scoreHeaderLabel.text = "Storage Health: Optimal"
        scoreHeaderLabel.font = UIFont.roundedFont(ofSize: 18, weight: .bold)
        scoreHeaderLabel.textColor = .label
        scoreHeaderLabel.textAlignment = .center
        resultsContainer.addArrangedSubview(scoreHeaderLabel)

        cardsRow.axis = .horizontal
        cardsRow.spacing = 12
        cardsRow.distribution = .fillEqually
        resultsContainer.addArrangedSubview(cardsRow)

        cardsRow.addArrangedSubview(photoResultCard)
        cardsRow.addArrangedSubview(videoResultCard)
        cardsRow.addArrangedSubview(contactResultCard)

        photoResultCard.addTarget(self, action: #selector(didTapPhotosCard), for: .touchUpInside)
        videoResultCard.addTarget(self, action: #selector(didTapVideosCard), for: .touchUpInside)
        contactResultCard.addTarget(self, action: #selector(didTapContactsCard), for: .touchUpInside)

        // Scan again — filled pill button
        scanAgainButton.setTitle("Scan Again", for: .normal)
        scanAgainButton.setTitleColor(.white, for: .normal)
        scanAgainButton.titleLabel?.font = UIFont.roundedFont(ofSize: 15, weight: .bold)
        scanAgainButton.backgroundColor = accentBlue
        scanAgainButton.layer.cornerRadius = 22
        scanAgainButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 28, bottom: 12, right: 28)
        scanAgainButton.translatesAutoresizingMaskIntoConstraints = false
        scanAgainButton.isHidden = true
        scanAgainButton.alpha = 0
        scanAgainButton.addTarget(self, action: #selector(didTapScanAgain), for: .touchUpInside)
        contentView.addSubview(scanAgainButton)
    }

    private func setupRings() {
        ringsContainerView.translatesAutoresizingMaskIntoConstraints = false
        ringsContainerView.isUserInteractionEnabled = false
        contentView.addSubview(ringsContainerView)
        
        ringsTopConstraint = ringsContainerView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 100)
        ringsTopConstraint.isActive = true

        let center = CGPoint(x: 160, y: 160) // 320x320 container
        let layerFrame = CGRect(x: 0, y: 0, width: 320, height: 320)
        
        // Inner Ring
        let innerPath = UIBezierPath(arcCenter: center, radius: 100, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        innerRingLayer.path = innerPath.cgPath
        innerRingLayer.frame = layerFrame
        innerRingLayer.fillColor = UIColor.clear.cgColor
        innerRingLayer.strokeColor = accentBlue.cgColor
        innerRingLayer.lineWidth = 3
        innerRingLayer.shadowColor = accentBlue.cgColor
        innerRingLayer.shadowRadius = 8
        innerRingLayer.shadowOpacity = 0.9
        innerRingLayer.shadowOffset = .zero
        ringsContainerView.layer.addSublayer(innerRingLayer)
        
        
        let middlePath = UIBezierPath(arcCenter: center, radius: 112, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        middleRingLayer.path = middlePath.cgPath
        middleRingLayer.frame = layerFrame
        middleRingLayer.fillColor = UIColor.clear.cgColor
        middleRingLayer.strokeColor = accentBlue.withAlphaComponent(0.12).cgColor
        middleRingLayer.lineWidth = 12
        ringsContainerView.layer.addSublayer(middleRingLayer)
        
        
        let outerPath = UIBezierPath(arcCenter: center, radius: 132, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        outerRingLayer.path = outerPath.cgPath
        outerRingLayer.frame = layerFrame
        outerRingLayer.fillColor = UIColor.clear.cgColor
        outerRingLayer.strokeColor = accentBlue.withAlphaComponent(0.6).cgColor
        outerRingLayer.lineWidth = 2.5
        outerRingLayer.lineDashPattern = [2.5, 12]
        outerRingLayer.lineCap = .round
        ringsContainerView.layer.addSublayer(outerRingLayer)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // Rings container
            ringsContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            ringsContainerView.widthAnchor.constraint(equalToConstant: 320),
            ringsContainerView.heightAnchor.constraint(equalToConstant: 320),

            // Progress ring centered exactly over button
            progressRing.centerXAnchor.constraint(equalTo: ringsContainerView.centerXAnchor),
            progressRing.centerYAnchor.constraint(equalTo: ringsContainerView.centerYAnchor),
            progressRing.widthAnchor.constraint(equalToConstant: 240),
            progressRing.heightAnchor.constraint(equalToConstant: 240),

            // Main Button centered on ringsContainerView
            scanButton.centerXAnchor.constraint(equalTo: ringsContainerView.centerXAnchor),
            scanButton.centerYAnchor.constraint(equalTo: ringsContainerView.centerYAnchor),
            scanButton.widthAnchor.constraint(equalToConstant: 180),
            scanButton.heightAnchor.constraint(equalToConstant: 180),

            // Stack view centered inside the main button
            buttonStackView.centerXAnchor.constraint(equalTo: scanButton.centerXAnchor),
            buttonStackView.centerYAnchor.constraint(equalTo: scanButton.centerYAnchor),
            buttonStackView.leadingAnchor.constraint(equalTo: scanButton.leadingAnchor, constant: 12),
            buttonStackView.trailingAnchor.constraint(equalTo: scanButton.trailingAnchor, constant: -12),

            scanIcon.widthAnchor.constraint(equalToConstant: 28),
            scanIcon.heightAnchor.constraint(equalToConstant: 28),

            // Bottom Metrics stack row
            metricsStackView.topAnchor.constraint(equalTo: ringsContainerView.bottomAnchor, constant: 24),
            metricsStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // Status label sits below the metrics/glow
            statusStackView.topAnchor.constraint(equalTo: metricsStackView.bottomAnchor, constant: 24),
            statusStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            statusStackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            statusStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),

            // Results Section
            resultsContainer.topAnchor.constraint(equalTo: statusStackView.bottomAnchor, constant: 24),
            resultsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            resultsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            photoResultCard.heightAnchor.constraint(equalToConstant: 108),

            // Scan again top constraint chained to resultsContainer, completing scroll height
            scanAgainButton.topAnchor.constraint(equalTo: resultsContainer.bottomAnchor, constant: 32),
            scanAgainButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            // Promo Banner
            swipePromoBanner.topAnchor.constraint(equalTo: scanAgainButton.bottomAnchor, constant: 32),
            swipePromoBanner.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            swipePromoBanner.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            swipePromoBanner.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -120)
        ])
    }

    // MARK: - Restore State Setup
    private func resetToIdleState() {
        scanIcon.image = UIImage(systemName: "viewfinder")
        scanIcon.isHidden = false
        
        scanTextLabel.attributedText = nil
        scanTextLabel.text = "SCAN YOUR iPHONE"
        scanTextLabel.textColor = .white
        scanTextLabel.font = UIFont.roundedFont(ofSize: 16, weight: .bold)
        
        metricsStackView.isHidden = true
        metricsStackView.alpha = 0
        swipePromoBanner.isHidden = true
        swipePromoBanner.alpha = 0
        
        statusLabel.text = "Tap the scan button to start scanning your iPhone"
        shieldIcon.isHidden = false
        
        scrollView.isScrollEnabled = false
        
        DispatchQueue.main.async { [weak self] in
            self?.startIdleBreathingAnimation()
        }
    }
    
    private func showCachedResults() {
        targetProgress = 1.0
        minTimeProgress = 1.0
        visualProgress = 1.0
        
        isScanning = false
        setAuraScanning(false)
        
        ringsTopConstraint.constant = 16
        scanButton.transform = .identity
        updateDashboardStats()
        statusLabel.text = "Optimization Completed"
        
        progressRing.isHidden = true
        scanIcon.isHidden = true
        scanTextLabel.isHidden = false
        shieldIcon.isHidden = true
        
        metricsStackView.isHidden = false
        resultsContainer.isHidden = false
        scanAgainButton.isHidden = false
        swipePromoBanner.isHidden = false
        
        metricsStackView.alpha = 1
        resultsContainer.alpha = 1
        scanAgainButton.alpha = 1
        swipePromoBanner.alpha = 1
        
        scrollView.isScrollEnabled = true
        scanButton.layer.removeAnimation(forKey: "pulse")
    }

    // MARK: - Rings animation

    private func startAuraRotation() {
        guard outerRingLayer.animation(forKey: "rotate") == nil else { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 14
        rotation.repeatCount = .infinity
        outerRingLayer.add(rotation, forKey: "rotate")
        
        // Idle opacity
        ringsContainerView.alpha = 1.0
        innerRingLayer.opacity = 1.0
        middleRingLayer.opacity = 1.0
        outerRingLayer.opacity = 1.0
    }

    private func startIdleBreathingAnimation() {
        let breathe = CABasicAnimation(keyPath: "transform.scale")
        breathe.fromValue = 1.0
        breathe.toValue = 1.06
        breathe.duration = 1.0
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        innerRingLayer.add(breathe, forKey: "breathe")
        middleRingLayer.add(breathe, forKey: "breathe")
        
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.06
        pulse.duration = 1.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        scanButton.layer.add(pulse, forKey: "idlePulse")
    }

    private func setAuraScanning(_ scanning: Bool) {
        UIView.animate(withDuration: 0.4) {
            // Speed up rotation when scanning
            self.outerRingLayer.speed = scanning ? 3.0 : 1.0
            
            
        }
    }

    private func stopIdleAnimations() {
        innerRingLayer.removeAnimation(forKey: "breathe")
        middleRingLayer.removeAnimation(forKey: "breathe")
        scanButton.layer.removeAnimation(forKey: "idlePulse")
    }

    @objc private func didTapScanButton() {
        guard !isScanning else { return }
        
        // Request Photo and Contact Access before scanning real database
        requestPermissionsIfNeeded { [weak self] granted in
            DispatchQueue.main.async {
                self?.startScanningFlow()
            }
        }
    }
    
    private func requestPermissionsIfNeeded(completion: @escaping (Bool) -> Void) {
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let contactStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        let group = DispatchGroup()
        
        if photoStatus == .notDetermined {
            group.enter()
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                group.leave()
            }
        }
        
        if contactStatus == .notDetermined {
            group.enter()
            CNContactStore().requestAccess(for: .contacts) { _, _ in
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(true)
        }
    }

    private func startScanningFlow() {
        isScanning = true
        targetProgress = 0.0
        minTimeProgress = 0.0
        visualProgress = 0.0
        
        stopIdleAnimations()
        setAuraScanning(true)
        
        scrollView.isScrollEnabled = false
        
        // Remove pulse animation if present
        scanButton.layer.removeAnimation(forKey: "pulse")

        scanIcon.isHidden = true // hide the sparkles icon to focus on visual progress
        
        ringsTopConstraint.constant = 100
        UIView.animate(withDuration: 0.3) {
            self.scanButton.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.view.layoutIfNeeded()
        }

        progressRing.isHidden = false
        progressRing.setProgress(0.0, animated: false)

        metricsStackView.isHidden = true
        metricsStackView.alpha = 0
        resultsContainer.isHidden = true
        resultsContainer.alpha = 0
        scanAgainButton.isHidden = true
        scanAgainButton.alpha = 0
        swipePromoBanner.isHidden = true
        swipePromoBanner.alpha = 0
        
        // Enforce smooth visual progress matching real scan, but taking at least 5.0 seconds
        var tickCount = 0
        visualProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.minTimeProgress += 0.01
            if self.minTimeProgress > 1.0 { self.minTimeProgress = 1.0 }
            
            self.visualProgress = min(self.targetProgress, self.minTimeProgress)
            
            tickCount += 1
            if tickCount % 2 == 0 {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
            }
            
            if self.visualProgress >= 1.0 {
                self.visualProgress = 1.0
                timer.invalidate()
                self.visualProgressTimer = nil
                self.completeScanningFlow()
            } else {
                self.progressRing.setProgress(self.visualProgress, animated: true)
                
                // Attributed string showing visual percentage inside button
                let percentText = "\(Int(self.visualProgress * 100))%"
                let combined = NSMutableAttributedString()
                combined.append(NSAttributedString(string: "\(percentText)\n", attributes: [
                    .font: UIFont.roundedFont(ofSize: 34, weight: .bold),
                    .foregroundColor: UIColor.label
                ]))
                combined.append(NSAttributedString(string: "SCANNING", attributes: [
                    .font: UIFont.roundedFont(ofSize: 11, weight: .bold),
                    .foregroundColor: UIColor.secondaryLabel
                ]))
                self.scanTextLabel.attributedText = combined
            }
        }

        // Trigger real scanner tasks in background
        PhotoScanManager.shared.scanPhotoLibrary(progressHandler: { [weak self] msg, prog in
            DispatchQueue.main.async {
                self?.targetProgress = CGFloat(prog) * 0.70
                self?.statusLabel.text = msg
            }
        }, completion: { [weak self] in
            guard let self = self else { return }
            VideoScanManager.shared.scanVideoLibrary(progressHandler: { [weak self] msg, prog in
                DispatchQueue.main.async {
                    self?.targetProgress = 0.70 + CGFloat(prog) * 0.20
                    self?.statusLabel.text = msg
                }
            }, completion: { [weak self] in
                guard let self = self else { return }
                ContactScanManager.shared.scanContacts(progressHandler: { [weak self] msg, prog in
                    DispatchQueue.main.async {
                        self?.targetProgress = 0.90 + CGFloat(prog) * 0.10
                        self?.statusLabel.text = msg
                    }
                }, completion: { [weak self] in
                    DispatchQueue.main.async {
                        PhotoScanManager.shared.saveToDisk()
                        VideoScanManager.shared.saveToDisk()
                        ContactScanManager.shared.saveToDisk()
                        self?.targetProgress = 1.0
                        self?.statusLabel.text = "Finalizing storage calculations..."
                    }
                })
            })
        })
    }

    private func updateDashboardStats() {
        let stats = StorageManager.shared.getFormattedStats()
        let diskBytes = StorageManager.shared.getDiskSpaceBytes()
        
        // Calculate total items to clean
        let duplicatesPhotosCount = PhotoScanManager.shared.duplicateGroups.flatMap({ $0.assets }).count + PhotoScanManager.shared.similarGroups.flatMap({ $0.assets }).count + PhotoScanManager.shared.screenshots.count + PhotoScanManager.shared.burstPhotos.count + PhotoScanManager.shared.blurryPhotos.count
        let duplicatesVideosCount = VideoScanManager.shared.largeVideos.count + VideoScanManager.shared.oldVideos.count
        let duplicatesContactsCount = ContactScanManager.shared.duplicateNameGroups.flatMap({ $0.contacts }).count + ContactScanManager.shared.duplicatePhoneGroups.flatMap({ $0.contacts }).count + ContactScanManager.shared.incompleteContactsList.count
        
        // Update cards with real data numbers
        photoResultCard.setScore("\(duplicatesPhotosCount)")
        videoResultCard.setScore("\(duplicatesVideosCount)")
        contactResultCard.setScore("\(duplicatesContactsCount)")

        // Calculate Cleanable Reclaimable sizes in bytes (approximate)
        let reclaimablePhotoBytes = Int64(duplicatesPhotosCount) * 3_000_000 // 3MB average
        var reclaimableVideoBytes: Int64 = 0
        for asset in VideoScanManager.shared.largeVideos {
            reclaimableVideoBytes += VideoScanManager.shared.videoSizes[asset.localIdentifier] ?? 0
        }
        let totalReclaimableBytes = reclaimablePhotoBytes + reclaimableVideoBytes
        let reclaimableString = formatGB(totalReclaimableBytes)
        
        // Set storage info inside the center of the circle
        let combined = NSMutableAttributedString()
        combined.append(NSAttributedString(string: "\(stats.used)\n", attributes: [
            .font: UIFont.roundedFont(ofSize: 26, weight: .bold),
            .foregroundColor: UIColor.label
        ]))
        combined.append(NSAttributedString(string: "of \(stats.total)\n", attributes: [
            .font: UIFont.roundedFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]))
        combined.append(NSAttributedString(string: "\(Int(stats.percentUsed * 100))% used", attributes: [
            .font: UIFont.roundedFont(ofSize: 12, weight: .bold),
            .foregroundColor: accentGreen
        ]))

        // Set metrics values below the circle
        usedMetric.setValue(formatGB(diskBytes.used - totalReclaimableBytes))
        availableMetric.setValue(stats.free)
        reclaimableMetric.setValue(reclaimableString)
        
        // Dynamic health score logic based on percent usage
        if stats.percentUsed < 0.60 {
            realHealthScore = 96
        } else if stats.percentUsed < 0.80 {
            realHealthScore = 84
        } else if stats.percentUsed < 0.92 {
            realHealthScore = 71
        } else {
            realHealthScore = 48
        }

        scanTextLabel.attributedText = combined
        let cardText = self.realHealthScore > 80 ? "Optimal" : (self.realHealthScore > 60 ? "Good" : "Needs Review")
        self.scoreHeaderLabel.text = "Storage Health: \(cardText)"
    }

    private func completeScanningFlow() {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        isScanning = false
        setAuraScanning(false)
        
        ringsTopConstraint.constant = 16
        UIView.animate(withDuration: 0.4, delay: 0.2, options: .curveEaseOut, animations: {
            self.scanButton.transform = .identity
            self.updateDashboardStats()
            self.statusLabel.text = "Optimization Completed"
            self.progressRing.isHidden = true
            
            self.scanIcon.isHidden = true
            self.scanTextLabel.isHidden = false
            
            self.view.layoutIfNeeded()
            
            // Fade-in the bottom metrics section
            self.metricsStackView.isHidden = false
            self.metricsStackView.alpha = 1
        }, completion: { [weak self] _ in
            self?.revealResults()
            self?.startPulsingAnimation()
        })
    }

    private func formatGB(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        return String(format: "%.2f GB", gb)
    }

    private func startPulsingAnimation() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.duration = 1.8
        pulse.fromValue = 1.0
        pulse.toValue = 1.04
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        scanButton.layer.add(pulse, forKey: "pulse")
    }

    private func revealResults() {
        resultsContainer.isHidden = false
        resultsContainer.transform = CGAffineTransform(translationX: 0, y: 16)
        resultsContainer.alpha = 0
        scanAgainButton.isHidden = false
        swipePromoBanner.isHidden = false
        
        scrollView.isScrollEnabled = true

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4, options: [], animations: {
            self.resultsContainer.alpha = 1
            self.resultsContainer.transform = .identity
        })

        UIView.animate(withDuration: 0.4, delay: 0.15, options: [], animations: {
            self.scanAgainButton.alpha = 1
            self.swipePromoBanner.alpha = 1
        })
    }

    @objc private func didTapScanAgain() {
        startScanningFlow()
    }

    // MARK: - Sub Score Card Redirections
    @objc private func didTapPhotosCard() {
        tabBarController?.selectedIndex = 1
    }

    @objc private func didTapVideosCard() {
        tabBarController?.selectedIndex = 2
    }

    @objc private func didTapContactsCard() {
        tabBarController?.selectedIndex = 3
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            backgroundGradientLayer.colors = [
                accentBlue.withAlphaComponent(0.10).cgColor,
                UIColor.systemBackground.cgColor
            ]
            buttonGradientLayer.colors = [
                UIColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1.0).cgColor
            ]
            scanButton.layer.shadowColor = accentBlue.cgColor
        }
    }
}

// MARK: - Metric View Component
class MetricView: UIView {
    
    private let valueLabel = UILabel()
    private let titleLabel = UILabel()
    
    init(title: String, color: UIColor) {
        super.init(frame: .zero)
        setup(title: title, color: color)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup(title: String, color: UIColor) {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 2
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        
        valueLabel.text = "--"
        valueLabel.textColor = color
        valueLabel.font = UIFont.roundedFont(ofSize: 14, weight: .bold)
        container.addArrangedSubview(valueLabel)
        
        titleLabel.text = title
        titleLabel.textColor = .secondaryLabel
        titleLabel.font = UIFont.roundedFont(ofSize: 11, weight: .medium)
        container.addArrangedSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func setValue(_ value: String) {
        valueLabel.text = value
    }
}

// MARK: - SubScoreCard Component
class SubScoreCard: UIControl {

    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let scoreLabel = UILabel()
    private let detailLabel = UILabel()

    init(title: String, score: String, color: UIColor, icon: String) {
        super.init(frame: .zero)
        setup(title: title, score: score, color: color, icon: icon)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func setup(title: String, score: String, color: UIColor, icon: String) {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 18
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.15).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)
        translatesAutoresizingMaskIntoConstraints = false

        iconBackground.backgroundColor = color.withAlphaComponent(0.15)
        iconBackground.layer.cornerRadius = 14
        iconBackground.isUserInteractionEnabled = false
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconBackground)

        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(iconView)

        titleLabel.text = title
        titleLabel.font = UIFont.roundedFont(ofSize: 12, weight: .bold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        scoreLabel.text = score
        scoreLabel.textColor = color
        scoreLabel.font = UIFont.roundedFont(ofSize: 22, weight: .bold)
        scoreLabel.textAlignment = .center
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scoreLabel)

        detailLabel.text = "Details →"
        detailLabel.font = UIFont.roundedFont(ofSize: 10, weight: .bold)
        detailLabel.textColor = .link
        detailLabel.textAlignment = .center
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(detailLabel)

        NSLayoutConstraint.activate([
            iconBackground.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            iconBackground.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconBackground.widthAnchor.constraint(equalToConstant: 28),
            iconBackground.heightAnchor.constraint(equalToConstant: 28),

            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 15),

            titleLabel.topAnchor.constraint(equalTo: iconBackground.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),

            scoreLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            scoreLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6)
        ])
    }
    
    func setScore(_ score: String) {
        scoreLabel.text = score
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.75 : 1.0
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.15).cgColor
            layer.shadowColor = UIColor.black.cgColor
        }
    }
}

extension ScanViewController: SwipePromoBannerDelegate {
    func didTapTryNow() {
        let swipeVC = SwipePhotosViewController()
        swipeVC.hidesBottomBarWhenPushed = true
        // The current file doesn't have a navigation controller pushed onto it directly, we might need to present it or push if in nav controller
        if let nav = navigationController {
            nav.pushViewController(swipeVC, animated: true)
        } else {
            swipeVC.modalPresentationStyle = .fullScreen
            present(swipeVC, animated: true, completion: nil)
        }
    }
}

// MARK: - Rounded font helper
extension UIFont {
    static func roundedFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = systemFont.fontDescriptor.withDesign(.rounded) else { return systemFont }
        return UIFont(descriptor: descriptor, size: size)
    }
}

import Foundation
import FirebaseAnalytics

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    // MARK: - Core Logger
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
    
    // MARK: - Onboarding
    func logOnboardingStepViewed(step: Int, title: String) {
        logEvent("onboarding_step_viewed", parameters: [
            "step_number": step,
            "step_title": title
        ])
    }
    
    func logOnboardingNextClicked(fromStep step: Int) {
        logEvent("onboarding_next_clicked", parameters: [
            "current_step": step
        ])
    }
    
    func logOnboardingOptionSelected(id: Int, name: String) {
        logEvent("onboarding_option_selected", parameters: [
            "option_id": id,
            "option_name": name
        ])
    }
    
    func logOnboardingCompleted(selectedOption: String) {
        logEvent("onboarding_completed", parameters: [
            "final_selected_option": selectedOption
        ])
    }
    
    // MARK: - Paywall & Subscriptions
    func logPaywallViewed(source: String) {
        logEvent("paywall_viewed", parameters: [
            "source": source
        ])
    }
    
    func logPaywallPlanSelected(planId: String, planPeriod: String, price: String) {
        logEvent("paywall_plan_selected", parameters: [
            "plan_id": planId,
            "plan_period": planPeriod,
            "price": price
        ])
    }
    
    func logSubscribeClicked(planId: String, planPeriod: String, price: String) {
        logEvent("paywall_subscribe_clicked", parameters: [
            "plan_id": planId,
            "plan_period": planPeriod,
            "price": price
        ])
    }
    
    func logPurchaseSuccess(productId: String, price: Double? = nil, currency: String? = nil) {
        var params: [String: Any] = [AnalyticsParameterItemID: productId]
        if let price = price {
            params[AnalyticsParameterPrice] = price
        }
        if let currency = currency {
            params[AnalyticsParameterCurrency] = currency
        }
        logEvent("purchase_success", parameters: params)
    }
    
    func logPurchaseFailed(productId: String, errorMessage: String) {
        logEvent("purchase_failed", parameters: [
            "product_id": productId,
            "error_message": errorMessage
        ])
    }
    
    func logRestoreClicked() {
        logEvent("restore_purchases_clicked")
    }
    
    func logRestoreSuccess(productId: String) {
        logEvent("restore_success", parameters: [
            "restored_product_id": productId
        ])
    }
    
    func logPaywallDismissed() {
        logEvent("paywall_dismissed")
    }
    
    // MARK: - Photos Cleaner
    func logPhotoScanStarted(source: String = "manual") {
        logEvent("photo_scan_started", parameters: ["source": source])
    }
    
    func logPhotoScanCompleted(duplicates: Int, similar: Int, screenshots: Int, totalBytes: Int64) {
        logEvent("photo_scan_completed", parameters: [
            "duplicate_count": duplicates,
            "similar_count": similar,
            "screenshot_count": screenshots,
            "total_cleanable_bytes": totalBytes
        ])
    }
    
    func logPhotoCategorySelected(category: String, count: Int) {
        logEvent("photo_category_selected", parameters: [
            "category_name": category,
            "items_count": count
        ])
    }
    
    func logPhotoSelectAllToggled(category: String, isSelected: Bool) {
        logEvent("photo_select_all_toggled", parameters: [
            "category": category,
            "is_selected": isSelected
        ])
    }
    
    func logPhotoDeleteInitiated(category: String, count: Int) {
        logEvent("photo_delete_initiated", parameters: [
            "category": category,
            "selected_count": count
        ])
    }
    
    func logPhotoDeleteSuccess(category: String, count: Int) {
        logEvent("photo_delete_success", parameters: [
            "category": category,
            "deleted_count": count
        ])
    }
    
    func logRecentlyDeletedGuideOpened(source: String = "photos_tab") {
        logEvent("recently_deleted_guide_opened", parameters: ["source": source])
    }
    
    // MARK: - Swipe Photo Cleaner
    func logSwipeScreenOpened(initialCategory: String) {
        logEvent("swipe_screen_opened", parameters: ["initial_category": initialCategory])
    }
    
    func logSwipeActionKeep(assetType: String) {
        logEvent("swipe_action_keep", parameters: ["asset_type": assetType])
    }
    
    func logSwipeActionTrash(assetType: String) {
        logEvent("swipe_action_trash", parameters: ["asset_type": assetType])
    }
    
    func logSwipeActionUndo() {
        logEvent("swipe_action_undo")
    }
    
    func logSwipeDeleteConfirmed(count: Int, freedBytes: Int64) {
        logEvent("swipe_delete_confirmed", parameters: [
            "deleted_count": count,
            "freed_bytes": freedBytes
        ])
    }
    
    // MARK: - Videos Cleaner & Compression
    func logVideoCategorySelected(category: String, count: Int) {
        logEvent("video_category_selected", parameters: [
            "category_name": category,
            "items_count": count
        ])
    }
    
    func logVideoDeleteSuccess(category: String, count: Int) {
        logEvent("video_delete_success", parameters: [
            "category": category,
            "deleted_count": count
        ])
    }
    
    func logVideoCompressStarted(originalMB: Double, targetQuality: String) {
        logEvent("video_compress_started", parameters: [
            "original_size_mb": originalMB,
            "target_quality": targetQuality
        ])
    }
    
    func logVideoCompressCompleted(originalMB: Double, compressedMB: Double, savedMB: Double) {
        logEvent("video_compress_completed", parameters: [
            "original_size_mb": originalMB,
            "compressed_size_mb": compressedMB,
            "saved_size_mb": savedMB
        ])
    }
    
    // MARK: - Contacts Cleaner
    func logContactsTabOpened(duplicateGroups: Int, incomplete: Int) {
        logEvent("contacts_tab_opened", parameters: [
            "duplicate_groups_count": duplicateGroups,
            "incomplete_count": incomplete
        ])
    }
    
    func logContactsSegmentChanged(segment: String) {
        logEvent("contacts_segment_changed", parameters: [
            "selected_segment": segment
        ])
    }
    
    func logContactsMerged(count: Int) {
        logEvent("contacts_merged", parameters: [
            "contacts_in_group": count
        ])
    }
    
    func logIncompleteContactDeleted() {
        logEvent("incomplete_contact_deleted")
    }
    
    // MARK: - Settings & Engagement
    func logRateUsClicked() {
        logEvent("settings_rate_us_clicked")
    }
    
    func logShareClicked() {
        logEvent("settings_share_clicked")
    }
    
    func logThemeToggled(theme: String) {
        logEvent("settings_theme_toggled", parameters: [
            "theme_selected": theme
        ])
    }
    
    func logGuideOpened(guideType: String) {
        logEvent("settings_guide_opened", parameters: [
            "guide_type": guideType
        ])
    }
    
    func logPrivacyClicked() {
        logEvent("settings_privacy_clicked")
    }
    
    // MARK: - Ads Tracking
    func logInterstitialAdShown(placement: String) {
        logEvent("interstitial_ad_shown", parameters: [
            "placement": placement
        ])
    }
    
    func logRewardedAdCompleted(rewardType: String) {
        logEvent("rewarded_ad_completed", parameters: [
            "feature_unlocked": rewardType
        ])
    }
}

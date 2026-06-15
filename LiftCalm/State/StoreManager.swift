//
//  StoreManager.swift
//  LiftCalm
//
//  The single source of truth for the one-time "LiftCalm Plus" unlock. Mirrors
//  the NotificationManager shape: an @Observable @MainActor object injected via
//  the environment, so any gate that reads `isPlus` re-renders the instant the
//  entitlement flips. StoreKit 2 only — no receipts, no server, no account
//  (privacy-first). Entitlement is always derived from Transaction state; the
//  cached flag only avoids a one-frame flicker on cold launch.
//

import StoreKit

@Observable
@MainActor
final class StoreManager {

    /// The non-consumable unlock. Must match the product id in App Store Connect
    /// and Products.storekit.
    static let plusProductID = "com.sambulosendas1.LiftCalm.plus"

    /// Whether LiftCalm Plus is unlocked. Source of truth for every premium gate.
    private(set) var isPlus: Bool
    /// The loaded product (nil until StoreKit responds, or if loading failed).
    private(set) var plusProduct: Product?
    /// Drives the paywall's buy button + error alert.
    private(set) var purchaseState: PurchaseState = .idle

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    /// Also read by `WidgetBridge` to bake the Plus state into the widget snapshot.
    static let cacheKey = "plus.entitlement.cached"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Seed from the last-known value so gates don't flash "locked" on launch
        // before StoreKit's async entitlement check completes.
        self.isPlus = defaults.bool(forKey: Self.cacheKey)
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Lifecycle

    /// Called once at app launch: load the product, reconcile the real
    /// entitlement, and begin listening for out-of-band transaction updates
    /// (Ask to Buy approvals, family sharing, refunds, restores on other devices).
    func start() async {
        await loadProduct()
        await refreshEntitlement()
        listenForUpdates()
    }

    func loadProduct() async {
        plusProduct = try? await Product.products(for: [Self.plusProductID]).first
    }

    /// Recomputes `isPlus` from the current entitlements. A verified, un-revoked
    /// transaction for the Plus product grants access.
    func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.plusProductID, transaction.revocationDate == nil {
                entitled = true
            }
        }
        setPlus(entitled)
    }

    // MARK: - Purchase / Restore

    /// Buys the Plus unlock. Returns true on a verified success. Cancellation and
    /// pending ("Ask to Buy") are not failures — they leave the paywall open.
    @discardableResult
    func purchase() async -> Bool {
        guard let product = plusProduct else {
            purchaseState = .failed("The product isn't available right now. Please try again.")
            return false
        }
        purchaseState = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseState = .failed("Your purchase couldn't be verified.")
                    return false
                }
                await transaction.finish()
                setPlus(true)
                purchaseState = .idle
                return true
            case .userCancelled:
                purchaseState = .idle
                return false
            case .pending:
                // Awaiting approval (e.g. Ask to Buy); the updates listener will
                // grant access once it's approved.
                purchaseState = .idle
                return false
            @unknown default:
                purchaseState = .idle
                return false
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
            return false
        }
    }

    /// Restores a previous purchase. `AppStore.sync()` forces a refresh against
    /// the account; entitlement is then recomputed from transactions.
    func restore() async {
        purchaseState = .purchasing
        try? await AppStore.sync()
        await refreshEntitlement()
        purchaseState = .idle
    }

    func clearError() {
        if case .failed = purchaseState { purchaseState = .idle }
    }

    // MARK: - Private

    private func listenForUpdates() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
    }

    private func setPlus(_ value: Bool) {
        isPlus = value
        defaults.set(value, forKey: Self.cacheKey)
    }
}

/// Purchase flow state, surfaced to the paywall.
enum PurchaseState: Equatable {
    case idle
    case purchasing
    case failed(String)
}

#if DEBUG
extension StoreManager {
    /// An unlocked instance for previews. Seeds the cache so `isPlus` is true on
    /// init without touching StoreKit.
    static var unlockedPreview: StoreManager {
        let defaults = UserDefaults(suiteName: "com.liftcalm.preview.plus")!
        defaults.set(true, forKey: cacheKey)
        return StoreManager(defaults: defaults)
    }
}
#endif

// MARK: - Plus policy

/// Pure, testable rules for what the free tier allows. Keeping the limits here
/// (rather than scattered through views) makes the free/paid split a single,
/// reviewable decision.
enum PlusPolicy {
    /// Free users may keep this many custom routines; built-in routines and
    /// workout logging are always unlimited.
    static let freeCustomRoutineLimit = 2

    /// Whether a new custom routine can be created given the current count.
    /// Existing routines are never deleted when locked — the cap only blocks
    /// *new* creation, so a refunded Plus user keeps what they made.
    static func canCreateCustomRoutine(currentCount: Int, isPlus: Bool) -> Bool {
        isPlus || currentCount < freeCustomRoutineLimit
    }
}

// MARK: - Paywall routing

/// Identifies which gate triggered the paywall, so its headline can speak to the
/// thing the user just reached for.
enum PaywallContext: String, Identifiable, Hashable, CaseIterable {
    case routines
    case readiness
    case charts
    case sync
    case generic

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .routines: "Build unlimited routines"
        case .readiness: "See the full picture"
        case .charts: "See your strength climb"
        case .sync: "Sync across your devices"
        case .generic: "Unlock LiftCalm Plus"
        }
    }

    var subheadline: String {
        switch self {
        case .routines:
            "You've reached the \(PlusPolicy.freeCustomRoutineLimit)-routine limit on the free plan. Plus lets you save as many as you like."
        case .readiness:
            "Plus reveals the full recovery breakdown behind your readiness score."
        case .charts:
            "Plus charts every lift's estimated 1RM and volume over time, so you can see what's working."
        case .sync:
            "Plus keeps your training backed up and in sync across your devices with iCloud."
        case .generic:
            "A one-time unlock for the features that go deeper."
        }
    }
}

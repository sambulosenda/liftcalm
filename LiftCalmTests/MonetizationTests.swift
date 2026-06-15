//
//  MonetizationTests.swift
//  LiftCalmTests
//
//  Coverage for the free/paid split rules and the entitlement cache behaviour.
//

import Testing
import Foundation
@testable import LiftCalm

struct MonetizationTests {

    // MARK: - Free routine cap

    @Test func plusUserCanAlwaysCreateRoutines() {
        for count in [0, 1, 2, 3, 50] {
            #expect(PlusPolicy.canCreateCustomRoutine(currentCount: count, isPlus: true))
        }
    }

    @Test func freeUserCanCreateUpToTheLimit() {
        #expect(PlusPolicy.canCreateCustomRoutine(currentCount: 0, isPlus: false))
        #expect(PlusPolicy.canCreateCustomRoutine(currentCount: 1, isPlus: false))
    }

    @Test func freeUserIsBlockedAtTheLimit() {
        #expect(PlusPolicy.canCreateCustomRoutine(currentCount: 2, isPlus: false) == false)
        #expect(PlusPolicy.canCreateCustomRoutine(currentCount: 3, isPlus: false) == false)
    }

    @Test func freeLimitMatchesPolicyConstant() {
        // The boundary is exactly the configured limit, not a hard-coded 2.
        let limit = PlusPolicy.freeCustomRoutineLimit
        #expect(PlusPolicy.canCreateCustomRoutine(currentCount: limit - 1, isPlus: false))
        #expect(PlusPolicy.canCreateCustomRoutine(currentCount: limit, isPlus: false) == false)
    }

    // MARK: - Entitlement cache

    @Test @MainActor func freshInstallIsLocked() {
        let suite = "com.liftcalm.tests.plus.fresh"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        #expect(StoreManager(defaults: defaults).isPlus == false)
    }

    @Test @MainActor func cachedEntitlementUnlocksOnLaunch() {
        // unlockedPreview seeds the cache then inits — exercising the read path
        // that avoids a locked flash on cold launch.
        #expect(StoreManager.unlockedPreview.isPlus)
    }

    // MARK: - Paywall copy

    @Test func routinesPaywallNamesTheLimit() {
        #expect(PaywallContext.routines.subheadline.contains("\(PlusPolicy.freeCustomRoutineLimit)"))
    }
}

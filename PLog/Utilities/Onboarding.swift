//
//  Onboarding.swift
//  PLog
//
//  Whether the welcome sheet is still owed. It's shown once, on a brand-new install, and
//  never to a store that already has data — an existing user has nothing to be welcomed to.
//

import Foundation

enum Onboarding {
    /// `@AppStorage` key: true from a fresh install's first launch until the welcome sheet
    /// is dismissed (by choosing a program or by skipping it).
    static let welcomePendingKey = "welcomePending"

    /// Called once per launch, right after the store opens.
    static func noteLaunch(isFreshInstall: Bool, defaults: UserDefaults = .standard) {
        if isFreshInstall {
            defaults.set(true, forKey: welcomePendingKey)
        }
    }
}

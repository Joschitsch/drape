//
//  FontRegistration.swift
//  drape
//
//  Registers the bundled editorial typefaces (Newsreader, Hanken Grotesk,
//  Spline Sans Mono) at runtime. Runtime registration via Core Text avoids
//  needing a `UIAppFonts` array in the generated Info.plist, which the project
//  does not maintain (GENERATE_INFOPLIST_FILE = YES).
//
//  Call `DrapeFonts.registerAll()` once, as early as possible (app init).
//

import CoreText
import Foundation
import UIKit

enum DrapeFonts {
    /// Registers every `.ttf` bundled under Resources/Fonts. Idempotent: a
    /// second call is a no-op (already-registered errors are ignored).
    static func registerAll() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil),
              !urls.isEmpty else { return }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, false, nil)
        applyNavigationBarAppearance()
    }

    /// Renders navigation-bar titles (large + inline) in Newsreader, so the
    /// editorial voice carries into the system chrome.
    private static func applyNavigationBarAppearance() {
        let ink = UIColor(red: 0x1C/255, green: 0x1A/255, blue: 0x17/255, alpha: 1)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        if let large = UIFont(name: Serif.medium, size: 34) {
            appearance.largeTitleTextAttributes = [.font: large, .foregroundColor: ink,
                                                   .kern: 0.37]
        }
        if let inline = UIFont(name: Body.semibold, size: 17) {
            appearance.titleTextAttributes = [.font: inline, .foregroundColor: ink]
        }
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    // ── PostScript names of the bundled faces ────────────────────────────
    // (read from each .ttf's name table — see Resources/Fonts)
    enum Serif {
        static let regular      = "Newsreader16pt16pt-Regular"
        static let medium       = "Newsreader16pt16pt-Medium"
        static let italic       = "Newsreader16pt16pt-Italic"
        static let mediumItalic = "Newsreader16pt16pt-MediumItalic"
    }
    enum Body {
        static let regular  = "HankenGrotesk-Regular"
        static let medium   = "HankenGrotesk-Medium"
        static let semibold = "HankenGrotesk-SemiBold"
        static let bold     = "HankenGrotesk-Bold"
    }
    enum Mono {
        static let regular = "SplineSansMono-Regular"
        static let medium  = "SplineSansMono-Medium"
    }
}

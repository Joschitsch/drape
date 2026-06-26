//
//  ShareSheet.swift
//  drape
//
//  Minimal UIKit share-sheet bridge for handing files (exported images, ground-
//  truth bundles) to AirDrop / Photos / Files via the system activity sheet.
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

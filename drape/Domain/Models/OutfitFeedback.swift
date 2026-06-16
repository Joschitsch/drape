//
//  OutfitFeedback.swift
//  drape
//
//  SwiftData model: a single thumbs rating on a suggested outfit. The live
//  personalisation lives in `UserProfile.styleTuning`; these rows are the audit
//  trail (and the seed for any future, richer learning).
//

import Foundation
import SwiftData

@Model
final class OutfitFeedback {
    var id: UUID = UUID()
    var date: Date = Date.now
    /// True for thumbs-up, false for thumbs-down.
    var positive: Bool = false
    /// Reason chips the user tapped, stored as `FeedbackReason` raw values.
    var reasonsRaw: [String] = []
    /// The garments that made up the rated suggestion, for later analysis.
    var garmentIDs: [UUID] = []
    var occasionRaw: String = Occasion.everyday.rawValue

    init(
        positive: Bool,
        reasons: [FeedbackReason],
        garmentIDs: [UUID],
        occasion: Occasion
    ) {
        self.positive = positive
        self.reasonsRaw = reasons.map(\.rawValue)
        self.garmentIDs = garmentIDs
        self.occasionRaw = occasion.rawValue
    }

    var reasons: [FeedbackReason] { reasonsRaw.compactMap(FeedbackReason.init(rawValue:)) }
}

import Foundation
import SwiftData

/// Sticky-level state machine. DEFCON numbering is INVERTED: 1 = highest severity,
/// 5 = lowest. The machine tracks a "floor" (most severe level seen recently) and
/// only allows the displayed level to decrease in severity (numeric value increase)
/// one step per cooldown period. Severity rises take effect immediately.
///
/// Pure port of docker `db/sticky_level.py`.
enum StickyLevel {

    /// 3 hours, matching docker `COOLDOWN`.
    static let cooldown: TimeInterval = 3 * 3600

    struct State {
        let floor: Int?
        let untilAt: Date?
    }

    struct Result {
        let displayedLevel: Int
        let newFloor: Int
        let newUntilAt: Date?
    }

    private static func isMoreSevere(_ a: Int, than b: Int) -> Bool { a < b }

    static func computeDisplayedLevel(rawLevel: Int,
                                      state: State,
                                      evidenceAnchor: Date? = nil,
                                      now: Date = Date()) -> Result {
        guard let floor = state.floor else {
            return Result(displayedLevel: rawLevel, newFloor: rawLevel, newUntilAt: nil)
        }

        // Severity rising (or equal) → snap to raw, clear cooldown.
        if isMoreSevere(rawLevel, than: floor) || rawLevel == floor {
            return Result(displayedLevel: rawLevel, newFloor: rawLevel, newUntilAt: nil)
        }

        // raw is LESS severe than floor (numeric raw > floor).
        // The cooldown anchor is the most recent article that still supports the
        // current floor (passed in as `evidenceAnchor`). Once that article ages
        // past `cooldown`, the floor starts stepping down. We take the EARLIER
        // of the stored `untilAt` and the evidence-based estimate so a stale
        // future-dated `untilAt` (left over from prior buggy logic or a fetch
        // that happened just before the supporting article rotated out) can't
        // pin the floor indefinitely.
        let evidenceUntil = evidenceAnchor?.addingTimeInterval(cooldown) ?? .distantPast
        let until: Date
        if let stored = state.untilAt {
            until = min(stored, evidenceUntil)
        } else {
            until = evidenceUntil
        }

        // Cooldown still active → hold.
        if now < until {
            return Result(displayedLevel: floor, newFloor: floor, newUntilAt: until)
        }

        // Cooldown expired → step floor toward raw (less severe). Catch up one
        // extra step per full cooldown period that has elapsed since `until`, so
        // the displayed level stays correct even if the app sat idle for hours
        // without a fetch tick.
        let extraSteps = max(0, Int(now.timeIntervalSince(until) / cooldown))
        var newFloor = floor + 1 + extraSteps
        var newUntil: Date? = now.addingTimeInterval(cooldown)
        if isMoreSevere(newFloor, than: rawLevel) || newFloor == rawLevel {
            if newFloor == rawLevel { newUntil = nil }
        } else {
            // overshot — clamp to raw.
            newFloor = rawLevel
            newUntil = nil
        }
        return Result(displayedLevel: newFloor, newFloor: newFloor, newUntilAt: newUntil)
    }

    // MARK: - Persistence

    static func read(context: ModelContext) -> State {
        let descriptor = FetchDescriptor<StickyLevelRecord>(predicate: #Predicate { $0.id == 1 })
        let row = (try? context.fetch(descriptor))?.first
        return State(floor: row?.floor, untilAt: row?.untilAt)
    }

    static func write(_ result: Result, context: ModelContext) {
        let descriptor = FetchDescriptor<StickyLevelRecord>(predicate: #Predicate { $0.id == 1 })
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.floor = result.newFloor
            existing.untilAt = result.newUntilAt
        } else {
            context.insert(StickyLevelRecord(id: 1, floor: result.newFloor, untilAt: result.newUntilAt))
        }
    }
}

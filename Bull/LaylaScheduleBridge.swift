import Foundation

/// The single atomic record shared by Layla and Bull. The envelope version owns the wire
/// format; `snapshot.sourceVersion` separately owns Layla's schedule semantics.
struct LaylaSleepScheduleTransportEnvelope: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var sequence: Int64
    var writtenTs: Double
    var writerBundleIdentifier: String
    var snapshot: LaylaSleepScheduleSnapshot
}

enum LaylaScheduleTransportFailure: String, Error, Equatable, Sendable {
    case unreadable
    case payloadTooLarge
    case malformedJSON
    case unsupportedSchema
    case invalidSequence
    case invalidWriter
    case invalidTimestamp
    case invalidSource
    case invalidTimeZone
    case invalidDayKey
    case invalidSchedule
    case invalidState

    var message: String {
        switch self {
        case .unreadable: return "The shared Layla update could not be read."
        case .payloadTooLarge: return "The shared Layla update is unexpectedly large."
        case .malformedJSON: return "The shared Layla update is incomplete or malformed."
        case .unsupportedSchema: return "Layla is using an unsupported sharing format."
        case .invalidSequence: return "The Layla update has an invalid ordering number."
        case .invalidWriter: return "The Layla update has no valid writer identity."
        case .invalidTimestamp: return "The Layla update contains an invalid timestamp."
        case .invalidSource: return "The shared update is not from the Layla schedule source."
        case .invalidTimeZone: return "The Layla update has no valid schedule time zone."
        case .invalidDayKey: return "The Layla update's date does not match its wake plan."
        case .invalidSchedule: return "The Layla wake and bedtime plan is not valid."
        case .invalidState: return "The Layla sleep state is missing required timing data."
        }
    }
}

enum LaylaScheduleBridgeReadResult: Equatable, Sendable {
    case available(LaylaSleepScheduleTransportEnvelope)
    case missing
    case appGroupUnavailable
    case invalid(LaylaScheduleTransportFailure)
}

struct LaylaScheduleBridgeStatus: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case notChecked
        case current
        case cachedCurrent
        case stale
        case missing
        case appGroupUnavailable
        case unavailableInTherapistRole
        case invalid
        case ignoredOlderUpdate
    }

    var state: State
    var checkedTs: Double?
    var sourceUpdatedTs: Double?
    var sourceVersion: Int?
    var sourceSequence: Int64?
    var sourceBundleIdentifier: String?
    var timeZoneIdentifier: String?
    var detail: String?

    static let notChecked = LaylaScheduleBridgeStatus(state: .notChecked)

    init(
        state: State,
        checkedTs: Double? = nil,
        sourceUpdatedTs: Double? = nil,
        sourceVersion: Int? = nil,
        sourceSequence: Int64? = nil,
        sourceBundleIdentifier: String? = nil,
        timeZoneIdentifier: String? = nil,
        detail: String? = nil
    ) {
        self.state = state
        self.checkedTs = checkedTs
        self.sourceUpdatedTs = sourceUpdatedTs
        self.sourceVersion = sourceVersion
        self.sourceSequence = sourceSequence
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
        self.detail = detail
    }

    var usesCurrentSchedule: Bool {
        state == .current || state == .cachedCurrent || state == .ignoredOlderUpdate
    }

    var message: String {
        switch state {
        case .notChecked:
            return "Bull has not checked for a Layla schedule yet."
        case .current:
            return "Bull is using the current Layla sleep schedule."
        case .cachedCurrent:
            return "Bull is using its last accepted Layla schedule; no shared update file is currently present."
        case .stale:
            return "The last Layla schedule is stale. Bull is using the fixed hours below."
        case .missing:
            return "No Layla schedule has been shared yet. Bull is using the fixed hours below."
        case .appGroupUnavailable:
            return "The shared App Group is unavailable. Confirm group.com.ahmed.Bull is enabled for Bull and Layla."
        case .unavailableInTherapistRole:
            return "Layla schedules are not read on a therapist-role installation."
        case .invalid:
            return detail ?? "Bull rejected an invalid Layla schedule and is using its last safe schedule."
        case .ignoredOlderUpdate:
            return "Bull ignored an older Layla replay and kept its newer accepted schedule."
        }
    }
}

/// Bull's read-only side of the Layla bridge. A file is used instead of several defaults
/// keys so readers can observe either the complete old record or the complete new record,
/// never a mixture of fields from two schedule states.
enum LaylaScheduleBridge {
    static let appGroupIdentifier = "group.com.ahmed.Bull"
    static let payloadFilename = "layla-bull-sleep-schedule-v1.json"
    static let schemaVersion = 1
    static let maximumFutureClockSkewMS: Double = 5 * 60_000
    static let maximumPlanSpanMS: Double = 36 * 3_600_000
    static let maximumPayloadBytes = 64 * 1_024

    static func readLatest(
        fileManager: FileManager = .default,
        now: Date = Date()
    ) -> LaylaScheduleBridgeReadResult {
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return .appGroupUnavailable
        }
        let url = container.appendingPathComponent(payloadFilename, isDirectory: false)
        guard fileManager.fileExists(atPath: url.path) else { return .missing }
        if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? NSNumber,
           size.intValue > maximumPayloadBytes {
            return .invalid(.payloadTooLarge)
        }
        let raw: Data
        do {
            raw = try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            return .invalid(.unreadable)
        }
        do {
            return .available(try validatedEnvelope(from: raw, now: now))
        } catch let failure as LaylaScheduleTransportFailure {
            return .invalid(failure)
        } catch {
            return .invalid(.malformedJSON)
        }
    }

    static func validatedEnvelope(
        from data: Data,
        now: Date = Date()
    ) throws -> LaylaSleepScheduleTransportEnvelope {
        guard data.count <= maximumPayloadBytes else {
            throw LaylaScheduleTransportFailure.payloadTooLarge
        }
        let envelope: LaylaSleepScheduleTransportEnvelope
        do {
            envelope = try JSONDecoder().decode(
                LaylaSleepScheduleTransportEnvelope.self,
                from: data
            )
        } catch {
            throw LaylaScheduleTransportFailure.malformedJSON
        }

        guard envelope.schemaVersion == schemaVersion else {
            throw LaylaScheduleTransportFailure.unsupportedSchema
        }
        guard envelope.sequence >= 1 else {
            throw LaylaScheduleTransportFailure.invalidSequence
        }
        let writer = envelope.writerBundleIdentifier.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !writer.isEmpty, writer.count <= 200 else {
            throw LaylaScheduleTransportFailure.invalidWriter
        }

        let snapshot = envelope.snapshot
        let nowMS = now.timeIntervalSince1970 * 1_000
        guard envelope.writtenTs.isFinite, envelope.writtenTs > 0,
              snapshot.updatedTs.isFinite, snapshot.updatedTs > 0,
              envelope.writtenTs <= nowMS + maximumFutureClockSkewMS,
              snapshot.updatedTs <= nowMS + maximumFutureClockSkewMS,
              snapshot.updatedTs <= envelope.writtenTs + maximumFutureClockSkewMS,
              snapshot.stateObservedTs.map({
                  $0.isFinite && $0 > 0 && $0 <= snapshot.updatedTs + maximumFutureClockSkewMS
              }) ?? true else {
            throw LaylaScheduleTransportFailure.invalidTimestamp
        }
        guard snapshot.sourceIdentifier == "layla", snapshot.sourceVersion >= 1,
              snapshot.sourceSequence == nil || snapshot.sourceSequence == envelope.sequence,
              snapshot.sourceBundleIdentifier == nil ||
                snapshot.sourceBundleIdentifier == writer else {
            throw LaylaScheduleTransportFailure.invalidSource
        }
        guard let timeZoneIdentifier = snapshot.timeZoneIdentifier,
              let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw LaylaScheduleTransportFailure.invalidTimeZone
        }
        guard snapshot.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              snapshot.dayKey == dayKey(
                forTimestampMS: snapshot.plannedFinalWakeTs,
                timeZone: timeZone
              ) else {
            throw LaylaScheduleTransportFailure.invalidDayKey
        }

        let earliestRelevantWake = snapshot.plannedFinalWakeTs - 12 * 3_600_000
        guard snapshot.plannedFinalWakeTs.isFinite, snapshot.plannedBedtimeTs.isFinite,
              snapshot.plannedFinalWakeTs > 0,
              snapshot.plannedBedtimeTs > snapshot.plannedFinalWakeTs,
              snapshot.plannedBedtimeTs - snapshot.plannedFinalWakeTs <= maximumPlanSpanMS,
              snapshot.actualFinalWakeTs.map({
                  $0.isFinite && $0 >= earliestRelevantWake &&
                      $0 <= snapshot.plannedBedtimeTs &&
                      $0 <= snapshot.updatedTs + maximumFutureClockSkewMS
              }) ?? true,
              snapshot.sleepConsistencyDeviationMinutes.map({
                  $0.isFinite && $0 >= 0 && $0 <= 720
              }) ?? true else {
            throw LaylaScheduleTransportFailure.invalidSchedule
        }
        if let observed = snapshot.stateObservedTs,
           !(observed >= earliestRelevantWake && observed <= snapshot.plannedBedtimeTs) {
            throw LaylaScheduleTransportFailure.invalidState
        }

        switch snapshot.state {
        case .sleeping:
            break
        case .plannedBriefWake:
            guard let observed = snapshot.stateObservedTs,
                  let deadline = snapshot.expectedReturnToSleepByTs,
                  deadline.isFinite,
                  deadline >= observed,
                  deadline <= snapshot.plannedFinalWakeTs else {
                throw LaylaScheduleTransportFailure.invalidState
            }
        case .upForDay, .unexpectedlyAwake:
            guard snapshot.actualFinalWakeTs != nil else {
                throw LaylaScheduleTransportFailure.invalidState
            }
        }

        var accepted = envelope
        accepted.snapshot.sourceSequence = envelope.sequence
        accepted.snapshot.sourceBundleIdentifier = writer
        return accepted
    }

    private static func dayKey(forTimestampMS timestamp: Double, timeZone: TimeZone) -> String {
        guard timestamp.isFinite else { return "" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = Date(timeIntervalSince1970: timestamp / 1_000)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }
}

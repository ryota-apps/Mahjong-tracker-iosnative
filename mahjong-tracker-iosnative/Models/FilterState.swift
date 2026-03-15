import Foundation
import Observation

// MARK: - FilterState
// Shared across HistoryView and AnalysisView via @Environment

@Observable
final class FilterState {
    var filterPlayers: Int? = nil
    var filterGameType: String? = nil
    var filterShop: String? = nil
    var filterRate: Int? = nil
    var withFees: Bool = true
    var dateRange: DateRangePreset = .all
    var sortOrder: HistorySortOrder = .newFirst
}

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - App Group ID

private let appGroupID = "group.com.ryota.mahjongtracker"

// MARK: - Timeline Entry

struct MahjongEntry: TimelineEntry {
    let date: Date
    let monthlyNet: Int
    let monthlySessionCount: Int
    let count1: Int
    let count2: Int
    let count3: Int
    let count4: Int

    static let placeholder = MahjongEntry(
        date: Date(),
        monthlyNet: 0,
        monthlySessionCount: 0,
        count1: 0, count2: 0, count3: 0, count4: 0
    )

    static let preview = MahjongEntry(
        date: Date(),
        monthlyNet: 15000,
        monthlySessionCount: 4,
        count1: 6, count2: 5, count3: 4, count4: 3
    )
}

// MARK: - Timeline Provider

struct MahjongProvider: TimelineProvider {
    func placeholder(in context: Context) -> MahjongEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (MahjongEntry) -> Void) {
        completion(context.isPreview ? .preview : (fetchEntry() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MahjongEntry>) -> Void) {
        let entry = fetchEntry() ?? .placeholder
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchEntry() -> MahjongEntry? {
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("mahjong.sqlite") else { return nil }

        guard FileManager.default.fileExists(atPath: groupURL.path) else { return nil }

        do {
            let config = ModelConfiguration(url: groupURL, allowsSave: false)
            let container = try ModelContainer(for: Schema([Session.self]), configurations: [config])
            let context = ModelContext(container)

            let cal = Calendar.current
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate { $0.date >= monthStart }
            )
            let sessions = try context.fetch(descriptor)

            return MahjongEntry(
                date: Date(),
                monthlyNet: sessions.reduce(0) { $0 + $1.net },
                monthlySessionCount: sessions.count,
                count1: sessions.reduce(0) { $0 + $1.count1 },
                count2: sessions.reduce(0) { $0 + $1.count2 },
                count3: sessions.reduce(0) { $0 + $1.count3 },
                count4: sessions.reduce(0) { $0 + $1.count4 }
            )
        } catch {
            return nil
        }
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: MahjongEntry

    private var netColor: Color {
        entry.monthlyNet >= 0 ? Color("AppTeal") : Color("AppRed")
    }

    private var signedNet: String {
        "\(entry.monthlyNet >= 0 ? "+" : "")\(entry.monthlyNet)円"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("今月の収支")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color("AppInk").opacity(0.5))

            Spacer()

            Text(signedNet)
                .font(.title2.weight(.bold))
                .foregroundStyle(netColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(Color("AppInk").opacity(0.4))
                Text("\(entry.monthlySessionCount)セッション")
                    .font(.caption2)
                    .foregroundStyle(Color("AppInk").opacity(0.6))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: MahjongEntry

    private var netColor: Color {
        entry.monthlyNet >= 0 ? Color("AppTeal") : Color("AppRed")
    }

    private var signedNet: String {
        "\(entry.monthlyNet >= 0 ? "+" : "")\(entry.monthlyNet)円"
    }

    private let placeColors: [Color] = [
        Color("Place1"), Color("Place2"), Color("Place3"), Color("Place4")
    ]
    private let placeLabels = ["1着", "2着", "3着", "4着"]
    private var placeCounts: [Int] {
        [entry.count1, entry.count2, entry.count3, entry.count4]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: net & sessions
            VStack(alignment: .leading, spacing: 6) {
                Text("今月の収支")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color("AppInk").opacity(0.5))

                Text(signedNet)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(netColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(Color("AppInk").opacity(0.4))
                    Text("\(entry.monthlySessionCount)セッション")
                        .font(.caption2)
                        .foregroundStyle(Color("AppInk").opacity(0.6))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color("AppInk").opacity(0.1))
                .frame(width: 0.5)
                .padding(.vertical, 12)

            // Right: place breakdown
            VStack(alignment: .leading, spacing: 7) {
                Text("着順内訳")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color("AppInk").opacity(0.5))

                ForEach(0..<4, id: \.self) { i in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(placeColors[i])
                            .frame(width: 7, height: 7)
                        Text(placeLabels[i])
                            .font(.caption2)
                            .foregroundStyle(Color("AppInk").opacity(0.6))
                        Spacer()
                        Text("\(placeCounts[i])")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("AppInk"))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Entry View

struct MahjongWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MahjongEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget

struct MahjongWidget: Widget {
    let kind = "MahjongWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MahjongProvider()) { entry in
            MahjongWidgetEntryView(entry: entry)
                .containerBackground(Color("AppPaper"), for: .widget)
        }
        .configurationDisplayName("麻雀成績")
        .description("今月の収支と着順内訳を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    MahjongWidget()
} timeline: {
    MahjongEntry.placeholder
    MahjongEntry.preview
}

#Preview("Medium", as: .systemMedium) {
    MahjongWidget()
} timeline: {
    MahjongEntry.placeholder
    MahjongEntry.preview
}

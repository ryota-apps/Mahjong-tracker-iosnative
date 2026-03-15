import SwiftUI
import SwiftData

// MARK: - HistoryView

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FilterState.self) private var filterState
    @Query(sort: \Session.createdAt, order: .reverse) private var allSessions: [Session]

    @State private var editingSession: Session? = nil
    @State private var deletingSession: Session? = nil
    @State private var showDuplicateToast = false

    // MARK: Computed

    private var uniqueShops: [String] {
        Array(Set(allSessions.map(\.shop))).sorted()
    }

    private var uniqueRates: [Int] {
        Array(Set(allSessions.map(\.rule))).sorted()
    }

    private var filteredSessions: [Session] {
        var result = applyDateFilter(Array(allSessions), preset: filterState.dateRange)
        if let p = filterState.filterPlayers { result = result.filter { $0.players == p } }
        if let gt = filterState.filterGameType { result = result.filter { $0.gameType == gt } }
        if let s = filterState.filterShop { result = result.filter { $0.shop == s } }
        if let r = filterState.filterRate { result = result.filter { $0.rule == r } }

        switch filterState.sortOrder {
        case .newFirst:    result.sort { $0.createdAt > $1.createdAt }
        case .oldFirst:    result.sort { $0.createdAt < $1.createdAt }
        case .balanceHigh: result.sort { getNet($0, withFees: filterState.withFees) > getNet($1, withFees: filterState.withFees) }
        case .balanceLow:  result.sort { getNet($0, withFees: filterState.withFees) < getNet($1, withFees: filterState.withFees) }
        }
        return result
    }

    private var filterKey: String {
        "\(filterState.dateRange.rawValue)-\(filterState.filterPlayers ?? -1)-\(filterState.filterGameType ?? "")-\(filterState.filterShop ?? "")-\(filterState.filterRate ?? -1)-\(filterState.sortOrder.rawValue)"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color("AppPaper").ignoresSafeArea()

                VStack(spacing: 0) {
                    headerTitle
                    filterBar
                    summaryBar

                    if filteredSessions.isEmpty {
                        emptyState
                    } else {
                        sessionList
                    }
                }

                if showDuplicateToast {
                    ToastView(message: "複製しました")
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut, value: showDuplicateToast)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $editingSession) { session in
            EditSessionSheet(session: session)
        }
        .alert("このセッションを削除しますか？", isPresented: Binding(
            get: { deletingSession != nil },
            set: { if !$0 { deletingSession = nil } }
        )) {
            Button("削除する", role: .destructive) {
                if let s = deletingSession { modelContext.delete(s) }
                deletingSession = nil
            }
            Button("キャンセル", role: .cancel) { deletingSession = nil }
        } message: {
            Text("この操作は取り消せません。")
        }
    }

    // MARK: Header

    private var headerTitle: some View {
        HStack {
            Text("戦績一覧")
                .font(.system(.title, design: .serif, weight: .bold))
                .foregroundStyle(Color("AppInk"))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DateRangePreset.allCases, id: \.self) { preset in
                    filterChip(preset.rawValue, active: filterState.dateRange == preset) {
                        filterState.dateRange = preset
                    }
                }

                chipDivider

                Menu {
                    Button("全人数") { filterState.filterPlayers = nil }
                    Button("3人") { filterState.filterPlayers = 3 }
                    Button("4人") { filterState.filterPlayers = 4 }
                } label: {
                    filterChipLabel(filterState.filterPlayers.map { "\($0)人" } ?? "人数",
                                    active: filterState.filterPlayers != nil)
                }

                Menu {
                    Button("全種別") { filterState.filterGameType = nil }
                    Button("フリー") { filterState.filterGameType = "free" }
                    Button("セット") { filterState.filterGameType = "set" }
                } label: {
                    filterChipLabel(gameTypeLabel(filterState.filterGameType),
                                    active: filterState.filterGameType != nil)
                }

                if !uniqueShops.isEmpty {
                    Menu {
                        Button("全店舗") { filterState.filterShop = nil }
                        ForEach(uniqueShops, id: \.self) { name in
                            Button(name) { filterState.filterShop = name }
                        }
                    } label: {
                        filterChipLabel(filterState.filterShop ?? "店舗",
                                        active: filterState.filterShop != nil)
                    }
                }

                if !uniqueRates.isEmpty {
                    Menu {
                        Button("全レート") { filterState.filterRate = nil }
                        ForEach(uniqueRates, id: \.self) { r in
                            Button(r == 0 ? "未設定" : "\(r)点") { filterState.filterRate = r }
                        }
                    } label: {
                        filterChipLabel(
                            filterState.filterRate.map { $0 == 0 ? "未設定" : "\($0)点" } ?? "レート",
                            active: filterState.filterRate != nil
                        )
                    }
                }

                chipDivider

                Button(action: { filterState.withFees.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: filterState.withFees ? "checkmark.square.fill" : "square")
                            .font(.caption)
                        Text(filterState.withFees ? "差し引く" : "差し引かない")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(filterState.withFees ? Color("AppInk") : Color("AppCream"))
                    .foregroundStyle(filterState.withFees ? Color("AppPaper") : Color("AppInk"))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color("AppInk").opacity(0.2), lineWidth: 1))
                }

                chipDivider

                Menu {
                    ForEach(HistorySortOrder.allCases, id: \.self) { order in
                        Button(order.rawValue) { filterState.sortOrder = order }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down").font(.caption)
                        Text(filterState.sortOrder.rawValue).font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color("AppCream"))
                    .foregroundStyle(Color("AppInk"))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color("AppInk").opacity(0.2), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color("AppPaper"))
    }

    private func filterChip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { filterChipLabel(label, active: active) }
    }

    private func filterChipLabel(_ label: String, active: Bool) -> some View {
        Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(active ? Color("AppInk") : Color("AppCream"))
            .foregroundStyle(active ? Color("AppPaper") : Color("AppInk"))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color("AppInk").opacity(0.2), lineWidth: 1))
    }

    private var chipDivider: some View {
        Rectangle()
            .fill(Color("AppInk").opacity(0.15))
            .frame(width: 1, height: 20)
    }

    // MARK: Summary bar

    private var summaryBar: some View {
        let sessions = filteredSessions
        let totalNet = sessions.reduce(0) { $0 + getNet($1, withFees: filterState.withFees) }
        let totalGames = sessions.reduce(0) { $0 + $1.totalGames }
        let avgPlace: Double = {
            guard totalGames > 0 else { return 0 }
            let w = sessions.reduce(0) { $0 + $1.count1*1 + $1.count2*2 + $1.count3*3 + $1.count4*4 }
            return Double(w) / Double(totalGames)
        }()
        let c1 = sessions.reduce(0) { $0 + $1.count1 }
        let c2 = sessions.reduce(0) { $0 + $1.count2 }
        let c3 = sessions.reduce(0) { $0 + $1.count3 }
        let c4 = sessions.reduce(0) { $0 + $1.count4 }
        let avgNet = sessions.isEmpty ? 0 : totalNet / sessions.count

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                summaryItem("セッション", value: "\(sessions.count)回")
                summaryItem("総ゲーム", value: "\(totalGames)局")
                summaryItem("平均着順", value: totalGames > 0 ? String(format: "%.2f", avgPlace) : "—")
                HStack(spacing: 6) {
                    placeCount(1, count: c1)
                    placeCount(2, count: c2)
                    placeCount(3, count: c3)
                    if sessions.contains(where: { $0.players == 4 }) {
                        placeCount(4, count: c4)
                    }
                }
                summaryItem("収支合計", value: signedYen(totalNet),
                            valueColor: totalNet >= 0 ? Color("AppTeal") : Color("AppRed"))
                summaryItem("平均収支", value: signedYen(avgNet),
                            valueColor: avgNet >= 0 ? Color("AppTeal") : Color("AppRed"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color("AppCream"))
        .overlay(Rectangle().fill(Color("AppInk").opacity(0.08)).frame(height: 1), alignment: .bottom)
    }

    private func summaryItem(_ label: String, value: String, valueColor: Color = Color("AppInk")) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(Color("AppInk").opacity(0.5))
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(valueColor)
        }
    }

    private func placeCount(_ place: Int, count: Int) -> some View {
        let colors: [Int: Color] = [1: Color("Place1"), 2: Color("Place2"), 3: Color("Place3"), 4: Color("Place4")]
        return HStack(spacing: 3) {
            Circle().fill(colors[place] ?? .gray).frame(width: 7, height: 7)
            Text("\(count)").font(.caption.weight(.medium)).foregroundStyle(Color("AppInk"))
        }
    }

    // MARK: Session list

    private var sessionList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredSessions) { session in
                    SessionCard(session: session, withFees: filterState.withFees,
                                onEdit: { editingSession = session },
                                onDelete: { deletingSession = session })
                        .id(session.id)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button { duplicate(session) } label: {
                                Label("複製", systemImage: "doc.on.doc")
                            }
                            .tint(Color("AppGold"))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deletingSession = session } label: {
                                Label("削除", systemImage: "trash")
                            }
                            Button { editingSession = session } label: {
                                Label("編集", systemImage: "pencil")
                            }
                            .tint(Color("AppTeal"))
                        }
                }
            }
            .listStyle(.plain)
            .background(Color("AppPaper"))
            .scrollContentBackground(.hidden)
            .onChange(of: filterKey) { _, _ in
                guard let firstID = filteredSessions.first?.id else { return }
                DispatchQueue.main.async {
                    withAnimation { proxy.scrollTo(firstID, anchor: .top) }
                }
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🀄").font(.system(size: 56))
            Text("記録がありません")
                .font(.headline).foregroundStyle(Color("AppInk").opacity(0.5))
            Text("フィルターを変更するか、新しいセッションを記録してください")
                .font(.caption).foregroundStyle(Color("AppInk").opacity(0.35))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: Actions

    private func duplicate(_ session: Session) {
        let copy = Session(
            shop: session.shop,
            date: Date(),
            players: session.players,
            format: session.format,
            rule: session.rule,
            gameType: session.gameType,
            count1: session.count1,
            count2: session.count2,
            count3: session.count3,
            count4: session.count4,
            balance: session.balance,
            chips: session.chips,
            chipUnit: session.chipUnit,
            chipVal: session.chipVal,
            venueFee: session.venueFee,
            net: session.net,
            gameFee: session.gameFee,
            topPrize: session.topPrize,
            note: session.note
        )
        modelContext.insert(copy)
        showDuplicateToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showDuplicateToast = false
        }
    }

    // MARK: Helpers

    private func gameTypeLabel(_ type: String?) -> String {
        switch type {
        case "free": return "フリー"
        case "set": return "セット"
        default: return "種別"
        }
    }
}

// MARK: - SessionCard

struct SessionCard: View {
    let session: Session
    let withFees: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var displayNet: Int { getNet(session, withFees: withFees) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            topRow
            bottomRow
        }
        .padding(14)
        .background(Color("AppCream"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color("AppInk").opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.shop.isEmpty ? "店舗未設定" : session.shop)
                    .font(.system(.callout, design: .serif, weight: .bold))
                    .foregroundStyle(Color("AppInk"))
                HStack(spacing: 6) {
                    Text(session.date, format: .dateTime.month().day())
                        .font(.caption).foregroundStyle(Color("AppInk").opacity(0.55))
                    metaTag("\(session.players)人")
                    metaTag(session.format)
                    if session.rule > 0 { metaTag("\(session.rule)点") }
                    gameTypeBadge
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(signedYen(displayNet))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(displayNet >= 0 ? Color("AppTeal") : Color("AppRed"))
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil").font(.caption)
                            .foregroundStyle(Color("AppInk").opacity(0.6))
                            .frame(width: 28, height: 28)
                            .background(Color("AppInk").opacity(0.07))
                            .clipShape(Circle())
                    }
                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.caption)
                            .foregroundStyle(Color("AppRed"))
                            .frame(width: 28, height: 28)
                            .background(Color("AppRed").opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var bottomRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                placeItem(1, count: session.count1)
                placeItem(2, count: session.count2)
                placeItem(3, count: session.count3)
                if session.players == 4 { placeItem(4, count: session.count4) }
                Spacer()
                Text("計\(session.totalGames)局")
                    .font(.caption).foregroundStyle(Color("AppInk").opacity(0.45))
            }
            let hasChip = session.chipVal != 0
            let hasVenueFee = session.venueFee > 0
            let hasMemo = !session.note.isEmpty
            if hasChip || hasVenueFee || hasMemo {
                HStack(spacing: 6) {
                    if hasChip {
                        infoBadge("チップ \(signedYen(session.chipVal))", color: Color("AppGold"))
                    }
                    if hasVenueFee {
                        infoBadge("場代 \(session.venueFee)円", color: Color("AppInk").opacity(0.5))
                    }
                    if hasMemo {
                        Text(session.note).font(.caption2)
                            .foregroundStyle(Color("AppInk").opacity(0.45)).lineLimit(1)
                    }
                }
            }
        }
    }

    private var gameTypeBadge: some View {
        let isFree = session.gameType == "free"
        return Text(isFree ? "フリー" : "セット")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(isFree ? Color("AppInk").opacity(0.1) : Color("AppTeal").opacity(0.15))
            .foregroundStyle(isFree ? Color("AppInk").opacity(0.6) : Color("AppTeal"))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func metaTag(_ text: String) -> some View {
        Text(text).font(.caption2).foregroundStyle(Color("AppInk").opacity(0.5))
    }

    private func placeItem(_ place: Int, count: Int) -> some View {
        let colors: [Int: Color] = [1: Color("Place1"), 2: Color("Place2"), 3: Color("Place3"), 4: Color("Place4")]
        return HStack(spacing: 4) {
            Circle().fill(colors[place] ?? .gray).frame(width: 8, height: 8)
            Text("\(count)").font(.subheadline.weight(.semibold)).foregroundStyle(Color("AppInk"))
        }
    }

    private func infoBadge(_ text: String, color: Color) -> some View {
        Text(text).font(.caption2.weight(.medium))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.12)).foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - EditSessionSheet

struct EditSessionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: Session

    @State private var date: Date
    @State private var shop: String
    @State private var count1: String
    @State private var count2: String
    @State private var count3: String
    @State private var count4: String
    @State private var balance: String
    @State private var chips: String
    @State private var note: String

    @FocusState private var focused: EditField?

    enum EditField: Hashable {
        case shop, count1, count2, count3, count4, balance, chips, note
    }

    init(session: Session) {
        self.session = session
        _date = State(initialValue: session.date)
        _shop = State(initialValue: session.shop)
        _count1 = State(initialValue: "\(session.count1)")
        _count2 = State(initialValue: "\(session.count2)")
        _count3 = State(initialValue: "\(session.count3)")
        _count4 = State(initialValue: "\(session.count4)")
        _balance = State(initialValue: "\(session.balance)")
        _chips = State(initialValue: "\(session.chips)")
        _note = State(initialValue: session.note)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppPaper").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        editCard("基本情報") {
                            rowDatePicker("日付", date: $date)
                            thinDivider
                            rowTextField("店舗名", placeholder: "店舗名を入力", text: $shop, field: .shop)
                        }
                        editCard("着順カウント") {
                            rowTextField("1着", placeholder: "0", text: $count1, field: .count1, keyboard: .numberPad)
                            thinDivider
                            rowTextField("2着", placeholder: "0", text: $count2, field: .count2, keyboard: .numberPad)
                            thinDivider
                            rowTextField("3着", placeholder: "0", text: $count3, field: .count3, keyboard: .numberPad)
                            if session.players == 4 {
                                thinDivider
                                rowTextField("4着", placeholder: "0", text: $count4, field: .count4, keyboard: .numberPad)
                            }
                        }
                        editCard("収支") {
                            rowTextField(
                                session.gameType == "free" ? "現金収支" : "点棒収支",
                                placeholder: "±0", text: $balance, field: .balance,
                                keyboard: .numbersAndPunctuation
                            )
                            thinDivider
                            rowTextField("チップ枚数", placeholder: "0", text: $chips, field: .chips, keyboard: .numberPad)
                        }
                        editCard("メモ") {
                            TextField("任意のメモを入力", text: $note, axis: .vertical)
                                .lineLimit(3...6).padding(14)
                                .foregroundStyle(Color("AppInk"))
                                .focused($focused, equals: .note)
                        }
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("セッション編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Color("AppInk"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveChanges() }
                        .foregroundStyle(Color("AppTeal")).fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focused = nil }.foregroundStyle(Color("AppTeal"))
                }
            }
        }
    }

    private func editCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption.weight(.semibold))
                .foregroundStyle(Color("AppInk").opacity(0.5))
                .padding(.horizontal, 20).padding(.bottom, 6)
            VStack(spacing: 0) { content() }
                .background(Color("AppCream"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("AppInk").opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 16)
        }
    }

    private func rowTextField(
        _ label: String, placeholder: String,
        text: Binding<String>, field: EditField,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(Color("AppInk"))
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(keyboard).multilineTextAlignment(.trailing)
                .foregroundStyle(Color("AppInk")).frame(width: 140)
                .focused($focused, equals: field)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func rowDatePicker(_ label: String, date: Binding<Date>) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(Color("AppInk"))
            Spacer()
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden().tint(Color("AppTeal"))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var thinDivider: some View {
        Rectangle().fill(Color("AppInk").opacity(0.1)).frame(height: 0.5).padding(.horizontal, 16)
    }

    private func saveChanges() {
        session.date = date
        session.shop = shop
        session.count1 = Int(count1) ?? session.count1
        session.count2 = Int(count2) ?? session.count2
        session.count3 = Int(count3) ?? session.count3
        session.count4 = Int(count4) ?? session.count4
        session.balance = Int(balance) ?? session.balance
        session.chips = Int(chips) ?? session.chips
        session.note = note
        session.chipVal = session.chips * session.chipUnit
        session.net = session.gameType == "free"
            ? session.balance + session.chipVal
            : session.balance + session.chipVal - session.venueFee
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .modelContainer(for: [Session.self, Shop.self], inMemory: true)
        .environment(FilterState())
}

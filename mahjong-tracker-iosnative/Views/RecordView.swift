import SwiftUI
import SwiftData

// MARK: - RecordView (root)

struct RecordView: View {
    @State private var isSessionActive = false
    @State private var sessionConfig: SessionConfig?
    @State private var showSavedToast = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if isSessionActive, let config = sessionConfig {
                SessionInputView(
                    config: config,
                    onDiscard: {
                        isSessionActive = false
                        sessionConfig = nil
                    },
                    onSaved: {
                        isSessionActive = false
                        sessionConfig = nil
                        showSavedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSavedToast = false
                        }
                    }
                )
                .transition(.move(edge: .trailing))
            } else {
                SetupView(onStart: { config in
                    sessionConfig = config
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSessionActive = true
                    }
                })
                .transition(.move(edge: .leading))
            }

            if showSavedToast {
                ToastView(message: "保存しました")
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: showSavedToast)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSessionActive)
    }
}

// MARK: - SessionConfig

struct SessionConfig {
    var date: Date
    var gameType: String
    var shopName: String
    var players: Int
    var format: String
    var rule: Int
    var chipUnit: Int
    var gameFee: Int
    var topPrize: Int
}

// MARK: - SetupView

struct SetupView: View {
    @Query(sort: \Shop.createdAt, order: .forward) private var shops: [Shop]

    @State private var selectedDate: Date = Date()
    @State private var selectedGameType: String = "free"
    @State private var shopName: String = ""
    @State private var selectedPlayers: Int = 4
    @State private var selectedFormat: String = "東南戦"
    @State private var selectedRule: Int = 0
    @State private var selectedShopPreset: Shop?

    let onStart: (SessionConfig) -> Void

    private let formatOptions = ["東南戦", "東風戦", "その他"]
    private let ruleOptions = Array(0...50)

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppPaper").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerTitle

                        cardSection("対戦情報") {
                            // 日付
                            HStack {
                                Label("日付", systemImage: "calendar")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppInk"))
                                Spacer()
                                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(Color("AppTeal"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            divider

                            // 種別
                            HStack(spacing: 0) {
                                gameTypeButton("フリー", value: "free")
                                gameTypeButton("セット", value: "set")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        cardSection("店舗") {
                            // プリセット（フリーのみ）
                            if selectedGameType == "free" && !shops.isEmpty {
                                HStack {
                                    Label("登録店舗", systemImage: "building.2")
                                        .font(.subheadline)
                                        .foregroundStyle(Color("AppInk"))
                                    Spacer()
                                    Picker("", selection: $selectedShopPreset) {
                                        Text("選択しない").tag(Shop?.none)
                                        ForEach(shops) { shop in
                                            Text(shop.name).tag(Shop?.some(shop))
                                        }
                                    }
                                    .tint(Color("AppTeal"))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .onChange(of: selectedShopPreset) { _, preset in
                                    applyPreset(preset)
                                }

                                divider
                            }

                            // 店舗名入力
                            HStack {
                                Label("店舗名", systemImage: "pencil")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppInk"))
                                Spacer()
                                TextField("店舗名を入力", text: $shopName)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(Color("AppInk"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        cardSection("ルール") {
                            // レート
                            HStack {
                                Label("レート", systemImage: "yensign.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppInk"))
                                Spacer()
                                Picker("", selection: $selectedRule) {
                                    Text("未設定").tag(0)
                                    ForEach(1...50, id: \.self) { v in
                                        Text("\(v)点").tag(v)
                                    }
                                }
                                .tint(Color("AppTeal"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            divider

                            // 人数
                            HStack {
                                Label("人数", systemImage: "person.2")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppInk"))
                                Spacer()
                                Picker("", selection: $selectedPlayers) {
                                    Text("3人").tag(3)
                                    Text("4人").tag(4)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            divider

                            // 戦型
                            HStack {
                                Label("戦型", systemImage: "flag")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppInk"))
                                Spacer()
                                Picker("", selection: $selectedFormat) {
                                    ForEach(formatOptions, id: \.self) { f in
                                        Text(f).tag(f)
                                    }
                                }
                                .tint(Color("AppTeal"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        // 開始ボタン
                        Button(action: startSession) {
                            Text("セッション開始")
                                .font(.headline)
                                .foregroundStyle(Color("AppPaper"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color("AppInk"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: Subviews

    private var headerTitle: some View {
        HStack {
            Text("記録する")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Color("AppInk"))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color("AppInk").opacity(0.1))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private func gameTypeButton(_ label: String, value: String) -> some View {
        Button(action: { selectedGameType = value }) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedGameType == value ? Color("AppInk") : Color.clear)
                .foregroundStyle(selectedGameType == value ? Color("AppPaper") : Color("AppInk"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(4)
    }

    // MARK: Helpers

    private func cardSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("AppInk").opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                content()
            }
            .background(Color("AppCream"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("AppInk").opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    private func applyPreset(_ shop: Shop?) {
        guard let shop else { return }
        shopName = shop.name
        selectedRule = shop.rule
        selectedPlayers = shop.players
        selectedFormat = shop.format
    }

    private func startSession() {
        let config = SessionConfig(
            date: selectedDate,
            gameType: selectedGameType,
            shopName: shopName,
            players: selectedPlayers,
            format: selectedFormat,
            rule: selectedRule,
            chipUnit: selectedShopPreset?.chipUnit ?? 0,
            gameFee: selectedShopPreset?.gameFee ?? 0,
            topPrize: selectedShopPreset?.topPrize ?? 0
        )
        onStart(config)
    }
}

// MARK: - SessionInputView

struct SessionInputView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedField: Field?

    let config: SessionConfig
    let onDiscard: () -> Void
    let onSaved: () -> Void

    @State private var counts: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0]
    @State private var balance: String = ""
    @State private var chips: String = ""
    @State private var chipUnitManual: String = ""
    @State private var venueFee: String = ""
    @State private var note: String = ""
    @State private var showDiscardAlert = false

    enum Field: Hashable {
        case balance, chips, chipUnit, venueFee, note
    }

    // MARK: Computed

    private var effectiveChipUnit: Int {
        if config.gameType == "free" {
            return config.chipUnit
        }
        return Int(chipUnitManual) ?? 0
    }

    private var chipVal: Int {
        (Int(chips) ?? 0) * effectiveChipUnit
    }

    private var netPreview: Int {
        let b = Int(balance) ?? 0
        let v = Int(venueFee) ?? 0
        if config.gameType == "free" {
            return b + chipVal
        } else {
            return b + chipVal - v
        }
    }

    private var totalGames: Int {
        counts.values.reduce(0, +)
    }

    private var placeColors: [Int: Color] {
        [1: Color("Place1"), 2: Color("Place2"), 3: Color("Place3"), 4: Color("Place4")]
    }

    private var placeLabels: [Int: String] {
        [1: "1着", 2: "2着", 3: "3着", 4: "4着"]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppPaper").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        sessionBar
                        countSection
                        balanceSection
                        noteSection
                        saveButton
                            .padding(.bottom, 32)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focusedField = nil }
                        .foregroundStyle(Color("AppTeal"))
                }
            }
            .alert("セッションを破棄しますか？", isPresented: $showDiscardAlert) {
                Button("破棄する", role: .destructive) { onDiscard() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("入力済みのデータは保存されません。")
            }
        }
    }

    // MARK: Session bar

    private var sessionBar: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(config.shopName.isEmpty ? "店舗未設定" : config.shopName)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Color("AppInk"))
                HStack(spacing: 6) {
                    Text(config.date, style: .date)
                    Text("·")
                    Text("\(config.players)人")
                    Text("·")
                    Text(config.format)
                    Text("·")
                    Text(config.gameType == "free" ? "フリー" : "セット")
                }
                .font(.caption)
                .foregroundStyle(Color("AppInk").opacity(0.6))
            }
            Spacer()
            Button(action: { showDiscardAlert = true }) {
                Text("終了・破棄")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color("AppRed"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("AppRed"), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color("AppCream"))
        .overlay(
            Rectangle()
                .fill(Color("AppInk").opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: Count section

    private var countSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("着順カウント")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("AppInk").opacity(0.5))
                Spacer()
                Text("合計 \(totalGames) ゲーム")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color("AppInk").opacity(0.5))
            }
            .padding(.horizontal, 20)

            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            let placesToShow = config.players == 3 ? [1, 2, 3] : [1, 2, 3, 4]

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(placesToShow, id: \.self) { place in
                    countCard(place: place)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func countCard(place: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(placeColors[place] ?? .gray)
                    .frame(width: 8, height: 8)
                Text(placeLabels[place] ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(placeColors[place] ?? .gray)
                Spacer()
            }

            Text("\(counts[place] ?? 0)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Color("AppInk"))
                .frame(height: 52)

            HStack(spacing: 16) {
                Button(action: { decrement(place) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color("AppRed"))
                        .clipShape(Circle())
                }

                Button(action: { increment(place) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color("AppPaper"))
                        .frame(width: 36, height: 36)
                        .background(Color("AppInk"))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(Color("AppCream"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("AppInk").opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: Balance section

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("収支入力")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("AppInk").opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                if config.gameType == "free" {
                    freeBalanceRows
                } else {
                    setBalanceRows
                }

                // 純収支プレビュー
                Rectangle()
                    .fill(Color("AppInk").opacity(0.1))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)

                HStack {
                    Text("純収支（プレビュー）")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("AppInk"))
                    Spacer()
                    Text(formatNet(netPreview))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(netPreview >= 0 ? Color("AppTeal") : Color("AppRed"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color("AppCream"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("AppInk").opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var freeBalanceRows: some View {
        numberInputRow(
            icon: "yensign.circle",
            label: "現金収支",
            placeholder: "±0",
            text: $balance,
            field: .balance
        )
        if config.chipUnit > 0 {
            thinDivider
            numberInputRow(
                icon: "square.stack",
                label: "チップ枚数",
                placeholder: "0",
                text: $chips,
                field: .chips
            )
            thinDivider
            HStack {
                Label("チップ収支", systemImage: "arrow.left.arrow.right")
                    .font(.subheadline)
                    .foregroundStyle(Color("AppInk"))
                Spacer()
                Text("\(chipVal > 0 ? "+" : "")\(chipVal)円")
                    .foregroundStyle(Color("AppInk").opacity(0.7))
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var setBalanceRows: some View {
        numberInputRow(
            icon: "chart.bar",
            label: "素点収支",
            placeholder: "±0",
            text: $balance,
            field: .balance
        )
        thinDivider
        numberInputRow(
            icon: "square.stack",
            label: "チップ枚数",
            placeholder: "0",
            text: $chips,
            field: .chips
        )
        thinDivider
        numberInputRow(
            icon: "tag",
            label: "チップ単価",
            placeholder: "0",
            text: $chipUnitManual,
            field: .chipUnit
        )
        thinDivider
        HStack {
            Label("チップ収支", systemImage: "arrow.left.arrow.right")
                .font(.subheadline)
                .foregroundStyle(Color("AppInk"))
            Spacer()
            Text("\(chipVal > 0 ? "+" : "")\(chipVal)円")
                .foregroundStyle(Color("AppInk").opacity(0.7))
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        thinDivider
        numberInputRow(
            icon: "building.columns",
            label: "場代",
            placeholder: "0",
            text: $venueFee,
            field: .venueFee
        )
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color("AppInk").opacity(0.1))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private func numberInputRow(
        icon: String,
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(Color("AppInk"))
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color("AppInk"))
                .frame(width: 120)
                .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Note section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("メモ")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("AppInk").opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            TextField("任意のメモを入力", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .padding(14)
                .foregroundStyle(Color("AppInk"))
                .focused($focusedField, equals: .note)
                .background(Color("AppCream"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("AppInk").opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 16)
        }
    }

    // MARK: Save button

    private var saveButton: some View {
        Button(action: save) {
            Text("保存する")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color("AppTeal"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
    }

    // MARK: Actions

    private func increment(_ place: Int) {
        counts[place, default: 0] += 1
    }

    private func decrement(_ place: Int) {
        let current = counts[place, default: 0]
        if current > 0 { counts[place] = current - 1 }
    }

    private func formatNet(_ value: Int) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(value)円"
    }

    private func save() {
        let balanceInt = Int(balance) ?? 0
        let chipsInt = Int(chips) ?? 0
        let venueFeeInt = Int(venueFee) ?? 0
        let resolvedChipUnit = config.gameType == "free" ? config.chipUnit : (Int(chipUnitManual) ?? 0)
        let chipValInt = chipsInt * resolvedChipUnit

        let session = Session(
            shop: config.shopName,
            date: config.date,
            players: config.players,
            format: config.format,
            rule: config.rule,
            gameType: config.gameType,
            count1: counts[1, default: 0],
            count2: counts[2, default: 0],
            count3: counts[3, default: 0],
            count4: counts[4, default: 0],
            balance: balanceInt,
            chips: chipsInt,
            chipUnit: resolvedChipUnit,
            chipVal: chipValInt,
            venueFee: venueFeeInt,
            net: netPreview,
            gameFee: config.gameFee,
            topPrize: config.topPrize,
            note: note
        )

        modelContext.insert(session)
        onSaved()
    }
}

// MARK: - ToastView

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color("AppInk").opacity(0.9))
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    RecordView()
        .modelContainer(for: [Session.self, Shop.self], inMemory: true)
}

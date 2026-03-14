import SwiftUI
import SwiftData

// MARK: - ShopsView

struct ShopsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Shop.createdAt, order: .forward) private var shops: [Shop]

    @State private var showSheet = false
    @State private var editingShop: Shop? = nil
    @State private var deletingShop: Shop? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppPaper").ignoresSafeArea()

                VStack(spacing: 0) {
                    headerTitle

                    if shops.isEmpty {
                        emptyState
                    } else {
                        shopList
                    }

                    addButton
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showSheet) {
            ShopFormSheet(editingShop: editingShop) {
                showSheet = false
                editingShop = nil
            }
        }
        .alert("この店舗を削除しますか？", isPresented: Binding(
            get: { deletingShop != nil },
            set: { if !$0 { deletingShop = nil } }
        )) {
            Button("削除する", role: .destructive) {
                if let s = deletingShop { modelContext.delete(s) }
                deletingShop = nil
            }
            Button("キャンセル", role: .cancel) { deletingShop = nil }
        } message: {
            Text("この操作は取り消せません。")
        }
    }

    // MARK: Header

    private var headerTitle: some View {
        HStack {
            Text("店舗設定")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Color("AppInk"))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: Shop list

    private var shopList: some View {
        List {
            ForEach(shops) { shop in
                ShopCard(
                    shop: shop,
                    onEdit: {
                        editingShop = shop
                        showSheet = true
                    },
                    onDelete: { deletingShop = shop }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deletingShop = shop
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                    Button {
                        editingShop = shop
                        showSheet = true
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    .tint(Color("AppTeal"))
                }
            }
        }
        .listStyle(.plain)
        .background(Color("AppPaper"))
        .scrollContentBackground(.hidden)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "building.2")
                .font(.system(size: 48))
                .foregroundStyle(Color("AppInk").opacity(0.15))
            Text("まだ店舗が登録されていません")
                .font(.headline)
                .foregroundStyle(Color("AppInk").opacity(0.4))
            Text("下のボタンから店舗を追加してください")
                .font(.caption)
                .foregroundStyle(Color("AppInk").opacity(0.3))
            Spacer()
        }
    }

    // MARK: Add button

    private var addButton: some View {
        Button(action: {
            editingShop = nil
            showSheet = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("新しい店舗を追加")
                    .font(.headline)
            }
            .foregroundStyle(Color("AppPaper"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color("AppInk"))
        }
    }
}

// MARK: - ShopCard

struct ShopCard: View {
    let shop: Shop
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            topRow
            metaRow
        }
        .padding(14)
        .background(Color("AppCream"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color("AppInk").opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            Text(shop.name.isEmpty ? "名称未設定" : shop.name)
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundStyle(Color("AppInk"))
            Spacer()
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(Color("AppInk").opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(Color("AppInk").opacity(0.07))
                        .clipShape(Circle())
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Color("AppRed"))
                        .frame(width: 28, height: 28)
                        .background(Color("AppRed").opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
    }

    private var metaRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Basic info tags
            HStack(spacing: 8) {
                infoBadge("\(shop.players)人", color: Color("AppInk").opacity(0.45))
                infoBadge(shop.format, color: Color("AppInk").opacity(0.45))
                infoBadge(shop.rule == 0 ? "レート未設定" : "\(shop.rule)点", color: Color("AppInk").opacity(0.45))
            }
            // Optional settings
            HStack(spacing: 8) {
                if shop.chipUnit > 0 {
                    infoBadge("チップ \(shop.chipUnit)円", color: Color("AppGold").opacity(0.8))
                }
                if shop.gameFee > 0 {
                    infoBadge("ゲーム代 \(shop.gameFee)円/局", color: Color("AppTeal").opacity(0.8))
                }
                if shop.topPrize > 0 {
                    infoBadge("トップ賞 \(shop.topPrize)円", color: Color("AppTeal").opacity(0.8))
                }
                if !shop.chipNote.isEmpty {
                    Text(shop.chipNote)
                        .font(.caption2)
                        .foregroundStyle(Color("AppInk").opacity(0.4))
                        .lineLimit(1)
                }
            }
        }
    }

    private func infoBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - ShopFormSheet

struct ShopFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedField: FormField?

    let editingShop: Shop?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var players: Int = 4
    @State private var format: String = "東南戦"
    @State private var rule: Int = 0
    @State private var chipUnit: Int = 0
    @State private var chipNote: String = ""
    @State private var gameFee: Int = 0
    @State private var topPrize: Int = 0

    // Raw string inputs for number fields
    @State private var chipUnitText: String = ""
    @State private var gameFeeText: String = ""
    @State private var topPrizeText: String = ""

    @State private var showValidationAlert = false

    enum FormField: Hashable {
        case name, chipUnit, chipNote, gameFee, topPrize
    }

    private let formatOptions = ["東南戦", "東風戦", "その他"]
    private var isEditing: Bool { editingShop != nil }

    init(editingShop: Shop?, onDismiss: @escaping () -> Void) {
        self.editingShop = editingShop
        self.onDismiss = onDismiss
        // Pre-populate @State from existing shop
        if let shop = editingShop {
            _name = State(initialValue: shop.name)
            _players = State(initialValue: shop.players)
            _format = State(initialValue: shop.format)
            _rule = State(initialValue: shop.rule)
            _chipUnit = State(initialValue: shop.chipUnit)
            _chipNote = State(initialValue: shop.chipNote)
            _gameFee = State(initialValue: shop.gameFee)
            _topPrize = State(initialValue: shop.topPrize)
            _chipUnitText = State(initialValue: shop.chipUnit > 0 ? "\(shop.chipUnit)" : "")
            _gameFeeText = State(initialValue: shop.gameFee > 0 ? "\(shop.gameFee)" : "")
            _topPrizeText = State(initialValue: shop.topPrize > 0 ? "\(shop.topPrize)" : "")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppPaper").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 基本情報
                        formSection("基本情報") {
                            // 店舗名
                            HStack {
                                Text("店舗名")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppInk"))
                                Spacer()
                                TextField("必須", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(Color("AppInk"))
                                    .focused($focusedField, equals: .name)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            thinDivider

                            // 人数
                            HStack {
                                Text("デフォルト人数")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppInk"))
                                Spacer()
                                Picker("", selection: $players) {
                                    Text("3人").tag(3)
                                    Text("4人").tag(4)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            thinDivider

                            // 戦型
                            HStack {
                                Text("デフォルト戦型")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppInk"))
                                Spacer()
                                Picker("", selection: $format) {
                                    ForEach(formatOptions, id: \.self) { f in
                                        Text(f).tag(f)
                                    }
                                }
                                .tint(Color("AppTeal"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            thinDivider

                            // レート
                            HStack {
                                Text("レート")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppInk"))
                                Spacer()
                                Picker("", selection: $rule) {
                                    Text("未設定").tag(0)
                                    ForEach(1...50, id: \.self) { v in
                                        Text("\(v)点").tag(v)
                                    }
                                }
                                .tint(Color("AppTeal"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        // チップ設定
                        formSection("チップ設定（任意）") {
                            numberRow(
                                label: "チップ単価",
                                placeholder: "0",
                                suffix: "円",
                                text: $chipUnitText,
                                field: .chipUnit
                            )
                            thinDivider
                            HStack {
                                Text("チップ種別メモ")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppInk"))
                                Spacer()
                                TextField("例: 赤5枚", text: $chipNote)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(Color("AppInk"))
                                    .focused($focusedField, equals: .chipNote)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        // ゲーム代・トップ賞
                        formSection("ゲーム代・トップ賞（任意）") {
                            numberRow(
                                label: "ゲーム代",
                                placeholder: "0",
                                suffix: "円/局",
                                text: $gameFeeText,
                                field: .gameFee
                            )
                            thinDivider
                            numberRow(
                                label: "トップ賞",
                                placeholder: "0",
                                suffix: "円/回",
                                text: $topPrizeText,
                                field: .topPrize
                            )
                        }

                        // 保存ボタン
                        Button(action: save) {
                            Text(isEditing ? "変更を保存" : "店舗を保存")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color("AppTeal"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(isEditing ? "店舗を編集" : "新しい店舗")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onDismiss() }
                        .foregroundStyle(Color("AppInk"))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focusedField = nil }
                        .foregroundStyle(Color("AppTeal"))
                }
            }
            .alert("入力エラー", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("店舗名を入力してください。")
            }
        }
    }

    // MARK: Subviews

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func numberRow(
        label: String,
        placeholder: String,
        suffix: String,
        text: Binding<String>,
        field: FormField
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color("AppInk"))
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color("AppInk"))
                .frame(width: 80)
                .focused($focusedField, equals: field)
            Text(suffix)
                .font(.caption)
                .foregroundStyle(Color("AppInk").opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color("AppInk").opacity(0.1))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    // MARK: Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            showValidationAlert = true
            return
        }

        let resolvedChipUnit = Int(chipUnitText) ?? 0
        let resolvedGameFee = Int(gameFeeText) ?? 0
        let resolvedTopPrize = Int(topPrizeText) ?? 0

        if let shop = editingShop {
            // Update existing
            shop.name = trimmedName
            shop.players = players
            shop.format = format
            shop.rule = rule
            shop.chipUnit = resolvedChipUnit
            shop.chipNote = chipNote
            shop.gameFee = resolvedGameFee
            shop.topPrize = resolvedTopPrize
        } else {
            // Create new
            let shop = Shop(
                name: trimmedName,
                players: players,
                format: format,
                rule: rule,
                chipUnit: resolvedChipUnit,
                chipNote: chipNote,
                gameFee: resolvedGameFee,
                topPrize: resolvedTopPrize
            )
            modelContext.insert(shop)
        }

        onDismiss()
    }
}

// MARK: - Preview

#Preview {
    ShopsView()
        .modelContainer(for: [Session.self, Shop.self], inMemory: true)
}

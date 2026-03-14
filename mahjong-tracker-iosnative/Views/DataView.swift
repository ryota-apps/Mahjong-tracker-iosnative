import SwiftUI
import SwiftData

// MARK: - DataView

struct DataView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [Session]
    @Query private var shops: [Shop]

    // Export state
    @State private var jsonShareItem: ShareItem? = nil
    @State private var csvShareItem: ShareItem? = nil

    // Import state
    @State private var showFileImporter = false

    // Delete state
    @State private var showDeleteAlert = false

    // Toast
    @State private var toastMessage: String = ""
    @State private var showToast = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color("AppPaper").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerTitle
                        exportSection
                        importSection
                        dataManagementSection
                        Spacer(minLength: 32)
                    }
                    .padding(.top, 8)
                }

                if showToast {
                    ToastView(message: toastMessage)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showToast)
            .navigationBarHidden(true)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .sheet(item: $jsonShareItem) { item in
            ShareSheet(url: item.url)
        }
        .sheet(item: $csvShareItem) { item in
            ShareSheet(url: item.url)
        }
        .alert("全データを削除しますか？", isPresented: $showDeleteAlert) {
            Button("削除する", role: .destructive) { deleteAll() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("全データを削除します。エクスポートしましたか？この操作は元に戻せません。")
        }
    }

    // MARK: Header

    private var headerTitle: some View {
        HStack {
            Text("データ")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Color("AppInk"))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: Section 1: Export

    private var exportSection: some View {
        dataCard("エクスポート") {
            VStack(alignment: .leading, spacing: 14) {
                Text("記録したデータをファイルとして保存します。定期的なバックアップを推奨します。")
                    .font(.caption)
                    .foregroundStyle(Color("AppInk").opacity(0.55))

                // JSON
                Button(action: exportJSON) {
                    HStack {
                        Text("📄")
                        Text("JSON（バックアップ）")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "arrow.up.circle")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color("AppTeal"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("AppTeal"), lineWidth: 1.5)
                    )
                }

                // CSV
                Button(action: exportCSV) {
                    HStack {
                        Text("📊")
                        Text("CSV（Excel用）")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "arrow.up.circle")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color("AppInk"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("AppInk"), lineWidth: 1.5)
                    )
                }

                Text("JSON → 再インポートして復元可能 ／ CSV → スプレッドシートで開けます")
                    .font(.caption2)
                    .foregroundStyle(Color("AppInk").opacity(0.4))
            }
            .padding(16)
        }
    }

    // MARK: Section 2: Import

    private var importSection: some View {
        dataCard("インポート（復元）") {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: { showFileImporter = true }) {
                    HStack {
                        Text("📂")
                        Text("ファイルを選択")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "folder")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color("AppInk"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("AppInk").opacity(0.4), lineWidth: 1.5)
                    )
                }

                HStack(alignment: .top, spacing: 6) {
                    Text("⚠️")
                        .font(.caption)
                    Text("インポートは現在のデータへの追加です（上書きではありません）。重複するIDのデータはスキップされます。")
                        .font(.caption)
                        .foregroundStyle(Color("AppInk").opacity(0.5))
                }
            }
            .padding(16)
        }
    }

    // MARK: Section 3: Data management

    private var dataManagementSection: some View {
        dataCard("データ管理") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("現在の記録数")
                        .font(.subheadline)
                        .foregroundStyle(Color("AppInk"))
                    Spacer()
                    Text("\(sessions.count) セッション")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("AppInk"))
                }

                Rectangle()
                    .fill(Color("AppInk").opacity(0.1))
                    .frame(height: 0.5)

                Button(action: {
                    if sessions.isEmpty {
                        showToast(message: "削除するデータがありません")
                    } else {
                        showDeleteAlert = true
                    }
                }) {
                    HStack {
                        Text("🗑️")
                        Text("すべてのデータを削除")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .foregroundStyle(Color("AppRed"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("AppRed"), lineWidth: 1.5)
                    )
                }

                HStack(alignment: .top, spacing: 6) {
                    Text("⚠️")
                        .font(.caption)
                    Text("削除は元に戻せません。事前にエクスポートを推奨します。")
                        .font(.caption)
                        .foregroundStyle(Color("AppInk").opacity(0.5))
                }
            }
            .padding(16)
        }
    }

    // MARK: Card container

    private func dataCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color("AppInk").opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 16)
        }
    }

    // MARK: Export actions

    private func exportJSON() {
        guard !sessions.isEmpty || !shops.isEmpty else {
            showToast(message: "エクスポートするデータがありません")
            return
        }
        do {
            let data = try ExportManager.makeJSONData(sessions: Array(sessions), shops: Array(shops))
            let url = try writeTempFile(data: data, filename: ExportManager.jsonFileName())
            jsonShareItem = ShareItem(url: url)
        } catch {
            showToast(message: "エクスポートに失敗しました")
        }
    }

    private func exportCSV() {
        guard !sessions.isEmpty else {
            showToast(message: "エクスポートするデータがありません")
            return
        }
        let data = ExportManager.makeCSVData(sessions: Array(sessions))
        do {
            let url = try writeTempFile(data: data, filename: ExportManager.csvFileName())
            csvShareItem = ShareItem(url: url)
        } catch {
            showToast(message: "エクスポートに失敗しました")
        }
    }

    private func writeTempFile(data: Data, filename: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    // MARK: Import action

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let (newSessions, newShops, importResult) = try ExportManager.importJSON(
                    from: url,
                    existingSessions: Array(sessions),
                    existingShops: Array(shops)
                )
                for s in newSessions {
                    let session = Session(
                        id: s.id, shop: s.shop, date: s.date, players: s.players,
                        format: s.format, rule: s.rule, gameType: s.gameType,
                        count1: s.count1, count2: s.count2, count3: s.count3, count4: s.count4,
                        balance: s.balance, chips: s.chips, chipUnit: s.chipUnit,
                        chipVal: s.chipVal, venueFee: s.venueFee, net: s.net,
                        gameFee: s.gameFee, topPrize: s.topPrize, note: s.note,
                        createdAt: s.createdAt
                    )
                    modelContext.insert(session)
                }
                for sh in newShops {
                    let shop = Shop(
                        id: sh.id, name: sh.name, players: sh.players,
                        format: sh.format, rule: sh.rule, chipUnit: sh.chipUnit,
                        chipNote: sh.chipNote, gameFee: sh.gameFee, topPrize: sh.topPrize
                    )
                    modelContext.insert(shop)
                }
                showToast(message: ExportManager.importMessage(importResult))
            } catch {
                showToast(message: "インポートに失敗しました")
            }
        case .failure:
            showToast(message: "ファイルの読み込みに失敗しました")
        }
    }

    // MARK: Delete all

    private func deleteAll() {
        for session in sessions { modelContext.delete(session) }
        showToast(message: "すべてのデータを削除しました")
    }

    // MARK: Toast helper

    private func showToast(message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}

// MARK: - ShareItem (Identifiable wrapper for sheet)

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - ShareSheet (UIActivityViewController bridge)

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    DataView()
        .modelContainer(for: [Session.self, Shop.self], inMemory: true)
}

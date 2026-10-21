import Charts
import SwiftUI

/// Charts, totals and the session list for a day, week, month or year.
struct HistoryView: View {
    @Environment(\.fileDialogs) private var fileDialogs
    @EnvironmentObject private var store: SessionStore
    @State private var query = HistoryQuery()
    @State private var showIncomplete = false
    @State private var selected: Session?
    @State private var confirmErase = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Range", selection: $query.range) {
                    ForEach(StatsRange.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.tabs)
                .testTarget("history.range", value: query.range.rawValue)
                .labelsHidden()
                totals
                    .testTarget("history.period", value: query.title)
                SummaryCard(sessions: filtered, periodName: query.title, tags: store.tags)
                    .id(query)
                chart
                sessionList
            }
            .padding(20)
        }
        .frame(minWidth: 600, minHeight: 640)
        .navigationTitle("History")
        .navigationSubtitle(query.title)
        .toolbar { toolbar }
        .sheet(item: $selected) { SessionDetailView(session: $0) }
        .alert("Erase all history?", isPresented: $confirmErase) {
            Button("Erase Everything", role: .destructive) { store.deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every recorded session will be deleted. This can't be undone.")
        }
    }

    private var filtered: [Session] { query.sessions(from: store.sessions) }

    private var completedFocus: [Session] {
        filtered.filter { $0.phase == .focus && $0.isCompleted }
    }

    // MARK: Views

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Previous", systemImage: "chevron.backward") { query.shift(by: -1) }
            Button("Next", systemImage: "chevron.forward") { query.shift(by: 1) }
                .disabled(!query.canMoveForward())
        }
        ToolbarItem(placement: .navigation) {
            Button("Today") { withAnimation(.smooth) { query.anchor = Date() } }
        }
        ToolbarSpacer(.flexible)
        ToolbarItem {
            Picker("Tag", selection: $query.filter) {
                Label("All Tags", systemImage: "tag").tag(TagFilter.all)
                Label("No Tag", systemImage: "tag.slash").tag(TagFilter.untagged)
                Divider()
                ForEach(store.tags) { Text($0.title).tag(TagFilter.tag($0.id)) }
            }
            .pickerStyle(.menu)
            .labelStyle(.titleAndIcon)
            .help("Filter by tag")
        }
        ToolbarSpacer(.fixed)
        ToolbarItem {
            Menu("More", systemImage: "ellipsis") {
                Button("Export as CSV…", systemImage: "square.and.arrow.up", action: exportCSV)
                Toggle("Show Unfinished Sessions", isOn: $showIncomplete)
                Divider()
                Button("Erase History…", systemImage: "trash", role: .destructive) { confirmErase = true }
            }
        }
    }

    private var totals: some View {
        let focusSessions = completedFocus
        let focused = focusSessions.reduce(0) { $0 + $1.focusedTime }
        let interruptions = filtered.filter { $0.phase == .focus }.reduce(0) { $0 + $1.interruptions.count }
        let breaks = filtered.filter { $0.phase.isBreak && $0.isCompleted }.count
        return HStack(spacing: 12) {
            statTile("Focus Sessions", "\(focusSessions.count)")
            statTile("Total Time", TimeFormat.hoursMinutes(focused))
            statTile("Breaks", "\(breaks)")
            statTile("Pauses", "\(interruptions)")
        }
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focused minutes").font(.caption).foregroundStyle(.secondary)
            let bars = query.focusBars(for: filtered) { store.tag(for: $0)?.title ?? "Untagged" }
            if bars.isEmpty {
                Text("Finish a focus session and your history will show up here.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart(bars) { bar in
                    BarMark(x: .value("Time", bar.date, unit: query.range.bucket),
                            y: .value("Minutes", bar.minutes))
                        .foregroundStyle(by: .value("Tag", bar.tag))
                        .cornerRadius(3)
                }
                .chartForegroundStyleScale(domain: tagDomain, range: tagColors)
                .chartXScale(domain: query.interval.start...query.interval.end)
                .frame(height: 200)
                .accessibilityLabel("Statistics chart")
            }
        }
    }

    private var tagDomain: [String] { store.tags.map(\.title) + ["Untagged"] }
    private var tagColors: [Color] { store.tags.map(\.color.color) + [Color.gray.opacity(0.6)] }

    private var sessionList: some View {
        let list = filtered
            .filter { showIncomplete || $0.isCompleted }
            .sorted { $0.startedAt > $1.startedAt }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Sessions").font(.headline)
            if list.isEmpty {
                Text("No Sessions Found").foregroundStyle(.secondary)
            }
            ForEach(list) { s in
                Button { selected = s } label: { SessionRow(session: s) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func exportCSV() {
        guard let url = fileDialogs.chooseCSVDestination(suggestedName: "Stint History.csv") else { return }
        try? store.csv(for: filtered).write(to: url, atomically: true, encoding: .utf8)
    }
}

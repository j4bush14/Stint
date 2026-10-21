import SwiftUI

/// One past session in the history list.
struct SessionRow: View {
    let session: Session
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(store.tag(for: session.tagID)?.color.color ?? .gray.opacity(0.5))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title.isEmpty ? session.phase.title : session.title)
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !session.isCompleted {
                Text("Not Completed").font(.caption).foregroundStyle(.orange)
            }
            if !session.interruptions.isEmpty {
                Label("\(session.interruptions.count)", systemImage: "pause.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(TimeFormat.hoursMinutes(session.focusedTime)).monospacedDigit()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}

/// Edit a past session's title and tag, or delete it.
struct SessionDetailView: View {
    @State var session: Session
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session Details").font(.title3.bold())
            Form {
                TextField("Title", text: $session.title)
                    .testTarget("session.title", value: session.title)
                Picker("Tag", selection: $session.tagID) {
                    Text("Untagged").tag(UUID?.none)
                    ForEach(store.tags) { Text($0.title).tag(Optional($0.id)) }
                }
                LabeledContent("Type", value: session.phase.title)
                LabeledContent("Started", value: session.startedAt.formatted(date: .abbreviated, time: .standard))
                LabeledContent("Completed",
                               value: session.completedAt?.formatted(date: .omitted, time: .standard) ?? "Not Completed")
                LabeledContent("Duration", value: TimeFormat.hoursMinutes(session.focusedTime))
                LabeledContent("Duration With Interruptions", value: TimeFormat.hoursMinutes(session.durationWithInterruptions))
                LabeledContent("Interruptions", value: "\(session.interruptions.count)")
            }
            .formStyle(.grouped)

            if !session.interruptions.isEmpty {
                Text("Interruptions").font(.headline)
                ForEach(Array(session.interruptions.enumerated()), id: \.offset) { _, i in
                    HStack {
                        Text("Stopped \(i.startedAt.formatted(date: .omitted, time: .standard))")
                        Spacer()
                        Text(i.finishedAt.map { "Resumed \($0.formatted(date: .omitted, time: .standard))" } ?? "—")
                    }
                    .font(.callout).foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Delete Session", role: .destructive) { confirmDelete = true }
                    .testTarget("session.delete")
                Spacer()
                Button("Cancel") { dismiss() }
                    .testTarget("session.cancel")
                Button("Save") { store.upsert(session); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .testTarget("session.save")
            }
        }
        .padding(20)
        .frame(width: 440)
        .alert("Delete this session?", isPresented: $confirmDelete) {
            Button("Delete Session", role: .destructive) { store.delete(session); dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

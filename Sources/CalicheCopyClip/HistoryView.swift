import SwiftUI

/// Caliche's signature colour, used for accents across the app.
extension Color {
    static let caliche = Color(red: 0.13, green: 0.70, blue: 0.35)
}

struct HistoryView: View {
    @ObservedObject var store: ClipStore
    var openSettings: () -> Void
    var close: () -> Void

    @State private var filter: ClipFilter = .all
    @State private var search = ""
    @State private var toast: String?
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 360, height: 480)
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.caliche, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.bottom, 48)
                    .transition(.opacity)
            }
        }
        .confirmationDialog("¿Borrar elementos?", isPresented: $confirmDelete) {
            Button("Borrar todo excepto favoritos") { store.deleteAll(keepBookmarks: true) }
            Button("Borrar todo", role: .destructive) { store.deleteAll(keepBookmarks: false) }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Caliche")
                    .font(.headline.weight(.heavy))
                    .foregroundColor(.caliche)
                + Text(" CopyClip").font(.headline)
                Spacer()
                Button(action: openSettings) { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless)
                    .help("Preferencias")
            }
            TextField("Buscar en lo que copió Caliche…", text: $search)
                .textFieldStyle(.roundedBorder)
            Picker("", selection: $filter) {
                ForEach(ClipFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(12)
    }

    @ViewBuilder
    private var list: some View {
        let clips = store.visibleClips(filter: filter, search: search)
        if clips.isEmpty {
            VStack(spacing: 6) {
                Spacer()
                Image(systemName: filter == .bookmarks ? "star" : "doc.on.clipboard")
                    .font(.largeTitle).foregroundStyle(Color.caliche)
                Text(filter == .bookmarks ? "¿Sin favoritos?" : "¿Nada copiado todavía?")
                    .font(.headline)
                Text(filter == .bookmarks
                     ? "Marca con la estrella lo que Caliche más usa."
                     : "Copia cualquier texto y aparecerá aquí para usarlo después.")
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(clips) { clip in
                        ClipRow(clip: clip,
                                onCopy: { copy(clip) },
                                onStar: { store.toggleBookmark(clip) },
                                onDelete: { store.delete(clip) })
                        Divider()
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Hecho con ♥ por Caliche")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Borrar…") { confirmDelete = true }
                .buttonStyle(.borderless)
                .disabled(store.clips.isEmpty)
            Button("Salir") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func copy(_ clip: Clip) {
        store.copyToPasteboard(clip)
        withAnimation { toast = "¡Listo para pegar, Caliche! ⌘V" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation { toast = nil }
            close()
        }
    }
}

private struct ClipRow: View {
    let clip: Clip
    let onCopy: () -> Void
    let onStar: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onStar) {
                Image(systemName: clip.isBookmark ? "star.fill" : "star")
                    .foregroundStyle(clip.isBookmark ? Color.caliche : .secondary)
            }
            .buttonStyle(.borderless)
            .help(clip.isBookmark ? "Quitar de favoritos" : "Agregar a favoritos")

            VStack(alignment: .leading, spacing: 3) {
                Text(clip.text.trimmingCharacters(in: .whitespacesAndNewlines))
                    .lineLimit(3)
                    .font(.system(.body))
                TimelineView(.everyMinute) { context in
                    HStack(spacing: 6) {
                        Text(timeAgo(clip.time, now: context.date))
                        if clip.count > 1 { Text("· copiado \(clip.count) veces") }
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if hovering {
                Button(action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Borrar")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(hovering ? Color.caliche.opacity(0.12) : .clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
        .onHover { hovering = $0 }
        .help("Clic para copiar")
    }
}

/// "hace 5 min", "hace 2 h": minutes, hours or days, never seconds.
private func timeAgo(_ date: Date, now: Date) -> String {
    let minutes = Int(now.timeIntervalSince(date) / 60)
    if minutes < 1 { return "hace un momento" }
    if minutes < 60 { return "hace \(minutes) min" }
    let hours = minutes / 60
    if hours < 24 { return "hace \(hours) h" }
    let days = hours / 24
    return days == 1 ? "hace 1 día" : "hace \(days) días"
}

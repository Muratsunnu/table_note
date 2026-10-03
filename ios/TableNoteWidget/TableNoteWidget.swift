import AppIntents
import SwiftUI
import UIKit
import WidgetKit

fileprivate struct WidgetMetric: Decodable {
    let id: String
    let label: String
    let value: String
}

/// One column of the grid the widget draws.
fileprivate struct WidgetColumn: Decodable {
    let label: String
    let numeric: Bool
    /// Set when this column is also one of the totals offered in the picker.
    let metricId: String?
}

fileprivate struct WidgetRow: Decodable {
    let text: String
    let values: [String: String]
    /// Aligned with the table's columns; absent in a snapshot from an older app.
    let cells: [String]?
    /// Aligned with `cells`; a tally tints its marks, a table never does.
    let colors: [Int?]?
    /// The colour the app writes a mark in, which is not the cell's own tint.
    let inks: [Int?]?
    /// Present only for a tally whose range covers today.
    let todayLabel: String?
    let todayColor: Int?

    static func color(_ argb: Int?) -> Color? {
        guard let argb else { return nil }
        let alpha = Double((argb >> 24) & 0xFF) / 255
        return Color(.sRGB,
                     red: Double((argb >> 16) & 0xFF) / 255,
                     green: Double((argb >> 8) & 0xFF) / 255,
                     blue: Double(argb & 0xFF) / 255,
                     opacity: alpha == 0 ? 1 : alpha)
    }
}

fileprivate struct WidgetTable: Decodable {
    let id: String
    let kind: String
    let tableId: String
    let name: String
    let count: Int
    let countText: String
    let typeText: String
    let metrics: [WidgetMetric]
    /// Optional so a snapshot written by an older app build still decodes.
    let rows: [WidgetRow]?
    let columns: [WidgetColumn]?
    let footer: [String]?
    /// Index of today's column in a tally, so it can be picked out.
    let todayColumn: Int?
    let countValue: String?
    let todayText: String?
    let todayMarked: String?
    /// The count with thousands separators, falling back to the plain number.
    var countLabel: String { countValue ?? String(count) }

    func url(add: Bool) -> URL? {
        var url = URLComponents()
        url.scheme = "com.muratstudio.tablenote"
        url.host = "widget"
        url.path = add ? "/add" : "/open"
        url.queryItems = [URLQueryItem(name: "kind", value: kind), URLQueryItem(name: "id", value: tableId)]
        return url.url
    }
}

fileprivate struct WidgetSnapshot: Decodable {
    let version: Int
    let language: String
    let dark: Bool
    let entries: [WidgetTable]
    let strings: [String: String]
    /// The app's colours. Absent in a snapshot written by an older build, so
    /// every lookup falls back to the shade the widget used before.
    let palette: [String: Int]?

    static func read() -> WidgetSnapshot {
        if let raw = UserDefaults(suiteName: "group.com.muratstudio.tablenote")?.string(forKey: "snapshot"),
           let data = raw.data(using: .utf8),
           let result = try? JSONDecoder().decode(WidgetSnapshot.self, from: data), result.version == 1 {
            return result
        }
        return WidgetSnapshot(version: 1, language: Locale.current.language.languageCode?.identifier ?? "en",
                              dark: false, entries: [], strings: [:], palette: nil)
    }

    func text(_ key: String, tr: String, en: String) -> String {
        strings[key] ?? (language == "en" ? en : tr)
    }

    /// One section per table: its name is the heading, its summaries are the rows.
    var sections: [IntentItemSection<String>] {
        entries.map { table in
            IntentItemSection(
                Self.label("\(table.typeText) · \(table.name)"),
                items: [IntentItem<String>(
                    table.id,
                    title: Self.label(text("countOnly", tr: "Yalnızca kayıt sayısı",
                                           en: "Record count only")),
                    subtitle: Self.label(table.countText))]
                    + table.metrics.map { metric in
                        IntentItem<String>(
                            Self.choiceID(table: table, metric: metric),
                            title: Self.label(metric.label),
                            subtitle: Self.label(text("total", tr: "Toplam", en: "Total")))
                    })
        }
    }

    /// One of the app's colours, or the given fallback when this snapshot
    /// predates the palette.
    func color(_ key: String, _ fallback: Color) -> Color {
        guard let argb = palette?[key] else { return fallback }
        return WidgetRow.color(argb) ?? fallback
    }

    /// Table and column names are user data, so they are shown as-is, never translated.
    static func label(_ value: String) -> LocalizedStringResource {
        LocalizedStringResource(stringLiteral: value)
    }

    static func choiceID(table: WidgetTable, metric: WidgetMetric) -> String {
        table.id + "|" + Data(metric.id.utf8).base64EncodedString()
    }

    func resolve(_ id: String) -> (WidgetTable, WidgetMetric?)? {
        for table in entries {
            if table.id == id { return (table, nil) }
            for metric in table.metrics where Self.choiceID(table: table, metric: metric) == id {
                return (table, metric)
            }
        }
        return nil
    }
}

/// A plain string option list. An AppEntity would need its identifier type registered
/// with AppIntents, which fails for a widget target that the app itself does not share.
struct WidgetSelectionOptions: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<String> {
        IntentItemCollection(sections: WidgetSnapshot.read().sections)
    }
}

struct TableNoteConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose table and summary"
    static var description = IntentDescription("Choose the table or tally to show on your home screen.")
    @Parameter(title: "Table and summary", optionsProvider: WidgetSelectionOptions())
    var selection: String?
}

struct TableNoteEntry: TimelineEntry {
    let date: Date
    fileprivate let snapshot: WidgetSnapshot
    fileprivate let table: WidgetTable?
    fileprivate let metric: WidgetMetric?
    let missing: Bool
}

struct TableNoteProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TableNoteEntry {
        TableNoteEntry(date: .now, snapshot: WidgetSnapshot.read(), table: nil, metric: nil, missing: false)
    }
    func snapshot(for configuration: TableNoteConfiguration, in context: Context) async -> TableNoteEntry {
        entry(configuration)
    }
    func timeline(for configuration: TableNoteConfiguration, in context: Context) async -> Timeline<TableNoteEntry> {
        // Only the app writes data. No network calls, periodic polling or writes from the extension.
        Timeline(entries: [entry(configuration)], policy: .never)
    }
    private func entry(_ configuration: TableNoteConfiguration) -> TableNoteEntry {
        let snapshot = WidgetSnapshot.read()
        let resolved = configuration.selection.flatMap { snapshot.resolve($0) }
        return TableNoteEntry(date: .now, snapshot: snapshot, table: resolved?.0, metric: resolved?.1,
                              missing: configuration.selection != nil && resolved == nil)
    }
}

struct TableNoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TableNoteEntry
    private var isLarge: Bool { family == .systemLarge }
    private var palette: WidgetSnapshot { entry.snapshot }
    private var foreground: Color {
        palette.color("text", entry.snapshot.dark ? .white : Color(red: 0.09, green: 0.15, blue: 0.33))
    }
    private var secondary: Color {
        palette.color("muted", entry.snapshot.dark ? Color(red: 0.68, green: 0.75, blue: 0.85) : .secondary)
    }
    private var line: Color { palette.color("line", secondary.opacity(0.22)) }
    private var accent: Color { palette.color("accent", .blue) }
    private var appURL: URL { URL(string: "com.muratstudio.tablenote://widget/open")! }

    var body: some View {
        // The grid sizes its own columns, so it has to know how much room it
        // has; the reader fills the widget, the same space the stack uses.
        GeometryReader { geometry in
        VStack(alignment: .leading, spacing: 8) {
            Link(destination: entry.table?.url(add: false) ?? appURL) {
                HStack {
                    Image(systemName: entry.table?.kind == "tally" ? "square.grid.3x3.fill" : "tablecells.fill")
                        .foregroundStyle(accent)
                    Text(entry.table?.name ?? "Table Note").font(.headline).lineLimit(1)
                    Spacer(minLength: 6)
                    // The large family gets a full summary line of its own.
                    if let table = entry.table, !isLarge {
                        Text(entry.metric?.value ?? table.countLabel)
                            .font(.subheadline.weight(.bold)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Image(systemName: "arrow.up.right").font(.caption2)
                }
                .foregroundStyle(foreground)
            }
            if let table = entry.table {
                let columns = gridColumns(table)
                if let rows = table.rows, !rows.isEmpty, !columns.isEmpty {
                    if isLarge { summaryLine(table: table) }
                    grid(table: table, columns: columns,
                         rows: Array(rows.prefix(isLarge ? 7 : 3)),
                         available: geometry.size.width)
                    if isLarge, let marked = table.todayMarked {
                        Text(marked).font(.caption2).foregroundStyle(secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    // No rows yet, or a snapshot from an older app build.
                    headline(table: table)
                    if isLarge {
                        Divider().overlay(secondary.opacity(0.35))
                        summaryList(table: table)
                    }
                }
                Spacer(minLength: 0)
                actionLink(table: table)
            } else {
                Text(entry.missing
                     ? entry.snapshot.text("missing", tr: "Seçim artık mevcut değil. Widget’ı düzenle.", en: "Selection no longer exists. Edit the widget.")
                     : entry.snapshot.text("choose", tr: "Tablo veya çetele seç", en: "Choose a table or tally"))
                    .font(.subheadline).foregroundStyle(secondary)
                Spacer(minLength: 0)
                Link(entry.snapshot.text("open", tr: "Uygulamayı aç", en: "Open app"), destination: appURL)
                    .font(.subheadline.weight(.semibold))
            }
        }
        }
        .widgetURL(entry.table?.url(add: false) ?? appURL)
        .privacySensitive()
        .containerBackground(for: .widget) {
            palette.color("background", entry.snapshot.dark
                ? Color(red: 0.09, green: 0.13, blue: 0.20)
                : Color(red: 0.95, green: 0.97, blue: 1))
        }
    }

    /// A column as the widget will draw it. `source` points into the row's
    /// cells; a column appended for the chosen total reads `metricId` instead.
    fileprivate struct GridColumn {
        let label: String
        let numeric: Bool
        let source: Int?
        let metricId: String?
    }

    /// The user's own leading columns, plus the total they picked when that
    /// column is not already among them. Narrow families show fewer.
    private func gridColumns(_ table: WidgetTable) -> [GridColumn] {
        guard let payload = table.columns, !payload.isEmpty else { return [] }
        let limit = isLarge ? 4 : 3
        var columns = payload.enumerated().map { index, column in
            GridColumn(label: column.label, numeric: column.numeric,
                       source: index, metricId: column.metricId)
        }
        // A tally is read from the right: the days closest to today are the
        // ones worth showing, so a narrow family drops the oldest, not today.
        // Day cells hold one or two characters, so more of them fit than the
        // table's wide columns; the budget below is not the table's `limit`.
        if table.kind == "tally" {
            return [columns[0]] + columns.dropFirst().suffix(isLarge ? 6 : 4)
        }
        if let metric = entry.metric,
           !columns.contains(where: { $0.metricId == metric.id }) {
            columns = Array(columns.prefix(limit - 1))
                + [GridColumn(label: metric.label, numeric: true, source: nil, metricId: metric.id)]
        }
        return Array(columns.prefix(limit))
    }

    private func value(_ row: WidgetRow, _ column: GridColumn) -> String {
        if let source = column.source {
            return source < (row.cells?.count ?? 0) ? row.cells![source] : ""
        }
        return column.metricId.flatMap { row.values[$0] } ?? ""
    }

    /// The colour a mark is written in: the app darkens or lightens the status
    /// colour so it stays readable, and sends the result as `inks`.
    private func ink(_ row: WidgetRow, _ column: GridColumn) -> Color? {
        guard let source = column.source else { return nil }
        if let inks = row.inks, source < inks.count,
           let ink = WidgetRow.color(inks[source]) {
            return ink
        }
        guard let colors = row.colors, source < colors.count else { return nil }
        return WidgetRow.color(colors[source])
    }

    /// What sits behind a cell: a marked day carries a wash of its own status
    /// colour, an unmarked one on today carries the tally's amber.
    private func fill(_ table: WidgetTable, _ row: WidgetRow, _ column: GridColumn) -> Color? {
        if let source = column.source, let colors = row.colors, source < colors.count,
           let status = WidgetRow.color(colors[source]) {
            return status.opacity(0.15)
        }
        return isToday(table, column) ? palette.color("todayCell", accent.opacity(0.12)) : nil
    }

    /// Day columns read as a block of marks, so they sit centred.
    private func alignment(_ table: WidgetTable, _ column: GridColumn, _ index: Int) -> Alignment {
        if column.numeric { return .trailing }
        return table.kind == "tally" && index > 0 ? .center : .leading
    }

    private func isToday(_ table: WidgetTable, _ column: GridColumn) -> Bool {
        table.todayColumn != nil && column.source == table.todayColumn
    }

    /// What the big number used to say, on one line above the table.
    private func summaryLine(table: WidgetTable) -> some View {
        let label = entry.metric.map { metric in
            table.kind == "tally"
                ? "\(entry.snapshot.text("total", tr: "Toplam", en: "Total")) · \(metric.label)"
                : metric.label
        } ?? table.countText
        return HStack(spacing: 6) {
            Text(label).font(.caption).lineLimit(1).foregroundStyle(secondary)
            Spacer(minLength: 6)
            Text(entry.metric?.value ?? table.countLabel)
                .font(.title3.weight(.bold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5).foregroundStyle(foreground)
        }
    }

    /// The table itself: a header row, the rows as they are on screen, and the
    /// totals row when the chosen columns have one.
    private static let headFont = UIFont.preferredFont(forTextStyle: .caption2)
    private static let bodyFont = UIFont.preferredFont(forTextStyle: .caption1)

    /// Measured bold, because the numeric cells are, and a column sized for
    /// regular text would clip them.
    private func textWidth(_ text: String, _ font: UIFont) -> CGFloat {
        if text.isEmpty { return 0 }
        let bold = UIFont(
            descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold) ?? font.fontDescriptor,
            size: font.pointSize)
        return ceil((text as NSString).size(withAttributes: [.font: bold]).width)
    }

    /// Column widths, decided here rather than by the layout system: SwiftUI
    /// shares leftover width out equally, which turns a one-letter tally mark
    /// into a wide gap and squeezes a number column next to a date column.
    ///
    /// Every column starts at the width its own content needs, capped, and the
    /// leftover is then handed out in proportion to those widths so the columns
    /// keep their relative weight. What no column can take stays as margin.
    private func columnWidths(table: WidgetTable, columns: [GridColumn],
                              rows: [WidgetRow], footer: [String]?,
                              available: CGFloat) -> [CGFloat] {
        let padding: CGFloat = 10
        let minimum: CGFloat = 26
        // A day holds one letter; letting it grow is exactly the gap to avoid.
        let dayMax: CGFloat = 34
        let wideMax = max(minimum, available * 0.45)
        let caps = columns.indices.map { index -> CGFloat in
            table.kind == "tally" && index > 0 ? dayMax : wideMax
        }

        var widths = columns.indices.map { index -> CGFloat in
            var needed = textWidth(columns[index].label, Self.headFont)
            for row in rows {
                needed = max(needed, textWidth(value(row, columns[index]), Self.bodyFont))
            }
            if let footer, index < footer.count {
                needed = max(needed, textWidth(footer[index], Self.bodyFont))
            }
            return min(caps[index], max(minimum, needed + padding))
        }

        let natural = widths.reduce(0, +)
        if natural > available {
            // Too much to show: shrink together, the text scales down the rest.
            let scale = available / natural
            return widths.map { max(minimum, $0 * scale) }
        }
        for _ in 0 ..< 3 {
            let slack = available - widths.reduce(0, +)
            if slack < 1 { break }
            let growable = widths.indices.filter { widths[$0] < caps[$0] - 0.5 }
            let base = growable.reduce(0) { $0 + widths[$1] }
            if growable.isEmpty || base <= 0 { break }
            for index in growable {
                widths[index] = min(caps[index], widths[index] + slack * widths[index] / base)
            }
        }
        return widths
    }

    private func grid(table: WidgetTable, columns: [GridColumn], rows: [WidgetRow],
                      available: CGFloat) -> some View {
        let footer = isLarge ? footerCells(table: table, columns: columns) : nil
        let widths = columnWidths(table: table, columns: columns, rows: rows,
                                  footer: footer, available: available)
        // The rules stop where the table stops; they never run into the margin.
        let tableWidth = widths.reduce(0, +)
        let header = palette.color("header", .clear)
        let onHeader = palette.color("onHeader", secondary)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                    Text(column.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(onHeader)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .modifier(Cell(width: widths[index],
                                       align: alignment(table, column, index),
                                       rule: index > 0, ruleColor: line,
                                       fill: isToday(table, column)
                                           ? palette.color("todayHeader", accent.opacity(0.35))
                                           : nil))
                }
            }
            .background(header)
            rule(tableWidth, line)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { position, column in
                        cell(value(row, column), ink: ink(row, column), strong: column.numeric)
                            .modifier(Cell(width: widths[position],
                                           align: alignment(table, column, position),
                                           rule: position > 0, ruleColor: line,
                                           fill: fill(table, row, column)))
                    }
                }
                // Same alternating rows as the table on screen.
                .background(palette.color(index.isMultiple(of: 2) ? "rowEven" : "rowOdd", .clear))
                .overlay(alignment: .bottom) { rule(tableWidth, line.opacity(0.6)) }
            }
            if let footer {
                HStack(spacing: 0) {
                    ForEach(Array(footer.enumerated()), id: \.offset) { index, text in
                        Text(text).font(.caption.weight(.bold)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .foregroundStyle(foreground)
                            .padding(.vertical, 4)
                            .modifier(Cell(width: widths[index],
                                           align: alignment(table, columns[index], index),
                                           rule: index > 0, ruleColor: line, fill: nil))
                    }
                }
                .background(header.opacity(0.55))
            }
        }
    }

    private func rule(_ width: CGFloat, _ color: Color) -> some View {
        Rectangle().fill(color).frame(width: width, height: 1)
    }

    /// A tally mark keeps its status colour; everything else is plain text.
    private func cell(_ text: String, ink: Color?, strong: Bool) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(strong ? .caption.weight(.semibold) : .caption)
            .monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(ink ?? foreground)
            .padding(.vertical, 4)
    }

    /// Mirrors the app's totals box: a total where the column has one, and the
    /// word "Toplam" in the first column when that one is not a number.
    private func footerCells(table: WidgetTable, columns: [GridColumn]) -> [String]? {
        guard table.kind == "table" else { return nil }
        var cells: [String] = []
        var hasTotal = false
        for column in columns {
            if let source = column.source, let footer = table.footer, source < footer.count {
                cells.append(footer[source])
                if column.numeric && !footer[source].isEmpty { hasTotal = true }
            } else if column.metricId != nil, let metric = entry.metric {
                cells.append(metric.value)
                hasTotal = true
            } else {
                cells.append("")
            }
        }
        guard hasTotal else { return nil }
        if !columns[0].numeric {
            cells[0] = entry.snapshot.text("total", tr: "Toplam", en: "Total")
        }
        return cells
    }

    /// The large family gets a full-width headline; the medium one keeps its single row.
    @ViewBuilder private func headline(table: WidgetTable) -> some View {
        // A bare status code says nothing, so a tally total names itself.
        let label = entry.metric.map { metric in
            table.kind == "tally"
                ? "\(entry.snapshot.text("total", tr: "Toplam", en: "Total")) · \(metric.label)"
                : metric.label
        } ?? table.typeText
        let value = entry.metric?.value ?? table.countLabel
        if isLarge {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.subheadline).lineLimit(1).foregroundStyle(secondary)
                Text(value)
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4).lineLimit(1).foregroundStyle(foreground)
            }
        } else {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(table.countText).font(.caption).foregroundStyle(secondary)
                    Text(label).font(.subheadline).lineLimit(1).foregroundStyle(secondary)
                }
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5).lineLimit(1).foregroundStyle(foreground)
            }
        }
    }

    /// Every summary this table offers - counts and totals only, never row contents.
    private func summaryList(table: WidgetTable) -> some View {
        VStack(spacing: 0) {
            summaryRow(table.kind == "tally"
                       ? entry.snapshot.text("itemCount", tr: "Öğe sayısı", en: "Items")
                       : entry.snapshot.text("recordCount", tr: "Kayıt sayısı", en: "Records"),
                       table.countLabel, highlighted: entry.metric == nil)
            ForEach(Array(table.metrics.prefix(6).enumerated()), id: \.offset) { _, metric in
                Divider().overlay(secondary.opacity(0.2))
                summaryRow(metric.label, metric.value, highlighted: metric.id == entry.metric?.id)
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String, highlighted: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.subheadline).lineLimit(1).foregroundStyle(secondary)
            Spacer(minLength: 8)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(highlighted ? Color.blue : foreground)
        }
        .padding(.vertical, 5)
    }

    private func actionLink(table: WidgetTable) -> some View {
        Link(destination: table.url(add: true) ?? appURL) {
            Text(table.kind == "tally"
                 ? entry.snapshot.text("addItem", tr: "+ Öğe ekle", en: "+ Add item")
                 : entry.snapshot.text("add", tr: "+ Kayıt ekle", en: "+ Add record"))
                .font(.subheadline.weight(.semibold)).lineLimit(1)
                .frame(maxWidth: .infinity).padding(.vertical, 7)
                .foregroundStyle(.white).background(Color.blue, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

/// One column of one row: its width, its alignment, the hairline that divides
/// it from the column on its left and whatever wash sits behind it. The rule is
/// an overlay, so it takes the cell's height instead of asking for one.
private struct Cell: ViewModifier {
    let width: CGFloat
    let align: Alignment
    let rule: Bool
    let ruleColor: Color
    let fill: Color?

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 5)
            .frame(width: width, alignment: align)
            .background(fill ?? .clear)
            .overlay(alignment: .leading) {
                if rule { Rectangle().fill(ruleColor).frame(width: 1) }
            }
    }
}

@main
struct TableNoteWidget: Widget {
    let kind = "TableNoteSummary"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TableNoteConfiguration.self, provider: TableNoteProvider()) {
            TableNoteWidgetView(entry: $0)
        }
        .configurationDisplayName("Table Note")
        .description("Table summaries and quick entry")
        // These families support independent links for opening and adding.
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

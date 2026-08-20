import SwiftUI
import WidgetKit

struct ClarityHomeWidget: Widget {
  let kind = "ClarityHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ClarityHomeWidgetProvider()) { entry in
      ClarityHomeWidgetView(entry: entry)
        .widgetBackground()
    }
    .configurationDisplayName("Clarity")
    .description("Cash and leftover this month")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct ClarityHomeWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> ClarityHomeWidgetEntry {
    ClarityHomeWidgetEntry.placeholder
  }

  func getSnapshot(in context: Context, completion: @escaping (ClarityHomeWidgetEntry) -> Void) {
    completion(ClarityHomeWidgetEntry.load())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ClarityHomeWidgetEntry>) -> Void) {
    let next = Date().addingTimeInterval(15 * 60)
    completion(
      Timeline(entries: [ClarityHomeWidgetEntry.load()], policy: .after(next))
    )
  }
}

struct ClarityHomeWidgetEntry: TimelineEntry {
  let date: Date
  let cashLabel: String
  let cashValue: String
  let leftLabel: String
  let leftValue: String
  let leftNegative: Bool
  let hasAccounts: Bool
  let emptyMessage: String

  static let placeholder = ClarityHomeWidgetEntry(
    date: Date(),
    cashLabel: "Cash",
    cashValue: "$0.00",
    leftLabel: "Left this month",
    leftValue: "$0.00",
    leftNegative: false,
    hasAccounts: true,
    emptyMessage: "Open Clarity and connect a bank to see cash and leftover."
  )

  static func load() -> ClarityHomeWidgetEntry {
    let defaults = UserDefaults(suiteName: "group.app.goclarity.clarity")
    func value(_ key: String) -> String {
      defaults?.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    return ClarityHomeWidgetEntry(
      date: Date(),
      cashLabel: value("clarity.widget.cashLabel"),
      cashValue: value("clarity.widget.cashValue"),
      leftLabel: value("clarity.widget.leftLabel"),
      leftValue: value("clarity.widget.leftValue"),
      leftNegative: value("clarity.widget.leftNegative") == "1",
      hasAccounts: value("clarity.widget.hasAccounts") == "1",
      emptyMessage: value("clarity.widget.emptyMessage")
    )
  }
}

struct ClarityHomeWidgetView: View {
  let entry: ClarityHomeWidgetEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    Group {
      if entry.hasAccounts, !entry.cashValue.isEmpty {
        amounts
      } else {
        emptyState
      }
    }
    .widgetURL(URL(string: "io.goclarity.clarity://overview"))
  }

  private var amounts: some View {
    VStack(alignment: .leading, spacing: family == .systemMedium ? 12 : 8) {
      Text("Clarity")
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color(red: 0, green: 0.84, blue: 0.75))
      if family == .systemMedium {
        HStack(alignment: .top, spacing: 16) {
          metric(entry.cashLabel, entry.cashValue, negative: false)
          metric(entry.leftLabel, entry.leftValue, negative: entry.leftNegative)
        }
      } else {
        metric(entry.cashLabel, entry.cashValue, negative: false)
        metric(entry.leftLabel, entry.leftValue, negative: entry.leftNegative)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Clarity")
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color(red: 0, green: 0.84, blue: 0.75))
      Text(
        entry.emptyMessage.isEmpty
          ? ClarityHomeWidgetEntry.placeholder.emptyMessage
          : entry.emptyMessage
      )
      .font(.caption)
      .foregroundStyle(Color(white: 0.7))
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func metric(_ label: String, _ value: String, negative: Bool) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption2)
        .foregroundStyle(Color(white: 0.62))
      Text(value)
        .font(.headline.weight(.bold))
        .foregroundStyle(
          negative
            ? Color(red: 1, green: 0.42, blue: 0.42)
            : Color(white: 0.97)
        )
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private extension View {
  @ViewBuilder
  func widgetBackground() -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(for: .widget) {
        Color.black
      }
    } else {
      background(Color.black)
    }
  }
}

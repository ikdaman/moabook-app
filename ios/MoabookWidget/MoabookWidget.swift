import SwiftUI
import WidgetKit

// MARK: - TimelineProvider

struct MoabookProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoabookEntry {
        MoabookEntry(date: Date(), books: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (MoabookEntry) -> Void) {
        completion(MoabookEntry(date: Date(), books: WidgetCache.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoabookEntry>) -> Void) {
        let entry = MoabookEntry(date: Date(), books: WidgetCache.read())
        // WidgetCenter.reloadAllTimelines() 가 Flutter publish 시 호출되므로 .never 정책 사용
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct MoabookEntry: TimelineEntry {
    let date: Date
    let books: [WidgetUiBook]
}

// MARK: - Widget

struct MoabookWidget: Widget {
    let kind: String = "MoabookWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoabookProvider()) { entry in
            if #available(iOS 17.0, *) {
                MoabookWidgetView(entry: entry)
                    .containerBackground(WidgetPalette.white.background, for: .widget)
            } else {
                MoabookWidgetView(entry: entry)
                    .padding()
                    .background(WidgetPalette.white.background)
            }
        }
        .configurationDisplayName("모아북")
        .description("읽고 싶은 책 모음")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Root view: switch by family

struct MoabookWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MoabookEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(books: entry.books)
        case .systemMedium:
            MediumWidgetView(books: entry.books)
        case .systemLarge:
            LargeWidgetView(books: entry.books)
        default:
            EmptyView()
        }
    }
}

// MARK: - Empty state

private struct EmptyStateView: View {
    let palette: WidgetPalette
    var body: some View {
        Text("읽고 싶은 책을 추가해 보세요 !")
            .font(.custom("DungGeunMo", size: 14))
            .foregroundColor(palette.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Small

private struct SmallWidgetView: View {
    let books: [WidgetUiBook]
    private let palette = WidgetPalette.white

    var body: some View {
        Group {
            if let book = books.first {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(palette.accent)
                            .font(.system(size: 18))
                        Spacer()
                    }
                    Spacer().frame(height: 10)
                    Text(book.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(palette.text)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    HStack {
                        Spacer()
                        Text(DateLabel.format(book.createdDate))
                            .font(.custom("DungGeunMo", size: 11))
                            .foregroundColor(palette.accent)
                    }
                }
                .widgetURL(URL(string: "moabookwidget://book?id=\(book.mybookId)"))
            } else {
                EmptyStateView(palette: palette)
                    .widgetURL(URL(string: "moabookwidget://home"))
            }
        }
    }
}

// MARK: - Medium

private struct MediumWidgetView: View {
    let books: [WidgetUiBook]
    private let palette = WidgetPalette.white

    var body: some View {
        Group {
            if let book = books.first {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(palette.accent)
                            .font(.system(size: 16))
                        Text(book.title)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(palette.text)
                            .lineLimit(1)
                    }
                    Spacer().frame(height: 12)
                    Text((book.reason?.isEmpty == false) ? book.reason! : "읽고 싶은 이유를 추가해 주세요.")
                        .font(.system(size: 12))
                        .foregroundColor(book.reason?.isEmpty == false ? palette.text : palette.dummyText)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    HStack {
                        Spacer()
                        Text(DateLabel.formatDisplay(book.createdDate))
                            .font(.custom("DungGeunMo", size: 12))
                            .foregroundColor(palette.accent)
                    }
                }
                .widgetURL(URL(string: "moabookwidget://book?id=\(book.mybookId)"))
            } else {
                EmptyStateView(palette: palette)
                    .widgetURL(URL(string: "moabookwidget://home"))
            }
        }
    }
}

// MARK: - Large

private struct LargeWidgetView: View {
    let books: [WidgetUiBook]
    private let palette = WidgetPalette.white

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BOOK NAME")
                .font(.custom("DungGeunMo", size: 20))
                .foregroundColor(palette.text)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0xD4/255, green: 0xD4/255, blue: 0xD4/255).opacity(0.3))

            if books.isEmpty {
                EmptyStateView(palette: palette)
                    .widgetURL(URL(string: "moabookwidget://home"))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(books.prefix(9)) { book in
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(palette.accent)
                                .font(.system(size: 12))
                            Text(book.title)
                                .font(.system(size: 14))
                                .foregroundColor(palette.text)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 30)
                    }
                }
                .padding(.top, 4)
                .widgetURL(URL(string: "moabookwidget://home"))
            }
            Spacer()
        }
    }
}

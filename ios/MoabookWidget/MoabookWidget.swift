import AppIntents
import SwiftUI
import WidgetKit

// MARK: - TimelineProvider

struct MoabookProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoabookEntry {
        MoabookEntry(date: Date(), books: [], mediumIndex: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoabookEntry) -> Void) {
        completion(MoabookEntry(date: Date(), books: WidgetCache.read(), mediumIndex: MediumPageStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoabookEntry>) -> Void) {
        let entry = MoabookEntry(date: Date(), books: WidgetCache.read(), mediumIndex: MediumPageStore.read())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct MoabookEntry: TimelineEntry {
    let date: Date
    let books: [WidgetUiBook]
    let mediumIndex: Int
}

// MARK: - Widget

struct MoabookWidget: Widget {
    let kind: String = "MoabookWidget"

    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: MoabookProvider()) { entry in
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

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

// MARK: - Root view

struct MoabookWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MoabookEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(books: entry.books)
                .padding(16)
        case .systemMedium:
            MediumWidgetView(books: entry.books, current: entry.mediumIndex)
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
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
                    HStack(alignment: .top) {
                        Image("ic_book_heart_navy")
                            .resizable()
                            .frame(width: 22, height: 22)
                        Spacer()
                        Link(destination: URL(string: "moabookwidget://refresh_small")!) {
                            Image("ic_widget_refresh_dark")
                                .resizable()
                                .frame(width: 14, height: 14)
                        }
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
    let current: Int
    private let palette = WidgetPalette.white

    var body: some View {
        Group {
            if books.isEmpty {
                EmptyStateView(palette: palette)
                    .widgetURL(URL(string: "moabookwidget://home"))
            } else {
                let safeIndex = max(0, min(current, books.count - 1))
                let book = books[safeIndex]
                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Image("ic_book_heart_navy")
                                .resizable()
                                .frame(width: 22, height: 22)
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
                        Text(DateLabel.formatDisplay(book.createdDate))
                            .font(.custom("DungGeunMo", size: 12))
                            .foregroundColor(palette.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if books.count > 1, #available(iOS 17.0, *) {
                        HStack(spacing: 6) {
                            Button(intent: MediumPagePrevIntent()) {
                                Text("이전")
                                    .font(.custom("DungGeunMo", size: 12))
                                    .foregroundColor(palette.accent)
                            }
                            .buttonStyle(.plain)
                            Text("|")
                                .font(.custom("DungGeunMo", size: 12))
                                .foregroundColor(palette.accent)
                            Button(intent: MediumPageNextIntent()) {
                                Text("다음")
                                    .font(.custom("DungGeunMo", size: 12))
                                    .foregroundColor(palette.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .widgetURL(URL(string: "moabookwidget://book?id=\(book.mybookId)"))
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
            // Edge-to-edge header — 외곽 패딩 없음, BOOK NAME 이 헤더에 박혀있음
            Text("BOOK NAME")
                .font(.custom("DungGeunMo", size: 20))
                .foregroundColor(palette.text)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0xD4/255, green: 0xD4/255, blue: 0xD4/255))

            if books.isEmpty {
                EmptyStateView(palette: palette)
                    .widgetURL(URL(string: "moabookwidget://home"))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(books.prefix(9)) { book in
                        HStack(spacing: 8) {
                            Image("ic_book_heart_navy")
                                .resizable()
                                .frame(width: 18, height: 18)
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

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - TimelineProvider

struct MoabookProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoabookEntry {
        MoabookEntry(date: Date(), books: [], mediumIndex: 0, smallCurrentMybookId: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoabookEntry) -> Void) {
        completion(MoabookEntry(
            date: Date(),
            books: WidgetCache.read(),
            mediumIndex: MediumPageStore.read(),
            smallCurrentMybookId: SmallCurrentStore.read()
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoabookEntry>) -> Void) {
        let entry = MoabookEntry(
            date: Date(),
            books: WidgetCache.read(),
            mediumIndex: MediumPageStore.read(),
            smallCurrentMybookId: SmallCurrentStore.read()
        )
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct MoabookEntry: TimelineEntry {
    let date: Date
    let books: [WidgetUiBook]
    let mediumIndex: Int
    let smallCurrentMybookId: Int
}

// MARK: - Widget kind 상수
// home_widget Flutter plugin 이 reloadTimelines(ofKind:) 호출 시 매칭 키.
// WidgetPublisher.dart 의 _iOSKinds 와 반드시 동일하게 유지.
enum MoabookWidgetKind {
    static let smallWhite  = "MoabookSmallWhite"
    static let smallBlue   = "MoabookSmallBlue"
    static let mediumWhite = "MoabookMediumWhite"
    static let mediumBlue  = "MoabookMediumBlue"
    static let large       = "MoabookLarge"
}

// MARK: - Widget configs (5 entries, Android 5개 receiver 와 1:1 매칭)

struct MoabookSmallWhiteWidget: Widget {
    var body: some WidgetConfiguration {
        moabookWidgetConfig(
            kind: MoabookWidgetKind.smallWhite,
            family: .systemSmall,
            palette: .white,
            displayName: "모아북 (작은 흰색)",
            description: "읽고 싶은 책 1권"
        )
    }
}

struct MoabookSmallBlueWidget: Widget {
    var body: some WidgetConfiguration {
        moabookWidgetConfig(
            kind: MoabookWidgetKind.smallBlue,
            family: .systemSmall,
            palette: .blue,
            displayName: "모아북 (작은 파랑)",
            description: "읽고 싶은 책 1권 — 진한 파랑"
        )
    }
}

struct MoabookMediumWhiteWidget: Widget {
    var body: some WidgetConfiguration {
        moabookWidgetConfig(
            kind: MoabookWidgetKind.mediumWhite,
            family: .systemMedium,
            palette: .white,
            displayName: "모아북 (중간 흰색)",
            description: "읽고 싶은 이유 표시"
        )
    }
}

struct MoabookMediumBlueWidget: Widget {
    var body: some WidgetConfiguration {
        moabookWidgetConfig(
            kind: MoabookWidgetKind.mediumBlue,
            family: .systemMedium,
            palette: .blue,
            displayName: "모아북 (중간 파랑)",
            description: "읽고 싶은 이유 표시 — 진한 파랑"
        )
    }
}

struct MoabookLargeWidget: Widget {
    var body: some WidgetConfiguration {
        moabookWidgetConfig(
            kind: MoabookWidgetKind.large,
            family: .systemLarge,
            palette: .white,
            displayName: "모아북 (큰 사이즈)",
            description: "최대 9권 목록"
        )
    }
}

// 공용 빌더 — kind/family/palette 만 다른 5개 Widget 의 중복 제거.
private func moabookWidgetConfig(
    kind: String,
    family: WidgetFamily,
    palette: WidgetPalette,
    displayName: LocalizedStringKey,
    description: LocalizedStringKey
) -> some WidgetConfiguration {
    let config = StaticConfiguration(kind: kind, provider: MoabookProvider()) { entry in
        if #available(iOS 17.0, *) {
            MoabookWidgetView(entry: entry, palette: palette)
                .containerBackground(palette.background, for: .widget)
        } else {
            MoabookWidgetView(entry: entry, palette: palette)
                .padding()
                .background(palette.background)
        }
    }
    .configurationDisplayName(displayName)
    .description(description)
    .supportedFamilies([family])

    if #available(iOS 17.0, *) {
        return config.contentMarginsDisabled()
    } else {
        return config
    }
}

// MARK: - Root view

struct MoabookWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MoabookEntry
    let palette: WidgetPalette

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(
                books: entry.books,
                currentMybookId: entry.smallCurrentMybookId,
                palette: palette
            )
            .padding(16)
        case .systemMedium:
            MediumWidgetView(books: entry.books, current: entry.mediumIndex, palette: palette)
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
        case .systemLarge:
            LargeWidgetView(books: entry.books, palette: palette)
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

// MARK: - Asset name 분기 (Blue 배경 = pure 흰색 아이콘, White 배경 = navy 아이콘)

private func bookHeartAsset(_ palette: WidgetPalette) -> String {
    palette.background == WidgetPalette.blue.background ? "ic_book_heart_pure" : "ic_book_heart_navy"
}

private func refreshAsset(_ palette: WidgetPalette) -> String {
    palette.background == WidgetPalette.blue.background ? "ic_widget_refresh_light" : "ic_widget_refresh_dark"
}

// MARK: - Small

private struct SmallWidgetView: View {
    let books: [WidgetUiBook]
    let currentMybookId: Int
    let palette: WidgetPalette

    private var currentBook: WidgetUiBook? {
        if currentMybookId != 0,
           let match = books.first(where: { $0.mybookId == currentMybookId }) {
            return match
        }
        return books.first
    }

    var body: some View {
        Group {
            if let book = currentBook {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Image(bookHeartAsset(palette))
                            .resizable()
                            .frame(width: 22, height: 22)
                        Spacer()
                        if #available(iOS 17.0, *) {
                            Button(intent: RefreshSmallIntent()) {
                                Image(refreshAsset(palette))
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                            .buttonStyle(.plain)
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
    let palette: WidgetPalette

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
                            Image(bookHeartAsset(palette))
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
    let palette: WidgetPalette

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
                            Image(bookHeartAsset(palette))
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

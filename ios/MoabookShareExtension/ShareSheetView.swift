// 공유 플로우 바텀시트 UI.
//
// Figma "2. 갤러리에서 추가(바텀시트)_260723" 3단계 + 오류 케이스.
// Flutter 쪽 share_import_sheet.dart 와 문구/구조를 맞춘다.

import SwiftUI

// Flutter AppColors 대응.
private enum Palette {
    static let primary = Color(red: 0x01 / 255, green: 0x01 / 255, blue: 0x96 / 255)
    static let textPrimary = Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255)
    static let textGray = Color(red: 0x99 / 255, green: 0x99 / 255, blue: 0x99 / 255)
    static let background = Color(red: 0xEB / 255, green: 0xEE / 255, blue: 0xF3 / 255)
}

private extension Font {
    static func dungGeunMo(_ size: CGFloat) -> Font { .custom("DungGeunMo", size: size) }
    static func wantedSans(_ size: CGFloat) -> Font { .custom("WantedSans-Regular", size: size) }
    static func wantedSansSemiBold(_ size: CGFloat) -> Font { .custom("WantedSans-SemiBold", size: size) }
}

struct ShareSheetView: View {
    @ObservedObject var model: ShareFlowModel
    let onClose: () -> Void
    let onOpenApp: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // 공유받은 사진 배경 + 검정 59% dim (Figma 디자인).
            if let image = model.sharedImage {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            }
            Color.black.opacity(0.59)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.init(top: 28, leading: 24, bottom: 16, trailing: 24))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Palette.background
                    .clipShape(RoundedCorners(radius: 30))
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .loading: loadingView
        case .pickBook: pickBookView
        case .saved: savedView
        case .error: errorView
        }
    }

    // ── Step 1: 검색 중 ───────────────────────────────────────────────────

    private var loadingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("일치하는 책을 검색 중이에요...")
            Spacer().frame(height: 72)
            HStack {
                Spacer()
                AnimatedGifView(name: "mascot_bounce")
                    .frame(width: 96, height: 96)
                Spacer()
            }
            Spacer().frame(height: 140)
        }
    }

    // ── Step 2: 책 선택 ───────────────────────────────────────────────────

    private var pickBookView: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("일치하는 책을 선택해주세요.")
            Spacer().frame(height: 12)
            Text("※ 사진에 텍스트가 많은 경우, 내가 찾는 책이 하단에 보일 수 있어요.")
                .font(.wantedSans(14))
                .foregroundColor(Palette.primary)
            Spacer().frame(height: 16)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.results) { book in
                        bookRow(book)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !model.isSaving { model.save(book) }
                            }
                    }
                }
            }
            .frame(maxHeight: 420)
        }
    }

    private func bookRow(_ book: AladinBook) -> some View {
        HStack(alignment: .top, spacing: 16) {
            coverImage(book.cover, width: 64, height: 90)
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.wantedSansSemiBold(16))
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(2)
                Text(book.author)
                    .font(.wantedSans(14))
                    .foregroundColor(Palette.textGray)
                    .lineLimit(1)
                Text(book.publisher)
                    .font(.wantedSans(14))
                    .foregroundColor(Palette.textGray)
                    .lineLimit(1)
            }
        }
    }

    // ── Step 3: 저장 완료 ─────────────────────────────────────────────────

    private var savedView: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("읽고 싶은 책이 저장되었어요!")
            Spacer().frame(height: 20)
            if let book = model.savedBook {
                HStack(alignment: .top, spacing: 16) {
                    coverImage(book.cover, width: 56, height: 80)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(book.title)
                            .font(.wantedSansSemiBold(16))
                            .foregroundColor(Palette.textPrimary)
                            .lineLimit(2)
                        Text(book.author)
                            .font(.wantedSans(14))
                            .foregroundColor(Palette.textGray)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.white)
            }
            Spacer().frame(height: 24)
            HStack {
                Spacer()
                primaryButton("저장한 책 보러가기", action: onOpenApp)
                Spacer()
            }
            Spacer().frame(height: 100)
        }
    }

    // ── 오류 ──────────────────────────────────────────────────────────────

    private var errorView: some View {
        let (titleText, guide): (String, String) = switch model.errorKind {
        case .imageFailed:
            ("이미지를 불러오지 못했어요.", "다른 사진으로 다시 시도해주세요.")
        case .noText:
            ("사진에서 글자를 찾지 못했어요.", "※ 책 제목이 명확하게 보이는 사진으로 다시 시도해주세요.")
        case .noResult:
            ("일치하는 책을 찾지 못했어요.", "※ 책 제목이 명확하게 보이는 사진으로 다시 시도해주세요.")
        case .network:
            ("문제가 발생했어요.", "네트워크 연결을 확인하고 다시 시도해주세요.")
        case .notLoggedIn:
            ("로그인이 필요해요.", "모아북 앱에서 로그인 후 다시 시도해주세요.")
        }

        return VStack(alignment: .leading, spacing: 0) {
            title(titleText)
            Spacer().frame(height: 12)
            Text(guide)
                .font(.wantedSans(14))
                .foregroundColor(Palette.primary)
            Spacer().frame(height: 32)
            HStack {
                Spacer()
                if model.errorKind == .notLoggedIn {
                    primaryButton("모아북 열기", action: onOpenApp)
                } else {
                    primaryButton("닫기", action: onClose)
                }
                Spacer()
            }
            Spacer().frame(height: 80)
        }
    }

    // ── 공용 ──────────────────────────────────────────────────────────────

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.dungGeunMo(18))
            .foregroundColor(Palette.textPrimary)
    }

    private func primaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.dungGeunMo(16))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Palette.primary)
        }
    }

    private func coverImage(_ url: String, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let imageUrl = URL(string: url), !url.isEmpty {
                AsyncImage(url: imageUrl) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        placeholderCover
                    }
                }
            } else {
                placeholderCover
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(4)
    }

    private var placeholderCover: some View {
        ZStack {
            Color(white: 0.9)
            Image(systemName: "book")
                .foregroundColor(Palette.textGray)
        }
    }
}

/// 상단 모서리만 둥근 배경.
private struct RoundedCorners: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: radius, height: radius)
            ).cgPath
        )
    }
}

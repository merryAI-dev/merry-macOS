import Foundation

enum PrintPreset: String, CaseIterable, Identifiable {
    case duplexColor
    case duplexMonochrome
    case twoUpColor
    case singleSidedColor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duplexColor:
            "양면 컬러"
        case .duplexMonochrome:
            "양면 흑백"
        case .twoUpColor:
            "한 장에 두 페이지"
        case .singleSidedColor:
            "단면 컬러"
        }
    }

    var detail: String {
        switch self {
        case .duplexColor:
            "보고서 기본 출력"
        case .duplexMonochrome:
            "양면 흑백으로 절약 출력"
        case .twoUpColor:
            "2-up 레이아웃 + 양면"
        case .singleSidedColor:
            "한 면씩 컬러 출력"
        }
    }

    var duplexMode: String {
        switch self {
        case .duplexColor, .duplexMonochrome, .twoUpColor:
            "long-edge"
        case .singleSidedColor:
            "one-sided"
        }
    }

    var optionPairs: [(String, String)] {
        switch self {
        case .duplexColor:
            [("CNColorMode", "color")]
        case .duplexMonochrome:
            [("CNColorMode", "mono")]
        case .twoUpColor:
            [("CNColorMode", "color"), ("number-up", "2")]
        case .singleSidedColor:
            [("CNColorMode", "color")]
        }
    }
}

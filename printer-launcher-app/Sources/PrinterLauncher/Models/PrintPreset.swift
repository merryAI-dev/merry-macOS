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
            "보고서/계약서 기본 출력"
        case .duplexMonochrome:
            "흑백 양면 절약 출력"
        case .twoUpColor:
            "2-up + 양면 출력"
        case .singleSidedColor:
            "한 장씩 컬러 출력"
        }
    }

    var symbolName: String {
        switch self {
        case .duplexColor:
            "doc.on.doc.fill"
        case .duplexMonochrome:
            "doc.text.fill"
        case .twoUpColor:
            "square.grid.2x2.fill"
        case .singleSidedColor:
            "doc.fill"
        }
    }

    var accentName: String {
        switch self {
        case .duplexColor:
            "blue"
        case .duplexMonochrome:
            "gray"
        case .twoUpColor:
            "orange"
        case .singleSidedColor:
            "green"
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

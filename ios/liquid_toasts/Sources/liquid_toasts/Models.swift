import Flutter
import SwiftUI
import UIKit

// MARK: - Enums (raw values mirror the Dart `.name` wire format)

enum ToastSemantic: String {
  case success, error, warning, info, none

  /// Default SF Symbol for this intent (nil for `.none`).
  var defaultSymbol: String? {
    switch self {
    case .success: return "checkmark.circle.fill"
    case .error: return "xmark.octagon.fill"
    case .warning: return "exclamationmark.triangle.fill"
    case .info: return "info.circle.fill"
    case .none: return nil
    }
  }

  /// Adaptive accent color (system colors auto-adapt to light/dark).
  var tint: Color {
    switch self {
    case .success: return .green
    case .error: return .red
    case .warning: return .orange
    case .info: return .blue
    case .none: return .secondary
    }
  }
}

enum ToastGlassIntent: String { case adaptive, liquid, frosted, solid, none }

enum ToastContentState: String { case `static`, loading }

enum ToastHapticKind: String { case none, success, warning, error, selection }

enum ToastSymbolEffect: String {
  case none, bounce, pulse, wiggle, rotate, breathe, variableColor, drawOn
}

enum ToastProgressStyle: String { case linear, circular }

enum ToastPositionModel: String {
  case topCenter, topLeading, topTrailing
  case center
  case bottomCenter, bottomLeading, bottomTrailing

  var isTop: Bool { self == .topCenter || self == .topLeading || self == .topTrailing }
  var isBottom: Bool { self == .bottomCenter || self == .bottomLeading || self == .bottomTrailing }

  var alignment: Alignment {
    switch self {
    case .topCenter: return .top
    case .topLeading: return .topLeading
    case .topTrailing: return .topTrailing
    case .center: return .center
    case .bottomCenter: return .bottom
    case .bottomLeading: return .bottomLeading
    case .bottomTrailing: return .bottomTrailing
    }
  }

  var horizontalAlignment: HorizontalAlignment {
    switch self {
    case .topLeading, .bottomLeading: return .leading
    case .topTrailing, .bottomTrailing: return .trailing
    default: return .center
    }
  }
}

enum ActionRole: String {
  case primary, secondary, destructive, success, warning, neutral

  var color: Color {
    switch self {
    case .primary: return .accentColor
    case .secondary: return .secondary
    case .destructive: return .red
    case .success: return .green
    case .warning: return .orange
    case .neutral: return Color.primary.opacity(0.7)
    }
  }
}

// MARK: - Color

extension Color {
  /// Builds a color from a 32-bit ARGB int (`0xAARRGGBB`), matching Flutter's
  /// `Color.toARGB32()`.
  init(argb: Int) {
    let a = Double((argb >> 24) & 0xFF) / 255.0
    let r = Double((argb >> 16) & 0xFF) / 255.0
    let g = Double((argb >> 8) & 0xFF) / 255.0
    let b = Double(argb & 0xFF) / 255.0
    self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
  }
}

/// A `{light, dark}` color pair decoded from the wire, resolved natively against
/// the current color scheme.
struct AdaptiveColor {
  let light: Color
  let dark: Color

  init?(_ value: Any?) {
    guard let map = value as? [String: Any],
          let l = map.int("light"),
          let d = map.int("dark") else { return nil }
    light = Color(argb: l)
    dark = Color(argb: d)
  }

  func resolved(_ scheme: ColorScheme) -> Color { scheme == .dark ? dark : light }
}

// MARK: - Style / Action models

struct ToastStyleModel {
  var tint: AdaptiveColor?
  var foreground: AdaptiveColor?
  var iconColor: AdaptiveColor?
  var glass: ToastGlassIntent?
  var cornerRadius: CGFloat?
  var symbolEffect: ToastSymbolEffect = .none

  init?(_ value: Any?) {
    guard let map = value as? [String: Any] else { return nil }
    tint = AdaptiveColor(map["tint"])
    foreground = AdaptiveColor(map["foreground"])
    iconColor = AdaptiveColor(map["iconColor"])
    glass = map.enumValue("glass")
    cornerRadius = map.cgFloat("cornerRadius")
    symbolEffect = map.enumValue("symbolEffect", default: .none)
  }
}

struct ToastActionModel {
  let actionId: String
  let label: String
  let role: ActionRole
  let color: AdaptiveColor?
  let dismissOnPress: Bool
  let loadingOnPress: Bool

  init?(_ value: Any?) {
    guard let map = value as? [String: Any],
          let actionId = map["actionId"] as? String,
          let label = map["label"] as? String else { return nil }
    self.actionId = actionId
    self.label = label
    self.role = map.enumValue("role", default: .primary)
    self.color = AdaptiveColor(map["color"])
    self.dismissOnPress = map.bool("dismissOnPress", default: true)
    self.loadingOnPress = map.bool("loadingOnPress", default: false)
  }
}

// MARK: - Toast model

struct ToastModel: Identifiable {
  let id: String
  var message: String
  var title: String?
  var icon: String?
  var image: UIImage?
  var semantic: ToastSemantic
  var style: ToastStyleModel?
  var position: ToastPositionModel
  var state: ToastContentState
  var persistent: Bool
  var durationMs: Int?
  var useDynamicIslandOrigin: Bool
  var progress: Double?
  var progressStyle: ToastProgressStyle
  var groupKey: String?
  var haptic: ToastHapticKind
  var semanticsLabel: String?
  var maxLines: Int
  var titleMaxLines: Int
  var tapToDismiss: Bool
  var hasTap: Bool
  var action: ToastActionModel?

  // Runtime-only
  var deadline: Date?

  init?(arguments: Any?) {
    guard let map = arguments as? [String: Any],
          let id = map["id"] as? String,
          let message = map["message"] as? String else { return nil }
    self.id = id
    self.message = message
    self.title = map["title"] as? String
    self.icon = map["icon"] as? String
    if let typed = map["image"] as? FlutterStandardTypedData {
      self.image = UIImage(data: typed.data)
    }
    self.semantic = map.enumValue("semantic", default: .none)
    self.style = ToastStyleModel(map["style"])
    self.position = map.enumValue("position", default: .topCenter)
    self.state = map.enumValue("state", default: .static)
    self.persistent = map.bool("persistent", default: false)
    self.durationMs = map.int("durationMs")
    self.useDynamicIslandOrigin = map.bool("useDynamicIslandOrigin", default: true)
    self.progress = map.double("progress")
    self.progressStyle = map.enumValue("progressStyle", default: .linear)
    self.groupKey = map["groupKey"] as? String
    self.haptic = map.enumValue("haptic", default: .none)
    self.semanticsLabel = map["semanticsLabel"] as? String
    self.maxLines = map.int("maxLines") ?? 1
    self.titleMaxLines = map.int("titleMaxLines") ?? 1
    self.tapToDismiss = map.bool("tapToDismiss", default: true)
    self.hasTap = map.bool("hasTap", default: false)
    self.action = ToastActionModel(map["action"])
  }

  /// Applies a fresh decode's content onto this toast, preserving identity so
  /// SwiftUI morphs the existing capsule instead of swapping it.
  mutating func applyContent(from other: ToastModel) {
    message = other.message
    title = other.title
    icon = other.icon
    image = other.image
    semantic = other.semantic
    style = other.style
    position = other.position
    state = other.state
    persistent = other.persistent
    durationMs = other.durationMs
    progress = other.progress
    progressStyle = other.progressStyle
    haptic = other.haptic
    semanticsLabel = other.semanticsLabel
    maxLines = other.maxLines
    titleMaxLines = other.titleMaxLines
    tapToDismiss = other.tapToDismiss
    hasTap = other.hasTap
    action = other.action
  }

  /// The SF Symbol to render: explicit icon wins, else the semantic default.
  var resolvedSymbol: String? {
    if let icon = icon, !icon.isEmpty { return icon }
    return semantic.defaultSymbol
  }

  /// Auto-dismiss interval, or nil when persistent / loading.
  var autoDuration: TimeInterval? {
    if persistent || state == .loading { return nil }
    let ms = durationMs ?? 3000
    let clamped = min(max(ms, 1500), 10000)
    return TimeInterval(clamped) / 1000.0
  }

  var accessibilityText: String {
    if let label = semanticsLabel, !label.isEmpty { return label }
    return [title, message].compactMap { $0 }.joined(separator: ", ")
  }
}

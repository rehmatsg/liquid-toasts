/// Value-level runtime capability checks.
///
/// NOTE: these are for *values* (wire strings, branching on data). Call sites
/// that USE availability-gated APIs (`glassEffect`, `.drawOn`, iOS 18 symbol
/// effects) must keep their `#if compiler(>=6.2)` / `if #available(...)`
/// blocks — the compiler requires syntactic availability there, and the
/// compiler guard keeps older-Xcode CocoaPods consumers building.
enum Capabilities {
  /// Whether the OS renders native Liquid Glass (iOS 26+).
  static var hasLiquidGlass: Bool {
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) { return true }
    #endif
    return false
  }

  /// The wire string advertised to Dart for the active glass implementation.
  static var glassModeString: String { hasLiquidGlass ? "liquidGlass" : "frosted" }
}

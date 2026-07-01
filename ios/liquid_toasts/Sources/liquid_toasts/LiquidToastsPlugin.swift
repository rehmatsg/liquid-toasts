import Flutter
import UIKit

/// Thin bridge between Flutter and the native overlay. Decodes method-channel
/// arguments into [ToastModel]s, drives [ToastManager], and streams lifecycle
/// events back over the event channel. Flutter invokes channel handlers on the
/// main thread, so UI is touched directly (no actor hop).
public class LiquidToastsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methods = FlutterMethodChannel(name: "liquid_toasts", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "liquid_toasts/events", binaryMessenger: registrar.messenger())
    let instance = LiquidToastsPlugin()
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
    // Install the (empty) overlay eagerly so SwiftUI has rendered the container
    // before the first `show` — otherwise the first toast appears as initial
    // content and skips its entrance transition.
    MainActor.assumeIsolated {
      ToastOverlayHost.shared.ensureInstalled()
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    MainActor.assumeIsolated {
      route(call, result: result)
    }
  }

  @MainActor
  private func route(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let host = ToastOverlayHost.shared
    let manager = host.manager
    // Keep the event sink wired to this plugin instance.
    manager.onEvent = { [weak self] payload in self?.eventSink?(payload) }

    let args = call.arguments as? [String: Any]

    switch call.method {
    case "handshake":
      // The Dart session prefix in the args is reserved wire data — native
      // flushes unconditionally on every handshake (fresh isolate = fresh UI).
      manager.flushAll()
      host.ensureInstalled()
      result(nil)

    case "configure":
      if let value = args?.int("maxVisible") { manager.maxVisible = max(1, value) }
      if let value = args?.int("maxQueue") { manager.maxQueue = max(1, value) }
      if let policy = args?["dropPolicy"] as? String { manager.dropOldest = policy != "dropNewest" }
      result(nil)

    case "show":
      host.ensureInstalled()
      guard let model = ToastModel(arguments: args) else {
        result(FlutterError(code: "INVALID_ARGS", message: "show: missing id/message", details: nil))
        return
      }
      manager.present(model)
      result([
        "id": model.id,
        "accepted": true,
        "capability": [
          "dynamicIslandOriginUsed": false,
          "glassMode": Capabilities.glassModeString,
        ],
      ])

    case "update":
      guard let id = args?["id"] as? String, let model = ToastModel(arguments: args) else {
        result(FlutterError(code: "INVALID_ARGS", message: "update: missing id/message", details: nil))
        return
      }
      let applied = manager.update(id: id, with: model)
      var res: [String: Any] = ["id": id, "applied": applied]
      if !applied { res["reason"] = "unknown_id" }
      result(res)

    case "dismiss":
      guard let id = args?["id"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "dismiss: missing id", details: nil))
        return
      }
      let ok = manager.dismiss(id: id, reason: "manual")
      var res: [String: Any] = ["id": id, "dismissed": ok]
      if !ok { res["reason"] = "unknown_id" }
      result(res)

    case "dismissAll":
      let reason = (args?["reason"] as? String) ?? "dismissAll"
      result(["dismissedIds": manager.dismissAll(reason: reason)])

    case "finishAction":
      if let id = args?["id"] as? String { manager.finishAction(id: id) }
      result(nil)

    case "debugTriggerAction":
      // Simulates an action-button tap (drives the spinner + lifecycle); used by
      // the example's async-action demo, which can't synthesize a real touch.
      if let id = args?["id"] as? String { manager.handleAction(id: id) }
      result(nil)

    case "queryGeometry":
      result(DynamicIslandGeometry.geometrySnapshot(ToastOverlayHost.activeWindow()))

    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - FlutterStreamHandler

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

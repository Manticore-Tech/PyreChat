import FirebaseCore
import FirebaseMessaging
import Flutter
import SCSDKCameraKit
import SCSDKCameraKitReferenceUI
import Security
import UIKit
import UserNotifications

private let pyreCameraKitChannelName = "dev.pyrearms.pyrechat/camera_kit"
private let pyreNotificationsChannelName = "dev.pyrearms.pyrechat/notifications"
private let pyreSecureSessionChannelName = "dev.pyrearms.pyrechat/secure_session"
private let pyreExternalLinksChannelName = "dev.pyrearms.pyrechat/external_links"
private let pyreCameraKitInternalEvalKey = "PyreCameraKitInternalEval"
private let pyreCameraKitTokenKey = "PyreCameraKitAPIToken"
private let pyreCameraKitGroupsKey = "PyreCameraKitLensGroupIDs"

private enum PyreSecureKeychain {
  private static let service =
    Bundle.main.bundleIdentifier ?? "dev.pyrearms.pyrechatFlutter"
  private static let tokenAccount = "session-token"

  static func readToken() -> String? {
    read(account: tokenAccount)
  }

  static func writeToken(_ token: String) -> Bool {
    write(account: tokenAccount, value: token)
  }

  static func deleteToken() {
    delete(account: tokenAccount)
  }

  static func readSecret(_ name: String) -> String? {
    read(account: secretAccount(name))
  }

  static func writeSecret(_ name: String, value: String) -> Bool {
    write(account: secretAccount(name), value: value)
  }

  static func deleteSecret(_ name: String) {
    delete(account: secretAccount(name))
  }

  private static func secretAccount(_ name: String) -> String {
    "secret:\(name)"
  }

  private static func baseQuery(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }

  private static func read(account: String) -> String? {
    var query = baseQuery(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private static func write(account: String, value: String) -> Bool {
    guard let data = value.data(using: .utf8) else { return false }

    let query = baseQuery(account: account)
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    let updateStatus = SecItemUpdate(
      query as CFDictionary,
      attributes as CFDictionary
    )
    if updateStatus == errSecSuccess {
      return true
    }
    guard updateStatus == errSecItemNotFound else {
      return false
    }

    var item = query
    for (key, value) in attributes {
      item[key] = value
    }
    return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
  }

  private static func delete(account: String) {
    let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      return
    }
  }
}

private struct PyreCameraKitConfiguration {
  let apiToken: String
  let lensGroupIDs: [String]

  static func load() -> PyreCameraKitConfiguration? {
    guard
      resolvedBool(for: pyreCameraKitInternalEvalKey),
      let apiToken = resolvedString(for: pyreCameraKitTokenKey),
      let groupsString = resolvedString(for: pyreCameraKitGroupsKey)
    else {
      return nil
    }

    let groups = groupsString
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !groups.isEmpty else { return nil }
    return PyreCameraKitConfiguration(apiToken: apiToken, lensGroupIDs: groups)
  }

  private static func resolvedBool(for key: String) -> Bool {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: key) else {
      return false
    }
    if let boolValue = raw as? Bool {
      return boolValue
    }
    let value = String(describing: raw)
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    return value == "true" || value == "1" || value == "yes"
  }

  private static func resolvedString(for key: String) -> String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return nil
    }

    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      !value.isEmpty,
      !value.contains("$("),
      !value.contains("REPLACE-THIS")
    else {
      return nil
    }
    return value
  }
}

private final class PyreCameraCaptureBridge: NSObject, CameraButtonDelegate {
  weak var owner: PyreCameraKitViewController?
  private var recording = false

  init(owner: PyreCameraKitViewController) {
    self.owner = owner
  }

  func cameraButtonTapped(_ cameraButton: CameraButton) {
    guard !recording, let owner else { return }

    owner.cameraController.takePhoto { [weak owner] image, error in
      if let error {
        owner?.finishFailure(error.localizedDescription)
        return
      }
      guard let image, let data = image.jpegData(compressionQuality: 0.94) else {
        owner?.finishFailure("Camera Kit did not return a photo.")
        return
      }

      do {
        let url = FileManager.default.temporaryDirectory
          .appendingPathComponent("pyre-camerakit-\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        owner?.finishCapture(url: url, kind: "image")
      } catch {
        owner?.finishFailure("Could not save the Camera Kit photo: \(error.localizedDescription)")
      }
    }
  }

  func cameraButtonHoldBegan(_ cameraButton: CameraButton) {
    guard !recording, let owner else { return }
    recording = true
    owner.cameraController.startRecording()
    owner.cameraView.hideAllControls()
    owner.cameraView.carouselView.hideCarousel()
    owner.cameraView.cameraActionsView.collapse()
  }

  func cameraButtonHoldCancelled(_ cameraButton: CameraButton) {
    guard recording, let owner else { return }
    recording = false
    owner.cameraController.cancelRecording()
    restoreCameraUI(owner)
  }

  func cameraButtonHoldEnded(_ cameraButton: CameraButton) {
    guard recording, let owner else { return }
    recording = false

    owner.cameraController.finishRecording { [weak owner] url, error in
      if let error {
        owner?.finishFailure(error.localizedDescription)
        return
      }
      guard let url else {
        owner?.finishFailure("Camera Kit did not return a video.")
        return
      }
      owner?.finishCapture(url: url, kind: "video")
    }
  }

  func cancelIfNeeded() {
    guard recording, let owner else { return }
    recording = false
    owner.cameraController.cancelRecording()
  }

  private func restoreCameraUI(_ owner: PyreCameraKitViewController) {
    DispatchQueue.main.async {
      owner.cameraView.cameraActionsView.expand()
      owner.cameraView.carouselView.showCarousel()
    }
  }
}

private final class PyreCameraKitViewController: CameraViewController {
  var onResult: (([String: String]?) -> Void)?
  var onFailure: ((String) -> Void)?

  private var finished = false
  private lazy var captureBridge = PyreCameraCaptureBridge(owner: self)

  override func viewDidLoad() {
    super.viewDidLoad()

    // Camera Kit owns Lens rendering/capture only. PyreChat owns review and sending,
    // so replace the Reference UI preview handoff with a file-return bridge.
    cameraView.cameraButton.delegate = captureBridge

    let closeButton = UIButton(type: .system)
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    closeButton.tintColor = .white
    closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.34)
    closeButton.layer.cornerRadius = 20
    closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
    closeButton.accessibilityLabel = "Close Camera Kit"
    closeButton.addTarget(self, action: #selector(closeCameraKit), for: .touchUpInside)

    view.addSubview(closeButton)
    NSLayoutConstraint.activate([
      closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
      closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
      closeButton.widthAnchor.constraint(equalToConstant: 40),
      closeButton.heightAnchor.constraint(equalToConstant: 40),
    ])
  }

  @objc private func closeCameraKit() {
    guard !finished else { return }
    finished = true
    captureBridge.cancelIfNeeded()
    dismiss(animated: true) { [weak self] in
      self?.onResult?(nil)
    }
  }

  func finishCapture(url: URL, kind: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self, !self.finished else { return }
      self.finished = true
      self.cameraController.restoreBrightnessIfNecessary()
      self.dismiss(animated: false) { [weak self] in
        self?.onResult?([
          "path": url.path,
          "mime_type": kind,
        ])
      }
    }
  }

  func finishFailure(_ message: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self, !self.finished else { return }
      self.finished = true
      self.cameraController.restoreBrightnessIfNecessary()
      self.dismiss(animated: false) { [weak self] in
        self?.onFailure?(message)
      }
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  private weak var activeCameraKitViewController: PyreCameraKitViewController?
  private var notificationForeground = false
  private var activeNotificationConversationId: String?
  private var pendingNotificationConversationId: String?
  private var latestFcmToken: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    configureFirebaseIfPresent()
    UNUserNotificationCenter.current().delegate = self
    if let remoteNotification =
      launchOptions?[.remoteNotification] as? [AnyHashable: Any]
    {
      pendingNotificationConversationId =
        notificationConversationId(from: remoteNotification)
    }

    guard let flutterController = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let externalLinksChannel = FlutterMethodChannel(
      name: pyreExternalLinksChannelName,
      binaryMessenger: flutterController.binaryMessenger
    )
    externalLinksChannel.setMethodCallHandler { call, result in
      guard call.method == "openUrl" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let raw = arguments["url"] as? String,
        let url = URL(string: raw),
        url.scheme?.lowercased() == "https",
        url.host?.lowercased() == "chat.pyrearms.dev"
      else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    }

    let notificationsChannel = FlutterMethodChannel(
      name: pyreNotificationsChannelName,
      binaryMessenger: flutterController.binaryMessenger
    )
    notificationsChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case "initNotifications":
        self.initializeNotifications(application: application, result: result)
      case "getPushToken":
        self.fetchPushToken(result: result)
      case "takeNotificationConversationId":
        let conversationId = self.pendingNotificationConversationId
        self.pendingNotificationConversationId = nil
        result(conversationId)
      case "setNotificationContext":
        self.notificationForeground = arguments?["foreground"] as? Bool ?? false
        let active = (arguments?["activeConversationId"] as? String)?
          .trimmingCharacters(in: .whitespacesAndNewlines)
        self.activeNotificationConversationId =
          active?.isEmpty == false ? active : nil
        result(nil)
      case "showNotification":
        let title = arguments?["title"] as? String ?? "PyreChat"
        let body = arguments?["body"] as? String ?? "New activity"
        let payload = arguments?["payload"] as? String
        self.showLocalNotification(
          title: title,
          body: body,
          payload: payload,
          result: result
        )
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let secureSessionChannel = FlutterMethodChannel(
      name: pyreSecureSessionChannelName,
      binaryMessenger: flutterController.binaryMessenger
    )
    secureSessionChannel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case "isSupported":
        result(true)
      case "readToken":
        result(PyreSecureKeychain.readToken())
      case "writeToken":
        guard let token = arguments?["token"] as? String else {
          result(false)
          return
        }
        result(PyreSecureKeychain.writeToken(token))
      case "deleteToken":
        PyreSecureKeychain.deleteToken()
        result(nil)
      case "readSecret":
        guard let rawName = arguments?["name"] as? String else {
          result(nil)
          return
        }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        result(name.isEmpty ? nil : PyreSecureKeychain.readSecret(name))
      case "writeSecret":
        guard
          let rawName = arguments?["name"] as? String,
          let value = arguments?["value"] as? String
        else {
          result(false)
          return
        }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        result(!name.isEmpty && PyreSecureKeychain.writeSecret(name, value: value))
      case "deleteSecret":
        if let rawName = arguments?["name"] as? String {
          let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
          if !name.isEmpty {
            PyreSecureKeychain.deleteSecret(name)
          }
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let cameraKitChannel = FlutterMethodChannel(
      name: pyreCameraKitChannelName,
      binaryMessenger: flutterController.binaryMessenger
    )

    cameraKitChannel.setMethodCallHandler { [weak self, weak flutterController] call, result in
      guard let self else {
        result(FlutterError(
          code: "camera_kit_unavailable",
          message: "Camera Kit host is unavailable.",
          details: nil
        ))
        return
      }

      switch call.method {
      case "isConfigured":
        result(PyreCameraKitConfiguration.load() != nil)

      case "openCapture":
        guard let config = PyreCameraKitConfiguration.load() else {
          result(FlutterError(
            code: "camera_kit_not_configured",
            message: "Camera Kit credentials are not configured for this build.",
            details: nil
          ))
          return
        }

        guard self.activeCameraKitViewController == nil else {
          result(FlutterError(
            code: "camera_kit_busy",
            message: "Camera Kit is already open.",
            details: nil
          ))
          return
        }

        guard let presenter = flutterController else {
          result(FlutterError(
            code: "camera_kit_unavailable",
            message: "Could not find the Flutter camera presenter.",
            details: nil
          ))
          return
        }

        let sessionConfig = SessionConfig(apiToken: config.apiToken)
        let cameraViewController = PyreCameraKitViewController(
          repoGroups: config.lensGroupIDs,
          sessionConfig: sessionConfig
        )
        cameraViewController.modalPresentationStyle = .fullScreen

        cameraViewController.onResult = { [weak self] payload in
          self?.activeCameraKitViewController = nil
          result(payload)
        }
        cameraViewController.onFailure = { [weak self] message in
          self?.activeCameraKitViewController = nil
          result(FlutterError(
            code: "camera_kit_failure",
            message: message,
            details: nil
          ))
        }

        self.activeCameraKitViewController = cameraViewController
        presenter.present(cameraViewController, animated: true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureFirebaseIfPresent() {
    guard FirebaseApp.app() == nil else {
      Messaging.messaging().delegate = self
      return
    }
    guard
      let path = Bundle.main.path(
        forResource: "GoogleService-Info",
        ofType: "plist"
      ),
      let options = FirebaseOptions(contentsOfFile: path)
    else {
      return
    }
    FirebaseApp.configure(options: options)
    Messaging.messaging().delegate = self
  }

  private func initializeNotifications(
    application: UIApplication,
    result: @escaping FlutterResult
  ) {
    configureFirebaseIfPresent()
    guard FirebaseApp.app() != nil else {
      result(nil)
      return
    }

    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { _, _ in
      DispatchQueue.main.async {
        application.registerForRemoteNotifications()
        result(nil)
      }
    }
  }

  private func fetchPushToken(result: @escaping FlutterResult) {
    configureFirebaseIfPresent()
    guard FirebaseApp.app() != nil else {
      result(nil)
      return
    }
    if let latestFcmToken, !latestFcmToken.isEmpty {
      result(latestFcmToken)
      return
    }

    Messaging.messaging().token { [weak self] token, _ in
      let clean = token?.trimmingCharacters(in: .whitespacesAndNewlines)
      if let clean, !clean.isEmpty {
        self?.latestFcmToken = clean
        result(clean)
      } else {
        result(nil)
      }
    }
  }

  private func showLocalNotification(
    title: String,
    body: String,
    payload: String?,
    result: @escaping FlutterResult
  ) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    var userInfo: [AnyHashable: Any] = ["pyreLocal": true]
    if
      let payload,
      let data = payload.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data),
      let values = object as? [String: Any]
    {
      for (key, value) in values {
        userInfo[key] = value
      }
      if let conversationId = values["conversationId"] as? String {
        content.threadIdentifier = conversationId
      }
    }
    content.userInfo = userInfo

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request) { error in
      result(error == nil)
    }
  }

  private func notificationConversationId(
    from userInfo: [AnyHashable: Any]
  ) -> String? {
    let raw =
      userInfo["conversationId"] as? String ??
      userInfo["gcm.notification.conversationId"] as? String
    let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
    return value?.isEmpty == false ? value : nil
  }

  func messaging(
    _ messaging: Messaging,
    didReceiveRegistrationToken fcmToken: String?
  ) {
    let clean = fcmToken?.trimmingCharacters(in: .whitespacesAndNewlines)
    latestFcmToken = clean?.isEmpty == false ? clean : nil
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    if FirebaseApp.app() != nil {
      Messaging.messaging().apnsToken = deviceToken
    }
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let isLocal = notification.request.content.userInfo["pyreLocal"] as? Bool == true
    if isLocal {
      completionHandler([.banner, .sound])
      return
    }

    if notificationForeground {
      completionHandler([])
      return
    }
    completionHandler([.banner, .sound])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    pendingNotificationConversationId =
      notificationConversationId(from: response.notification.request.content.userInfo)
    completionHandler()
  }
}

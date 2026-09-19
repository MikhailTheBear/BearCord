
import Flutter
import ActivityKit
import Foundation
import CryptoKit

final class BearCordLiveActivityPlugin: NSObject, FlutterPlugin {

    private var channel: FlutterMethodChannel?

    // ============================================================
    // APP GROUP
    // ============================================================

    private let appGroupID =
        "group.tailsbear.bearcord"

    // ============================================================
    // REGISTER
    // ============================================================

    static func register(
        with registrar: FlutterPluginRegistrar
    ) {

        let channel = FlutterMethodChannel(
            name: "bearcord/live_activity",
            binaryMessenger: registrar.messenger()
        )

        let instance =
            BearCordLiveActivityPlugin()

        instance.channel = channel

        registrar.addMethodCallDelegate(
            instance,
            channel: channel
        )
    }

    // ============================================================
    // HANDLE
    // ============================================================

    func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {

        switch call.method {

        case "start":

            if #available(iOS 16.2, *) {
                start(
                    call: call,
                    result: result
                )
            } else {
                result(
                    FlutterError(
                        code: "UNSUPPORTED",
                        message:
                            "Live Activities require iOS 16.2+",
                        details: nil
                    )
                )
            }

        case "update":

            if #available(iOS 16.2, *) {
                update(
                    call: call,
                    result: result
                )
            } else {
                result(
                    FlutterError(
                        code: "UNSUPPORTED",
                        message:
                            "Live Activities require iOS 16.2+",
                        details: nil
                    )
                )
            }

        case "stop":

            if #available(iOS 16.2, *) {
                stop(result: result)
            } else {
                result(
                    FlutterError(
                        code: "UNSUPPORTED",
                        message:
                            "Live Activities require iOS 16.2+",
                        details: nil
                    )
                )
            }

        case "isSupported":

            if #available(iOS 16.2, *) {

                result(
                    ActivityAuthorizationInfo()
                        .areActivitiesEnabled
                )

            } else {

                result(false)
            }

        default:

            result(
                FlutterMethodNotImplemented
            )
        }
    }

    // ============================================================
    // AVATAR CACHE
    // ============================================================

    private func avatarCacheURL(
        for avatarURL: String
    ) -> URL? {

        guard
            let container =
                FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier:
                        appGroupID
                )
        else {

            print(
                "❌ App Group container not found: \(appGroupID)"
            )

            return nil
        }

        let avatarsDirectory =
            container.appendingPathComponent(
                "BearCordAvatars",
                isDirectory: true
            )

        do {

            try FileManager.default.createDirectory(
                at: avatarsDirectory,
                withIntermediateDirectories: true
            )

        } catch {

            print(
                "❌ Avatar directory error: \(error)"
            )

            return nil
        }

        let hash =
            SHA256.hash(
                data:
                    Data(
                        avatarURL.utf8
                    )
            )

        let hashString =
            hash
                .map {
                    String(
                        format: "%02x",
                        $0
                    )
                }
                .joined()

        let pathExtension =
            URL(
                string: avatarURL
            )?
            .pathExtension
            .lowercased()

        let ext =
            pathExtension == "png"
                ? "png"
                : "jpg"

        return avatarsDirectory
            .appendingPathComponent(
                "\(hashString).\(ext)"
            )
    }

    private func cacheAvatar(
        avatarURL: String?
    ) async {

        guard
            let avatarURL,
            !avatarURL.isEmpty,
            let remoteURL =
                URL(string: avatarURL)
        else {

            return
        }

        guard
            let localURL =
                avatarCacheURL(
                    for: avatarURL
                )
        else {

            return
        }

        // Уже скачан
        if FileManager.default.fileExists(
            atPath: localURL.path
        ) {

            print(
                "🖼️ Avatar уже в кеше:"
            )

            print(
                "   \(localURL.path)"
            )

            return
        }

        do {

            print(
                "🖼️ Скачиваем avatar:"
            )

            print(
                "   \(avatarURL)"
            )

            let request =
                URLRequest(
                    url: remoteURL,
                    cachePolicy:
                        .reloadIgnoringLocalCacheData,
                    timeoutInterval:
                        15
                )

            let (
                data,
                response
            ) =
                try await URLSession.shared.data(
                    for: request
                )

            if let httpResponse =
                response as? HTTPURLResponse {

                guard
                    200...299
                        ~= httpResponse.statusCode
                else {

                    print(
                        "❌ Avatar HTTP error: "
                        + "\(httpResponse.statusCode)"
                    )

                    return
                }
            }

            try data.write(
                to: localURL,
                options: .atomic
            )

            print(
                "✅ Avatar сохранён:"
            )

            print(
                "   \(localURL.path)"
            )

        } catch {

            print(
                "❌ Avatar download error: \(error)"
            )
        }
    }

    // ============================================================
    // START
    // ============================================================

    @available(iOS 16.2, *)
    private func start(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {

        guard
            let args =
                call.arguments as? [String: Any]
        else {

            result(
                FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message:
                        "Invalid arguments",
                    details: nil
                )
            )

            return
        }

        let chatID =
            args["chatID"] as? String
            ?? "default"

        let chatName =
            args["chatName"] as? String
            ?? "BearCord"

        let senderName =
            args["senderName"] as? String
            ?? "BearCord"

        let message =
            args["message"] as? String
            ?? ""

        let avatarURL =
            args["avatarURL"] as? String

        print(
            "🏝️ BearCord Live Activity START"
        )

        print(
            "   chatID: \(chatID)"
        )

        print(
            "   chatName: \(chatName)"
        )

        print(
            "   senderName: \(senderName)"
        )

        print(
            "   message: \(message)"
        )

        print(
            "   avatarURL: "
                + "\(avatarURL ?? "nil")"
        )

        guard ActivityAuthorizationInfo()
            .areActivitiesEnabled
        else {

            result(
                FlutterError(
                    code: "ACTIVITY_DISABLED",
                    message:
                        "Live Activities are disabled",
                    details: nil
                )
            )

            return
        }

        Task {

            // Сначала сохраняем аватар,
            // чтобы Widget Extension уже могла
            // прочитать его локально.
            await cacheAvatar(
                avatarURL: avatarURL
            )

            let attributes =
                BearCordLiveActivityAttributes(
                    chatID: chatID,
                    chatName: chatName
                )

            let state =
                BearCordLiveActivityAttributes.ContentState(
                    senderName: senderName,
                    message: message,
                    avatarURL: avatarURL
                )

            do {

                let activity =
                    try Activity<
                        BearCordLiveActivityAttributes
                    >.request(
                        attributes: attributes,
                        content:
                            ActivityContent(
                                state: state,
                                staleDate: nil
                            ),
                        pushType: nil
                    )

                print(
                    "🏝️ Live Activity started: "
                        + "\(activity.id)"
                )

                result(activity.id)

            } catch {

                print(
                    "❌ Live Activity start error: "
                        + "\(error)"
                )

                result(
                    FlutterError(
                        code: "START_FAILED",
                        message:
                            error.localizedDescription,
                        details: nil
                    )
                )
            }
        }
    }

    // ============================================================
    // UPDATE
    // ============================================================

    @available(iOS 16.2, *)
    private func update(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {

        guard
            let args =
                call.arguments as? [String: Any]
        else {

            result(
                FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message:
                        "Invalid arguments",
                    details: nil
                )
            )

            return
        }

        guard
            let activityID =
                args["activityID"] as? String
        else {

            result(
                FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message:
                        "activityID is required",
                    details: nil
                )
            )

            return
        }

        let senderName =
            args["senderName"] as? String
            ?? "BearCord"

        let message =
            args["message"] as? String
            ?? ""

        let avatarURL =
            args["avatarURL"] as? String

        print(
            "🔄 BearCord Live Activity UPDATE"
        )

        print(
            "   activityID: \(activityID)"
        )

        print(
            "   senderName: \(senderName)"
        )

        print(
            "   message: \(message)"
        )

        print(
            "   avatarURL: "
                + "\(avatarURL ?? "nil")"
        )

        guard
            let activity =
                Activity<
                    BearCordLiveActivityAttributes
                >.activities.first(
                    where: {
                        $0.id == activityID
                    }
                )
        else {

            print(
                "❌ Live Activity not found"
            )

            result(
                FlutterError(
                    code: "NOT_FOUND",
                    message:
                        "Live Activity not found",
                    details: nil
                )
            )

            return
        }

        Task {

            await cacheAvatar(
                avatarURL: avatarURL
            )

            let state =
                BearCordLiveActivityAttributes.ContentState(
                    senderName: senderName,
                    message: message,
                    avatarURL: avatarURL
                )

            await activity.update(
                ActivityContent(
                    state: state,
                    staleDate: nil
                )
            )

            print(
                "✅ Live Activity updated"
            )

            result(true)
        }
    }

    // ============================================================
    // STOP
    // ============================================================

    @available(iOS 16.2, *)
    private func stop(
        result: @escaping FlutterResult
    ) {

        print(
            "🛑 Stopping BearCord Live Activities"
        )

        Task {

            for activity in Activity<
                BearCordLiveActivityAttributes
            >.activities {

                await activity.end(
                    nil,
                    dismissalPolicy:
                        .immediate
                )
            }

            print(
                "🛑 BearCord Live Activities stopped"
            )

            result(true)
        }
    }
}


import ActivityKit

struct BearCordLiveActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var senderName: String
        var message: String
        var avatarURL: String?
    }

    // Внутренний ID комнаты.
    // Он нужен приложению, но НЕ показывается пользователю.
    var chatID: String

    // Красивое название чата.
    var chatName: String
}
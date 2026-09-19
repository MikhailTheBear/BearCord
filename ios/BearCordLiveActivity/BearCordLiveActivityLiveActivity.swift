
//
//  BearCordLiveActivityLiveActivity.swift
//  BearCordLiveActivity
//

import ActivityKit
import WidgetKit
import SwiftUI
import UIKit
import CryptoKit

// =====================================================
// AVATAR VIEW
// =====================================================

struct BearCordAvatarView: View {

    let avatarURL: String?
    let size: CGFloat

    private let appGroupID =
        "group.tailsbear.bearcord"

    // =====================================================
    // LOCAL AVATAR URL
    // =====================================================

    private func avatarFileURL() -> URL? {

        guard
            let avatarURL,
            !avatarURL.isEmpty
        else {

            print(
                "❌ Widget avatarURL пустой"
            )

            return nil
        }

        guard
            let container =
                FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier:
                        appGroupID
                )
        else {

            print(
                "❌ Widget App Group container не найден"
            )

            print(
                "   App Group: \(appGroupID)"
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

        let directory =
            container
                .appendingPathComponent(
                    "BearCordAvatars",
                    isDirectory: true
                )

        let fileURL =
            directory
                .appendingPathComponent(
                    "\(hashString).\(ext)"
                )

        return fileURL
    }

    // =====================================================
    // LOAD AVATAR
    // =====================================================

    private func loadAvatarImage() -> UIImage? {

        guard
            let localURL = avatarFileURL()
        else {

            return nil
        }

        print(
            "🖼️ Widget avatar path:"
        )

        print(
            "   \(localURL.path)"
        )

        let exists =
            FileManager.default.fileExists(
                atPath:
                    localURL.path
            )

        print(
            "🖼️ Widget avatar exists: \(exists)"
        )

        guard exists else {

            print(
                "❌ Widget файл аватара НЕ найден"
            )

            return nil
        }

        guard
            let image =
                UIImage(
                    contentsOfFile:
                        localURL.path
                )
        else {

            print(
                "❌ Widget не смог загрузить UIImage"
            )

            return nil
        }

        print(
            "✅ Widget avatar loaded"
        )

        print(
            "   size: "
                + "\(image.size.width)x\(image.size.height)"
        )

        return image
    }

    // =====================================================
    // BODY
    // =====================================================

    var body: some View {

        ZStack {

            Circle()
                .fill(
                    Color.white.opacity(0.10)
                )

            if let image =
                loadAvatarImage() {

                Image(
                    uiImage: image
                )
                .resizable()
                .scaledToFill()
                .frame(
                    width: size,
                    height: size
                )
                .clipShape(
                    Circle()
                )

            } else {

                Image(
                    systemName:
                        "person.fill"
                )
                .font(
                    .system(
                        size: size * 0.42
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.8)
                )
            }
        }
        .frame(
            width: size,
            height: size
        )
        .clipShape(
            Circle()
        )
    }
}


// =====================================================
// LIVE ACTIVITY
// =====================================================

struct BearCordLiveActivityLiveActivity: Widget {

    var body: some WidgetConfiguration {

        ActivityConfiguration(
            for:
                BearCordLiveActivityAttributes.self
        ) { context in

            // =================================================
            // LOCK SCREEN / BANNER
            // =================================================

            HStack(
                spacing: 12
            ) {

                BearCordAvatarView(
                    avatarURL:
                        context.state.avatarURL,
                    size: 42
                )

                VStack(
                    alignment:
                        .leading,
                    spacing: 3
                ) {

                    Text(
                        context.attributes.chatName
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                    HStack(
                        spacing: 5
                    ) {

                        Text(
                            context.state.senderName
                        )
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                        Text(
                            context.state.message
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            .white.opacity(0.75)
                        )
                        .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(
                .horizontal,
                16
            )
            .padding(
                .vertical,
                12
            )
            .activityBackgroundTint(
                Color.black
            )
            .activitySystemActionForegroundColor(
                Color.white
            )

        } dynamicIsland: { context in

            DynamicIsland {

                // =================================================
                // LEADING
                // =================================================

                DynamicIslandExpandedRegion(
                    .leading
                ) {

                    BearCordAvatarView(
                        avatarURL:
                            context.state.avatarURL,
                        size: 38
                    )
                }

                // =================================================
                // TRAILING
                // =================================================

                DynamicIslandExpandedRegion(
                    .trailing
                ) {

                    Text(
                        context.attributes.chatName
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                }

                // =================================================
                // BOTTOM
                // =================================================

                DynamicIslandExpandedRegion(
                    .bottom
                ) {

                    VStack(
                        alignment:
                            .leading,
                        spacing: 4
                    ) {

                        Text(
                            context.state.senderName
                        )
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                        Text(
                            context.state.message
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            .white.opacity(0.80)
                        )
                        .lineLimit(2)
                    }
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            .leading
                    )
                }

            } compactLeading: {

                BearCordAvatarView(
                    avatarURL:
                        context.state.avatarURL,
                    size: 22
                )

            } compactTrailing: {

                Text(
                    context.state.senderName
                )
                .font(.caption2)
                .fontWeight(.semibold)
                .lineLimit(1)

            } minimal: {

                BearCordAvatarView(
                    avatarURL:
                        context.state.avatarURL,
                    size: 20
                )
            }
            .keylineTint(.blue)
        }
    }
}


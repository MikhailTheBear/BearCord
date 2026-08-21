//
//  BearCordLiveActivityLiveActivity.swift
//  BearCordLiveActivity
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BearCordLiveActivityLiveActivity: Widget {

    var body: some WidgetConfiguration {

        ActivityConfiguration(
            for: BearCordLiveActivityAttributes.self
        ) { context in

            // =====================================================
            // LOCK SCREEN / BANNER
            // =====================================================

            HStack(spacing: 12) {

                // Аватар пока системный.
                // Позже можем сделать загрузку реального avatarURL.
                ZStack {
                    Circle()
                        .fill(
                            Color.white.opacity(0.10)
                        )

                    Image(
                        systemName: "person.fill"
                    )
                    .font(
                        .system(size: 18)
                    )
                    .foregroundStyle(
                        .white.opacity(0.8)
                    )
                }
                .frame(
                    width: 42,
                    height: 42
                )

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    // Название чата
                    Text(
                        context.attributes.chatName
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                    // Отправитель + сообщение
                    HStack(spacing: 5) {

                        Text(
                            context.state.senderName
                        )
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(
                Color.black
            )
            .activitySystemActionForegroundColor(
                Color.white
            )

        } dynamicIsland: { context in

            // =====================================================
            // DYNAMIC ISLAND
            // =====================================================

            DynamicIsland {

                // -------------------------------------------------
                // LEFT
                // -------------------------------------------------

                DynamicIslandExpandedRegion(
                    .leading
                ) {

                    ZStack {
                        Circle()
                            .fill(
                                Color.white.opacity(
                                    0.12
                                )
                            )

                        Image(
                            systemName:
                                "person.fill"
                        )
                        .font(
                            .system(size: 16)
                        )
                        .foregroundStyle(
                            .white.opacity(0.85)
                        )
                    }
                    .frame(
                        width: 38,
                        height: 38
                    )
                }

                // -------------------------------------------------
                // RIGHT
                // -------------------------------------------------

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

                // -------------------------------------------------
                // BOTTOM
                // -------------------------------------------------

                DynamicIslandExpandedRegion(
                    .bottom
                ) {

                    VStack(
                        alignment: .leading,
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
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                }

            } compactLeading: {

                // -------------------------------------------------
                // COMPACT LEADING
                // -------------------------------------------------

                Image(
                    systemName:
                        "message.fill"
                )
                .foregroundStyle(.white)

            } compactTrailing: {

                // -------------------------------------------------
                // COMPACT TRAILING
                // -------------------------------------------------

                Text(
                    context.state.senderName
                )
                .font(.caption2)
                .fontWeight(.semibold)
                .lineLimit(1)

            } minimal: {

                // -------------------------------------------------
                // MINIMAL
                // -------------------------------------------------

                Image(
                    systemName:
                        "message.fill"
                )
                .foregroundStyle(.white)

            }
            .keylineTint(.blue)
        }
    }
}
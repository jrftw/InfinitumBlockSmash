/******************************************************
 * FILE: NotificationName+Extension.swift
 * MARK: Notification Name Constants Extension
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Defines custom notification names for app-wide communication,
 * providing centralized constants for notification-based events.
 *
 * KEY RESPONSIBILITIES:
 * - Define online users count change notifications
 * - Define daily players count change notifications
 * - Define network error notifications
 * - Provide consistent notification naming
 * - Support app-wide event communication
 *
 * MAJOR DEPENDENCIES:
 * - Foundation: Core framework for Notification.Name
 * - App-wide notification system: Event communication
 *
 * EXTERNAL FRAMEWORKS USED:
 * - Foundation: Core framework for notification system
 *
 * ARCHITECTURE ROLE:
 * Acts as a notification constants provider that enables
 * consistent event communication across the app.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Notification names must be unique across the app
 * - Constants must be available before notification posting
 * - Naming must be descriptive and consistent
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify notification names are unique and descriptive
 * - Check that all notification consumers use these constants
 * - Test notification posting and receiving
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add more notification types as needed
 * - Implement notification grouping
 * - Add notification documentation
 ******************************************************/

import Foundation

extension Notification.Name {
    static let onlineUsersCountDidChange = Notification.Name("onlineUsersCountDidChange")
    static let dailyPlayersCountDidChange = Notification.Name("dailyPlayersCountDidChange")
    static let networkError = Notification.Name("networkError")
} 
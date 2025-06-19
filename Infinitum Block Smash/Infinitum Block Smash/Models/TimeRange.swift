/*
 * FILE: TimeRange.swift
 * PURPOSE: Defines time range options for analytics and leaderboards
 * DEPENDENCIES: None
 * AUTHOR: @jrftw
 * LAST UPDATED: 6/19/2025
 */

import Foundation

// MARK: - TimeRange
enum TimeRange: String, CaseIterable {
    case day = "24 Hours"
    case week = "7 Days"
    case month = "30 Days"
    case allTime = "All Time"
} 
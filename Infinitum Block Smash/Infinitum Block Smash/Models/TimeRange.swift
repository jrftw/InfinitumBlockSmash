/******************************************************
 * FILE: TimeRange.swift
 * MARK: Time Range Enumeration for Analytics and Leaderboards
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Defines time range options for analytics, leaderboards, and data filtering.
 * This enumeration provides standardized time periods for consistent
 * data analysis and user interface display across the application.
 *
 * KEY RESPONSIBILITIES:
 * - Time range enumeration for data filtering
 * - Analytics period selection and display
 * - Leaderboard time-based filtering
 * - User interface time period options
 * - Data aggregation period definitions
 * - Consistent time range formatting
 * - Cross-feature time period standardization
 *
 * MAJOR DEPENDENCIES:
 * - Foundation: Core framework for string handling
 * - Analytics systems for data filtering
 * - Leaderboard systems for time-based queries
 * - UI components for time period selection
 *
 * EXTERNAL FRAMEWORKS USED:
 * - Foundation: Core framework for string operations
 *
 * ARCHITECTURE ROLE:
 * Acts as a utility enumeration that provides consistent
 * time range definitions across analytics, leaderboards,
 * and user interface components.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - String values must be user-friendly for UI display
 * - CaseIterable enables easy UI iteration
 * - Raw string values provide consistent data storage
 * - Time periods should align with common user expectations
 */

import Foundation

// MARK: - TimeRange
enum TimeRange: String, CaseIterable {
    case day = "24 Hours"
    case week = "7 Days"
    case month = "30 Days"
    case allTime = "All Time"
} 
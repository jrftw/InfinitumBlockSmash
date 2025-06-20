/******************************************************
 * FILE: CalendarExtensions.swift
 * MARK: Calendar Utility Extensions
 * CREATED: 6/19/2025 by @jrftw
 * MODIFIED LAST: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Provides utility extensions for Calendar operations, offering
 * convenient methods for date calculations and time period management.
 *
 * KEY RESPONSIBILITIES:
 * - Calculate start of week for any given date
 * - Calculate start of month for any given date
 * - Provide consistent date boundary calculations
 * - Support time period analysis and grouping
 *
 * MAJOR DEPENDENCIES:
 * - Foundation: Core framework for Calendar and Date
 * - DateComponents: Date calculation components
 *
 * EXTERNAL FRAMEWORKS USED:
 * - Foundation: Core framework for date and time operations
 *
 * ARCHITECTURE ROLE:
 * Acts as a utility extension that provides convenient
 * date calculation methods for time-based features.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Date calculations must be accurate and consistent
 * - Methods must handle edge cases properly
 * - Time zone considerations must be accounted for
 */

/******************************************************
 * REVIEW NOTES:
 * - Verify date calculations are accurate across time zones
 * - Test edge cases like year boundaries
 * - Check performance for frequent date operations
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add more date utility methods
 * - Implement time zone handling
 * - Add date formatting utilities
 ******************************************************/

import Foundation

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
    
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
} 
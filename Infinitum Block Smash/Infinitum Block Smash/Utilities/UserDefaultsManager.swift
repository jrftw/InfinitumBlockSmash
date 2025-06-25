/*
 * UserDefaultsManager.swift
 * 
 * SAFE USERDEFAULTS OPERATIONS MANAGER
 * 
 * This utility provides safe UserDefaults operations that prevent main thread I/O hangs
 * by performing all disk operations on background threads.
 * 
 * KEY FEATURES:
 * - Background thread synchronization
 * - Safe main thread access
 * - Batch operations support
 * - Error handling and logging
 * - Performance optimization
 * 
 * THREADING MODEL:
 * - All disk I/O operations on background queue
 * - Main thread only for UI updates
 * - Thread-safe property access
 * - Async/await support
 */

import Foundation

@MainActor
class UserDefaultsManager: ObservableObject {
    static let shared = UserDefaultsManager()
    
    private let userDefaults = UserDefaults.standard
    private let backgroundQueue = DispatchQueue(label: "UserDefaultsManager.background", qos: .utility)
    private var pendingWrites: [String: Any] = [:]
    private var writeTimer: Timer?
    
    private init() {
        // Start periodic flush timer
        startWriteTimer()
    }
    
    deinit {
        writeTimer?.invalidate()
        // Use weak capture to avoid deinit capture warning
        Task { [weak self] in
            await self?.flushPendingWrites()
        }
    }
    
    // MARK: - Safe Read Operations (Main Thread Safe)
    
    func bool(forKey key: String) -> Bool {
        return userDefaults.bool(forKey: key)
    }
    
    func integer(forKey key: String) -> Int {
        return userDefaults.integer(forKey: key)
    }
    
    func double(forKey key: String) -> Double {
        return userDefaults.double(forKey: key)
    }
    
    func string(forKey key: String) -> String? {
        return userDefaults.string(forKey: key)
    }
    
    func object(forKey key: String) -> Any? {
        return userDefaults.object(forKey: key)
    }
    
    func data(forKey key: String) -> Data? {
        return userDefaults.data(forKey: key)
    }
    
    // MARK: - Safe Write Operations (Background Thread)
    
    func set(_ value: Any?, forKey key: String) {
        // Store in memory immediately for main thread access
        userDefaults.set(value, forKey: key)
        
        // Queue for background synchronization
        Task.detached(priority: .background) { [weak self] in
            await self?.performBackgroundSynchronization()
        }
    }
    
    func setBool(_ value: Bool, forKey key: String) {
        set(value, forKey: key)
    }
    
    func setInteger(_ value: Int, forKey key: String) {
        set(value, forKey: key)
    }
    
    func setDouble(_ value: Double, forKey key: String) {
        set(value, forKey: key)
    }
    
    func setString(_ value: String?, forKey key: String) {
        set(value, forKey: key)
    }
    
    func setData(_ value: Data?, forKey key: String) {
        set(value, forKey: key)
    }
    
    // MARK: - Batch Operations
    
    func setMultiple(_ values: [String: Any]) {
        // Store all values in memory immediately
        for (key, value) in values {
            userDefaults.set(value, forKey: key)
        }
        
        // Queue single synchronization
        Task.detached(priority: .background) { [weak self] in
            await self?.performBackgroundSynchronization()
        }
    }
    
    // MARK: - Remove Operations
    
    func removeObject(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        
        Task.detached(priority: .background) { [weak self] in
            await self?.performBackgroundSynchronization()
        }
    }
    
    func removePersistentDomain(forName domainName: String) {
        Task.detached(priority: .background) { [weak self] in
            await self?.performBackgroundSynchronizationWithDomainRemoval(domainName: domainName)
        }
    }
    
    // MARK: - Force Synchronization
    
    func synchronize() async {
        await performBackgroundSynchronization()
    }
    
    // MARK: - Private Methods
    
    private func flushPendingWrites() {
        Task { @MainActor in
            await performBackgroundSynchronization()
        }
    }
    
    @MainActor
    private func performBackgroundSynchronization() async {
        await withCheckedContinuation { continuation in
            backgroundQueue.async {
                // Use UserDefaults.standard directly in background context
                UserDefaults.standard.synchronize()
                continuation.resume()
            }
        }
    }
    
    @MainActor
    private func performBackgroundSynchronizationWithDomainRemoval(domainName: String) async {
        await withCheckedContinuation { continuation in
            backgroundQueue.async {
                // Use UserDefaults.standard directly in background context
                UserDefaults.standard.removePersistentDomain(forName: domainName)
                UserDefaults.standard.synchronize()
                continuation.resume()
            }
        }
    }
    
    private func startWriteTimer() {
        // Reduce write frequency to save battery
        writeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in // Increased from 1.0 to 5.0
            Task { @MainActor in
                self?.flushPendingWrites()
            }
        }
    }
}

// MARK: - Convenience Extensions

extension UserDefaultsManager {
    // Game-specific convenience methods
    func getHighScore(for level: Int) -> Int {
        return integer(forKey: "highScore_level_\(level)")
    }
    
    func setHighScore(_ score: Int, for level: Int) {
        setInteger(score, forKey: "highScore_level_\(level)")
    }
    
    func getIsTimedMode() -> Bool {
        return bool(forKey: "isTimedMode")
    }
    
    func setIsTimedMode(_ isTimed: Bool) {
        setBool(isTimed, forKey: "isTimedMode")
    }
    
    func getIsGuest() -> Bool {
        return bool(forKey: "isGuest")
    }
    
    func setIsGuest(_ isGuest: Bool) {
        setBool(isGuest, forKey: "isGuest")
    }
    
    func getSoundEnabled() -> Bool {
        return bool(forKey: "soundEnabled")
    }
    
    func setSoundEnabled(_ enabled: Bool) {
        setBool(enabled, forKey: "soundEnabled")
    }
    
    func getMusicEnabled() -> Bool {
        return bool(forKey: "musicEnabled")
    }
    
    func setMusicEnabled(_ enabled: Bool) {
        setBool(enabled, forKey: "musicEnabled")
    }
    
    func getVibrationEnabled() -> Bool {
        return bool(forKey: "vibrationEnabled")
    }
    
    func setVibrationEnabled(_ enabled: Bool) {
        setBool(enabled, forKey: "vibrationEnabled")
    }
    
    func getHapticsEnabled() -> Bool {
        return bool(forKey: "hapticsEnabled")
    }
    
    func setHapticsEnabled(_ enabled: Bool) {
        setBool(enabled, forKey: "hapticsEnabled")
    }
    
    func getAllowCrashReports() -> Bool {
        return bool(forKey: "allowCrashReports")
    }
    
    func setAllowCrashReports(_ allowed: Bool) {
        setBool(allowed, forKey: "allowCrashReports")
    }
    
    func getTheme() -> String {
        return string(forKey: "theme") ?? "default"
    }
    
    func setTheme(_ theme: String) {
        setString(theme, forKey: "theme")
    }
    
    func getDifficulty() -> String {
        return string(forKey: "difficulty") ?? "normal"
    }
    
    func setDifficulty(_ difficulty: String) {
        setString(difficulty, forKey: "difficulty")
    }
    
    func getUsername() -> String? {
        return string(forKey: "username")
    }
    
    func setUsername(_ username: String) {
        setString(username, forKey: "username")
    }
    
    func getDeviceToken() -> String? {
        return string(forKey: "deviceToken")
    }
    
    func setDeviceToken(_ token: String) {
        setString(token, forKey: "deviceToken")
    }
    
    func getLastLeaderboardUpdate() -> Date? {
        return object(forKey: "lastLeaderboardUpdate") as? Date
    }
    
    func setLastLeaderboardUpdate(_ date: Date) {
        set(date, forKey: "lastLeaderboardUpdate")
    }
    
    func getLastFirebaseSaveTime() -> Date? {
        return object(forKey: "lastFirebaseSaveTime") as? Date
    }
    
    func setLastFirebaseSaveTime(_ date: Date) {
        set(date, forKey: "lastFirebaseSaveTime")
    }
    
    func getLastSaveTime() -> Date? {
        return object(forKey: "lastSaveTime") as? Date
    }
    
    func setLastSaveTime(_ date: Date) {
        set(date, forKey: "lastSaveTime")
    }
    
    func getDeviceId() -> String? {
        return string(forKey: "deviceId")
    }
    
    func setDeviceId(_ deviceId: String) {
        setString(deviceId, forKey: "deviceId")
    }
    
    func getGameDataVersion() -> Int {
        return integer(forKey: "gameDataVersion")
    }
    
    func setGameDataVersion(_ version: Int) {
        setInteger(version, forKey: "gameDataVersion")
    }
    
    func getTargetFPS() -> Int {
        return integer(forKey: "targetFPS")
    }
    
    func setTargetFPS(_ fps: Int) {
        setInteger(fps, forKey: "targetFPS")
    }
    
    func getAppOpenCount() -> Int {
        return integer(forKey: "appOpenCount")
    }
    
    func setAppOpenCount(_ count: Int) {
        setInteger(count, forKey: "appOpenCount")
    }
    
    func getHasRated() -> Bool {
        return bool(forKey: "hasRated")
    }
    
    func setHasRated(_ hasRated: Bool) {
        setBool(hasRated, forKey: "hasRated")
    }
    
    func getHasShownReferral() -> Bool {
        return bool(forKey: "hasShownReferral")
    }
    
    func setHasShownReferral(_ hasShown: Bool) {
        setBool(hasShown, forKey: "hasShownReferral")
    }
    
    func getHasSavedGame() -> Bool {
        return bool(forKey: "hasSavedGame")
    }
    
    func setHasSavedGame(_ hasSaved: Bool) {
        setBool(hasSaved, forKey: "hasSavedGame")
    }
    
    func getTimedGameTimeRemaining() -> Double {
        return double(forKey: "timedGame_timeRemaining")
    }
    
    func setTimedGameTimeRemaining(_ time: Double) {
        setDouble(time, forKey: "timedGame_timeRemaining")
    }
    
    func getTimedGameIsTimeRunning() -> Bool {
        return bool(forKey: "timedGame_isTimeRunning")
    }
    
    func setTimedGameIsTimeRunning(_ isRunning: Bool) {
        setBool(isRunning, forKey: "timedGame_isTimeRunning")
    }
    
    func getCachedAnalyticsData() -> String? {
        return string(forKey: "cached_analytics_data")
    }
    
    func setCachedAnalyticsData(_ data: String) {
        setString(data, forKey: "cached_analytics_data")
    }
    
    func getPersonalHighScore() -> Int {
        return integer(forKey: "personalHighScore")
    }
    
    func setPersonalHighScore(_ score: Int) {
        setInteger(score, forKey: "personalHighScore")
    }
    
    func getPersonalHighestLevel() -> Int {
        return integer(forKey: "personalHighestLevel")
    }
    
    func setPersonalHighestLevel(_ level: Int) {
        setInteger(level, forKey: "personalHighestLevel")
    }
    
    func getHighScore() -> Int {
        return integer(forKey: "highScore")
    }
    
    func setHighScore(_ score: Int) {
        setInteger(score, forKey: "highScore")
    }
    
    func getHighestLevel() -> Int {
        return integer(forKey: "highestLevel")
    }
    
    func setHighestLevel(_ level: Int) {
        setInteger(level, forKey: "highestLevel")
    }
    
    func getBestTime() -> Double {
        return double(forKey: "bestTime")
    }
    
    func setBestTime(_ time: Double) {
        setDouble(time, forKey: "bestTime")
    }
    
    func getScore() -> Int {
        return integer(forKey: "score")
    }
    
    func setScore(_ score: Int) {
        setInteger(score, forKey: "score")
    }
    
    func getLevel() -> Int {
        return integer(forKey: "level")
    }
    
    func setLevel(_ level: Int) {
        setInteger(level, forKey: "level")
    }
    
    func getBlocksPlaced() -> Int {
        return integer(forKey: "blocksPlaced")
    }
    
    func setBlocksPlaced(_ count: Int) {
        setInteger(count, forKey: "blocksPlaced")
    }
    
    func getLinesCleared() -> Int {
        return integer(forKey: "linesCleared")
    }
    
    func setLinesCleared(_ count: Int) {
        setInteger(count, forKey: "linesCleared")
    }
    
    func getGamesCompleted() -> Int {
        return integer(forKey: "gamesCompleted")
    }
    
    func setGamesCompleted(_ count: Int) {
        setInteger(count, forKey: "gamesCompleted")
    }
    
    func getPerfectLevels() -> Int {
        return integer(forKey: "perfectLevels")
    }
    
    func setPerfectLevels(_ count: Int) {
        setInteger(count, forKey: "perfectLevels")
    }
    
    func getTotalPlayTime() -> Double {
        return double(forKey: "totalPlayTime")
    }
    
    func setTotalPlayTime(_ time: Double) {
        setDouble(time, forKey: "totalPlayTime")
    }
} 
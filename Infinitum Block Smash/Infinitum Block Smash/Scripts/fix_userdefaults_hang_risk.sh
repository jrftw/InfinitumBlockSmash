#!/bin/bash

# Fix UserDefaults Hang Risk Script
# This script helps identify and fix UserDefaults operations that could cause main thread I/O hangs

echo "🔍 Scanning for potential UserDefaults hang risks..."

# Find all UserDefaults.synchronize() calls
echo "📝 Found UserDefaults.synchronize() calls:"
grep -r "UserDefaults\.standard\.synchronize()" . --include="*.swift" -n

echo ""
echo "📝 Found UserDefaults.standard.set() calls:"
grep -r "UserDefaults\.standard\.set(" . --include="*.swift" -n

echo ""
echo "📝 Found UserDefaults.standard.removeObject() calls:"
grep -r "UserDefaults\.standard\.removeObject(" . --include="*.swift" -n

echo ""
echo "📝 Found UserDefaults.standard.removePersistentDomain() calls:"
grep -r "UserDefaults\.standard\.removePersistentDomain(" . --include="*.swift" -n

echo ""
echo "🔧 RECOMMENDED FIXES:"
echo "1. Replace UserDefaults.standard.synchronize() with UserDefaultsManager.shared.synchronize()"
echo "2. Replace UserDefaults.standard.set() with UserDefaultsManager.shared.set()"
echo "3. Replace UserDefaults.standard.removeObject() with UserDefaultsManager.shared.removeObject()"
echo "4. Replace UserDefaults.standard.removePersistentDomain() with UserDefaultsManager.shared.removePersistentDomain()"
echo ""
echo "📋 EXAMPLE MIGRATION:"
echo "// OLD (causes hang risk):"
echo "UserDefaults.standard.set(value, forKey: key)"
echo "UserDefaults.standard.synchronize()"
echo ""
echo "// NEW (safe):"
echo "UserDefaultsManager.shared.set(value, forKey: key)"
echo "// synchronize() is called automatically in background"
echo ""
echo "✅ The UserDefaultsManager.swift file has been created with safe operations."
echo "🔄 Run this script again after migration to verify all issues are resolved." 
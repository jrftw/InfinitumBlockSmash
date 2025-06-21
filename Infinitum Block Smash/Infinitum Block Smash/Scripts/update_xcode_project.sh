#!/bin/bash

# Xcode Project Update Helper Script
# This script helps identify files that need to be added to the Xcode project
# and provides a summary of the current file organization.

echo "🔍 Xcode Project Update Helper"
echo "=============================="
echo ""

# Get the project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_PROJECT_DIR="$(cd "$PROJECT_DIR/.." && pwd)"

echo "📁 Project Directory: $PROJECT_DIR"
echo "📁 Xcode Project Directory: $XCODE_PROJECT_DIR"
echo ""

# Check if Xcode project exists
if [ ! -d "$XCODE_PROJECT_DIR/Infinitum Block Smash.xcodeproj" ]; then
    echo "❌ Error: Xcode project not found at expected location"
    echo "Expected: $XCODE_PROJECT_DIR/Infinitum Block Smash.xcodeproj"
    exit 1
fi

echo "✅ Xcode project found"
echo ""

# Function to count files by extension
count_files() {
    local extension=$1
    local count=$(find "$PROJECT_DIR" -name "*.$extension" -type f | wc -l | tr -d ' ')
    echo "$count"
}

# Function to list files by extension
list_files() {
    local extension=$1
    find "$PROJECT_DIR" -name "*.$extension" -type f | sed "s|$PROJECT_DIR/||" | sort
}

echo "📊 File Summary:"
echo "================"

# Count Swift files
swift_count=$(count_files "swift")
echo "📱 Swift files: $swift_count"

# Count storyboard files
storyboard_count=$(count_files "storyboard")
echo "📱 Storyboard files: $storyboard_count"

# Count plist files
plist_count=$(count_files "plist")
echo "⚙️  Plist files: $plist_count"

# Count markdown files
md_count=$(count_files "md")
echo "📝 Markdown files: $md_count"

# Count JSON files
json_count=$(count_files "json")
echo "📄 JSON files: $json_count"

# Count shell scripts
sh_count=$(count_files "sh")
echo "🐚 Shell scripts: $sh_count"

# Count Python files
py_count=$(count_files "py")
echo "🐍 Python files: $py_count"

echo ""
echo "📁 Directory Structure:"
echo "======================"

# List all directories
find "$PROJECT_DIR" -type d -not -path "*/\.*" | sed "s|$PROJECT_DIR/||" | sort | while read -r dir; do
    if [ -n "$dir" ]; then
        echo "📁 $dir"
    fi
done

echo ""
echo "🔍 Files by Category:"
echo "===================="

echo ""
echo "📱 Swift Files:"
echo "---------------"
list_files "swift" | head -20
if [ "$swift_count" -gt 20 ]; then
    echo "... and $((swift_count - 20)) more Swift files"
fi

echo ""
echo "📝 Documentation Files:"
echo "----------------------"
list_files "md"

echo ""
echo "⚙️  Configuration Files:"
echo "----------------------"
list_files "plist"
list_files "json"

echo ""
echo "🐚 Scripts:"
echo "----------"
list_files "sh"
list_files "py"

echo ""
echo "📋 Next Steps:"
echo "=============="
echo ""
echo "1. Open Xcode project:"
echo "   open \"$XCODE_PROJECT_DIR/Infinitum Block Smash.xcodeproj\""
echo ""
echo "2. Follow the XCODE_PROJECT_UPDATE_GUIDE.md for detailed instructions"
echo ""
echo "3. Key areas to focus on:"
echo "   - Create groups matching the folder structure"
echo "   - Move files to appropriate groups"
echo "   - Fix any broken file references (red files)"
echo "   - Ensure all files are added to the correct target"
echo ""
echo "4. Test the project after updates:"
echo "   - Clean build folder (⇧⌘K)"
echo "   - Build project (⌘B)"
echo "   - Run on simulator (⌘R)"
echo ""

# Check for potential issues
echo "⚠️  Potential Issues to Watch For:"
echo "================================="

# Check for files that might be missing from Xcode
echo ""
echo "🔍 Checking for common missing files..."

# Check for Info.plist
if [ -f "$PROJECT_DIR/App/Info.plist" ]; then
    echo "✅ Info.plist found at App/Info.plist"
else
    echo "❌ Info.plist not found in expected location"
fi

# Check for GoogleService-Info.plist
if [ -f "$PROJECT_DIR/Config/GoogleService-Info.plist" ]; then
    echo "✅ GoogleService-Info.plist found"
else
    echo "❌ GoogleService-Info.plist not found in Config/"
fi

# Check for main app file
if [ -f "$PROJECT_DIR/App/Infinitum_Block_SmashApp.swift" ]; then
    echo "✅ Main app file found"
else
    echo "❌ Infinitum_Block_SmashApp.swift not found in App/"
fi

# Check for Assets.xcassets
if [ -d "$PROJECT_DIR/Resources/Assets.xcassets" ]; then
    echo "✅ Assets.xcassets found"
else
    echo "❌ Assets.xcassets not found in Resources/"
fi

echo ""
echo "🎯 Ready to update Xcode project!"
echo "Follow the guide in Documentation/XCODE_PROJECT_UPDATE_GUIDE.md"
echo "" 
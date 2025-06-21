#!/bin/bash

# Exclude Config Files Build Phase Script
# This script should be run as a build phase in Xcode to prevent configuration files
# from being included in the app bundle, which causes multiple command conflicts.

echo "Excluding configuration files and node_modules from build bundle..."

# Get the build products directory from Xcode environment
if [ -n "$BUILT_PRODUCTS_DIR" ]; then
    BUNDLE_DIR="$BUILT_PRODUCTS_DIR"
else
    # Fallback for manual execution
    BUNDLE_DIR="$1"
fi

if [ -z "$BUNDLE_DIR" ]; then
    echo "Error: No bundle directory specified"
    exit 1
fi

echo "Cleaning bundle directory: $BUNDLE_DIR"

# Remove problematic configuration files from the app bundle
find "$BUNDLE_DIR" -name ".editorconfig" -delete
find "$BUNDLE_DIR" -name ".eslintrc" -delete
find "$BUNDLE_DIR" -name ".jshintrc" -delete
find "$BUNDLE_DIR" -name ".npmignore" -delete
find "$BUNDLE_DIR" -name ".eslintrc.js" -delete
find "$BUNDLE_DIR" -name ".eslintrc.json" -delete
find "$BUNDLE_DIR" -name ".jshintrc.json" -delete
find "$BUNDLE_DIR" -name ".editorconfig.json" -delete
find "$BUNDLE_DIR" -name ".nycrc" -delete
find "$BUNDLE_DIR" -name ".travis.yml" -delete
find "$BUNDLE_DIR" -name "FUNDING.yml" -delete

# Remove problematic JavaScript files
find "$BUNDLE_DIR" -name "BaseOutputBuilder.js" -delete
find "$BUNDLE_DIR" -name "BufferSource.js" -delete
find "$BUNDLE_DIR" -name "CharsSymbol.js" -delete
find "$BUNDLE_DIR" -name "EntitiesParser.js" -delete
find "$BUNDLE_DIR" -name "JsArrBuilder.js" -delete
find "$BUNDLE_DIR" -name "JsMinArrBuilder.js" -delete
find "$BUNDLE_DIR" -name "JsObjBuilder.js" -delete

# Remove documentation files
find "$BUNDLE_DIR" -name "CHANGELOG.md" -delete
find "$BUNDLE_DIR" -name "CHANGES.md" -delete
find "$BUNDLE_DIR" -name "CONTRIBUTING.md" -delete
find "$BUNDLE_DIR" -name "HISTORY.md" -delete
find "$BUNDLE_DIR" -name "History.md" -delete
find "$BUNDLE_DIR" -name "LICENSE" -delete
find "$BUNDLE_DIR" -name "LICENSE-MIT.txt" -delete

# Remove all JavaScript files from node_modules
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.js" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.mjs" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.ts" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.tsx" -delete

# Remove all documentation files from node_modules
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.md" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.txt" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.yml" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.yaml" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.json" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.xml" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.html" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.css" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.scss" -delete
find "$BUNDLE_DIR" -path "*/node_modules/*" -name "*.less" -delete

# Remove entire node_modules directories
find "$BUNDLE_DIR" -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true

# Remove Services directory if it exists in the bundle
if [ -d "${BUNDLE_DIR}/Services" ]; then
    echo "Removing Services directory from bundle"
    rm -rf "${BUNDLE_DIR}/Services"
fi

# Remove firebase.json and .firebaserc if they exist
if [ -f "${BUNDLE_DIR}/firebase.json" ]; then
    echo "Removing firebase.json from bundle"
    rm -f "${BUNDLE_DIR}/firebase.json"
fi

if [ -f "${BUNDLE_DIR}/.firebaserc" ]; then
    echo "Removing .firebaserc from bundle"
    rm -f "${BUNDLE_DIR}/.firebaserc"
fi

# Remove package files
find "$BUNDLE_DIR" -name "package.json" -delete
find "$BUNDLE_DIR" -name "package-lock.json" -delete
find "$BUNDLE_DIR" -name "yarn.lock" -delete

echo "Configuration files and node_modules excluded from build bundle successfully!" 
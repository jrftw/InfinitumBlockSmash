#!/bin/bash

# Clean Build Conflicts Script
# This script removes configuration files that cause multiple command conflicts in Xcode builds

echo "Cleaning build conflicts..."

# Get the project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"

# Find the derived data directory for this project
PROJECT_NAME="Infinitum_Block_Smash"
DERIVED_PROJECT_DIR=$(find "$DERIVED_DATA_DIR" -name "*$PROJECT_NAME*" -type d | head -1)

if [ -n "$DERIVED_PROJECT_DIR" ]; then
    echo "Found derived data directory: $DERIVED_PROJECT_DIR"
    
    # Remove problematic configuration files from build products
    find "$DERIVED_PROJECT_DIR" -name ".editorconfig" -delete
    find "$DERIVED_PROJECT_DIR" -name ".eslintrc" -delete
    find "$DERIVED_PROJECT_DIR" -name ".jshintrc" -delete
    find "$DERIVED_PROJECT_DIR" -name ".npmignore" -delete
    find "$DERIVED_PROJECT_DIR" -name ".eslintrc.js" -delete
    find "$DERIVED_PROJECT_DIR" -name ".eslintrc.json" -delete
    find "$DERIVED_PROJECT_DIR" -name ".jshintrc.json" -delete
    find "$DERIVED_PROJECT_DIR" -name ".editorconfig.json" -delete
    find "$DERIVED_PROJECT_DIR" -name ".nycrc" -delete
    find "$DERIVED_PROJECT_DIR" -name ".travis.yml" -delete
    find "$DERIVED_PROJECT_DIR" -name "FUNDING.yml" -delete
    
    # Remove problematic JavaScript files
    find "$DERIVED_PROJECT_DIR" -name "BaseOutputBuilder.js" -delete
    find "$DERIVED_PROJECT_DIR" -name "BufferSource.js" -delete
    find "$DERIVED_PROJECT_DIR" -name "CharsSymbol.js" -delete
    find "$DERIVED_PROJECT_DIR" -name "EntitiesParser.js" -delete
    find "$DERIVED_PROJECT_DIR" -name "JsArrBuilder.js" -delete
    find "$DERIVED_PROJECT_DIR" -name "JsMinArrBuilder.js" -delete
    find "$DERIVED_PROJECT_DIR" -name "JsObjBuilder.js" -delete
    
    # Remove documentation files
    find "$DERIVED_PROJECT_DIR" -name "CHANGELOG.md" -delete
    find "$DERIVED_PROJECT_DIR" -name "CHANGES.md" -delete
    find "$DERIVED_PROJECT_DIR" -name "CONTRIBUTING.md" -delete
    find "$DERIVED_PROJECT_DIR" -name "HISTORY.md" -delete
    find "$DERIVED_PROJECT_DIR" -name "History.md" -delete
    find "$DERIVED_PROJECT_DIR" -name "LICENSE" -delete
    find "$DERIVED_PROJECT_DIR" -name "LICENSE-MIT.txt" -delete
    
    # Remove all JavaScript files from node_modules
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.js" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.mjs" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.ts" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.tsx" -delete
    
    # Remove all documentation files from node_modules
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.md" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.txt" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.yml" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.yaml" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.json" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.xml" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.html" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.css" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.scss" -delete
    find "$DERIVED_PROJECT_DIR" -path "*/node_modules/*" -name "*.less" -delete
    
    # Remove entire node_modules directories
    find "$DERIVED_PROJECT_DIR" -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true
    
    # Remove Services directory if it exists
    find "$DERIVED_PROJECT_DIR" -type d -name "Services" -exec rm -rf {} + 2>/dev/null || true
    
    # Remove firebase.json and .firebaserc
    find "$DERIVED_PROJECT_DIR" -name "firebase.json" -delete
    find "$DERIVED_PROJECT_DIR" -name ".firebaserc" -delete
    
    # Remove package files
    find "$DERIVED_PROJECT_DIR" -name "package.json" -delete
    find "$DERIVED_PROJECT_DIR" -name "package-lock.json" -delete
    find "$DERIVED_PROJECT_DIR" -name "yarn.lock" -delete
    
    echo "Cleaned configuration files from derived data"
else
    echo "No derived data directory found for project: $PROJECT_NAME"
fi

# Clean from project directory
echo "Cleaning from project directory..."

# Remove any stray configuration files from the project directory
find "$PROJECT_DIR" -maxdepth 1 -name ".editorconfig" -delete
find "$PROJECT_DIR" -maxdepth 1 -name ".eslintrc" -delete
find "$PROJECT_DIR" -maxdepth 1 -name ".jshintrc" -delete
find "$PROJECT_DIR" -maxdepth 1 -name ".npmignore" -delete
find "$PROJECT_DIR" -maxdepth 1 -name ".eslintrc.js" -delete
find "$PROJECT_DIR" -maxdepth 1 -name ".eslintrc.json" -delete
find "$PROJECT_DIR" -maxdepth 1 -name ".jshintrc.json" -delete
find "$PROJECT_DIR" -maxdepth 1 -name ".editorconfig.json" -delete
find "$PROJECT_DIR" -maxdepth 1 -name ".nycrc" -delete
find "$PROJECT_DIR" -maxdepth 1 -name ".travis.yml" -delete
find "$PROJECT_DIR" -maxdepth 1 -name "FUNDING.yml" -delete

echo "Build conflicts cleaned successfully!"
echo "You can now build your project without the multiple command conflicts." 
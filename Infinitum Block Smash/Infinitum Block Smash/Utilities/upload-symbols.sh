#!/bin/bash

# Script to upload dSYM files to Firebase Crashlytics
# This script should be run as a build phase in Xcode

# Find the GoogleService-Info.plist file
GOOGLE_SERVICE_INFO_PLIST="${PROJECT_DIR}/GoogleService-Info.plist"

# Check if the file exists
if [ ! -f "$GOOGLE_SERVICE_INFO_PLIST" ]; then
    echo "Error: GoogleService-Info.plist not found at $GOOGLE_SERVICE_INFO_PLIST"
    exit 1
fi

# Find the dSYM file
DSYM_PATH="${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"

# Check if the dSYM file exists
if [ ! -d "$DSYM_PATH" ]; then
    echo "Error: dSYM file not found at $DSYM_PATH"
    exit 1
fi

# Upload the dSYM file to Firebase Crashlytics
"${PODS_ROOT}/FirebaseCrashlytics/upload-symbols" -gsp "$GOOGLE_SERVICE_INFO_PLIST" -p ios "$DSYM_PATH"

echo "dSYM file uploaded successfully" 
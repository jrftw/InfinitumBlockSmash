#!/bin/bash

# Remove Services directory from app bundle to prevent configuration files from being included
# This script should be run as a "Run Script" build phase in Xcode

echo "Removing Services directory from app bundle..."

# Get the app bundle path
APP_BUNDLE="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"

# Remove Services directory if it exists
if [ -d "${APP_BUNDLE}/Services" ]; then
    echo "Removing ${APP_BUNDLE}/Services"
    rm -rf "${APP_BUNDLE}/Services"
fi

# Remove firebase.json if it exists
if [ -f "${APP_BUNDLE}/firebase.json" ]; then
    echo "Removing ${APP_BUNDLE}/firebase.json"
    rm -f "${APP_BUNDLE}/firebase.json"
fi

# Remove .firebaserc if it exists
if [ -f "${APP_BUNDLE}/.firebaserc" ]; then
    echo "Removing ${APP_BUNDLE}/.firebaserc"
    rm -f "${APP_BUNDLE}/.firebaserc"
fi

echo "Services directory cleanup completed." 
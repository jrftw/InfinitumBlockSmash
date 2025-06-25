#!/bin/bash

# Firebase Functions Deployment Script
# This script builds and deploys the updated leaderboard cleanup functions

echo "🚀 Starting Firebase Functions deployment..."

# Navigate to the functions directory
cd "$(dirname "$0")"

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found. Make sure you're in the firebase-functions directory."
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Build the TypeScript functions
echo "🔨 Building functions..."
npm run build

# Check if build was successful
if [ ! -f "lib/index.js" ]; then
    echo "❌ Error: Build failed. lib/index.js not found."
    exit 1
fi

# Deploy the functions
echo "🚀 Deploying functions to Firebase..."
firebase deploy --only functions

# Check deployment status
if [ $? -eq 0 ]; then
    echo "✅ Functions deployed successfully!"
    echo ""
    echo "📋 Deployed functions:"
    echo "  - dailyLeaderboardReset (runs daily at midnight EST)"
    echo "  - weeklyLeaderboardReset (runs weekly on Sundays at midnight EST)"
    echo "  - monthlyLeaderboardReset (runs monthly on last day at midnight EST)"
    echo "  - cleanupLeaderboards (legacy function - deprecated)"
    echo ""
    echo "🔍 You can monitor the functions in the Firebase Console:"
    echo "   https://console.firebase.google.com/project/infinitum-stack-smash/functions"
else
    echo "❌ Deployment failed!"
    exit 1
fi 
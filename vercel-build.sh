#!/bin/bash

# Exit on error
set -e

# Clone Flutter stable if not already there
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PATH:`pwd`/flutter/bin"

# Disable analytics to speed up build
flutter config --no-analytics

# Generate .env from Vercel environment variables if it doesn't exist
# This allows you to set these in the Vercel dashboard instead of committing the file
if [ ! -f ".env" ]; then
  echo "Generating .env file from environment variables..."
  echo "AUTH0_DOMAIN=$AUTH0_DOMAIN" > .env
  echo "AUTH0_CLIENT_ID=$AUTH0_CLIENT_ID" >> .env
  echo "SUPABASE_URL=$SUPABASE_URL" >> .env
  echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
fi

# Build the web app — force JS renderer (auth0_flutter is WASM-incompatible)
echo "Building Flutter Web..."
flutter build web --release --no-wasm-dry-run

echo "Build complete."

#!/bin/sh
set -e

git clone https://github.com/flutter/flutter.git --depth 1 -b stable /tmp/flutter
export PATH="$PATH:/tmp/flutter/bin"

flutter pub get
flutter build web --release \
  --dart-define=RECAPTCHA_SITE_KEY=$RECAPTCHA_SITE_KEY \
  --dart-define=API_BASE_URL=$API_BASE_URL \
  --dart-define=GEOAPIFY_API_KEY=$GEOAPIFY_API_KEY \
  --dart-define=GEOAPIFY_MAP_STYLE=$GEOAPIFY_MAP_STYLE \
  --dart-define=DEFAULT_MAP_CENTER=$DEFAULT_MAP_CENTER \
  --dart-define=APP_ENV=$APP_ENV \
  --dart-define=APP_ENV_LABEL=$APP_ENV_LABEL

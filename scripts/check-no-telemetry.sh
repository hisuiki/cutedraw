#!/usr/bin/env bash

set -euo pipefail

patterns='telemetry|analytics|sentry|posthog|amplitude|plausible|segment\.com|google.?analytics|gtag\(|mixpanel|statsig|datadog|newrelic|trackEvent|track_event|matomo|sa_event|sa_pageview|fathom'

if git grep -n -i -E "$patterns" -- \
  ':!yarn.lock' \
  ':!dev-docs/yarn.lock' \
  ':!packages/excalidraw/CHANGELOG.md' \
  ':!dev-docs/docs/introduction/development.mdx' \
  ':!package.json' \
  ':!README.md' \
  ':!PRIVACY.md' \
  ':!scripts/wasm/woff2.wasm' \
  ':!scripts/check-no-telemetry.sh' \
  ':!scripts/remove-telemetry-instrumentation.pl'; then
  echo "Telemetry references remain in tracked source files." >&2
  exit 1
fi

if git grep -n -i -E 'sentry|posthog|amplitude|plausible|mixpanel|statsig|datadog|newrelic|matomo|firebase/analytics' -- \
  'package.json' \
  '*/package.json'; then
  echo "Telemetry dependencies remain in package manifests." >&2
  exit 1
fi

echo "No telemetry references found in tracked source files."

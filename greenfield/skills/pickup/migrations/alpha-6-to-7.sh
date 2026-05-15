#!/usr/bin/env bash
# alpha-6-to-7.sh — R6 NEW migration: alpha.6 -> alpha.7
#
# 1. For each of the 9 new phases, insert {skipped: true} default.
# 2. For each of the 6 inline gates, write {needed: null, vendor: null}.
# 3. Split phases.pluginDiscovery -> phases.pluginRecommendation + phases.pluginInstall
#    (preserves resume state — copies installed[] forward, not resetting).
# 4. Add phases.cicdAndDelivery.lockedYaml = null + adjustHistory = [].
# 5. Update meta.schemaVersion = "alpha.7".

set -euo pipefail
command -v jq >/dev/null || { echo "alpha-6-to-7: jq required" >&2; exit 2; }

INPUT=$(cat)
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REASON_R6="Round 6 phase added 2026-05-15; pre-R6 sessions skip"

echo "$INPUT" | jq --arg ts "$NOW" --arg reason "$REASON_R6" '
  # 1. Nine new phases default-skipped
  .phases = (.phases // {})
  | .phases.search                = (.phases.search                // {skipped: true, deferredReason: $reason})
  | .phases.caching               = (.phases.caching               // {skipped: true, deferredReason: $reason})
  | .phases.realtime              = (.phases.realtime              // {skipped: true, deferredReason: $reason})
  | .phases.fileUploads           = (.phases.fileUploads           // {skipped: true, deferredReason: $reason})
  | .phases.payments              = (.phases.payments              // {skipped: true, deferredReason: $reason})
  | .phases.frontendArchitecture  = (.phases.frontendArchitecture  // {skipped: true, deferredReason: $reason})
  | .phases.designSystem          = (.phases.designSystem          // {skipped: true, deferredReason: $reason})
  | .phases.uxAccessibilityPerf   = (.phases.uxAccessibilityPerf   // {skipped: true, deferredReason: $reason})
  | .phases.i18nL10n              = (.phases.i18nL10n              // {skipped: true, deferredReason: $reason})

  # If the legacy "frontend" stub exists, drop it (we renamed to frontendArchitecture)
  | (if .phases.frontend then del(.phases.frontend) else . end)

  # 2. Six inline gates default to {needed: null, vendor: null}
  | .phases.auth = (.phases.auth // {})
  | .phases.auth.concerns = (.phases.auth.concerns // {})
  | .phases.auth.concerns.transactionalEmail = (.phases.auth.concerns.transactionalEmail // {needed: null, vendor: null})
  | .phases.auth.concerns.sms                = (.phases.auth.concerns.sms                // {needed: null, vendor: null})

  | .phases.uxAccessibilityPerf.concerns = (.phases.uxAccessibilityPerf.concerns // {})
  | .phases.uxAccessibilityPerf.concerns.marketingEmail    = (.phases.uxAccessibilityPerf.concerns.marketingEmail    // {needed: null, vendor: null})
  | .phases.uxAccessibilityPerf.concerns.pushNotifications = (.phases.uxAccessibilityPerf.concerns.pushNotifications // {needed: null, vendor: null})
  | .phases.uxAccessibilityPerf.concerns.productAnalytics  = (.phases.uxAccessibilityPerf.concerns.productAnalytics  // {needed: null, vendor: null})

  | .phases.cicdAndDelivery = (.phases.cicdAndDelivery // {})
  | .phases.cicdAndDelivery.concerns = (.phases.cicdAndDelivery.concerns // {})
  | .phases.cicdAndDelivery.concerns.featureGating = (.phases.cicdAndDelivery.concerns.featureGating // {needed: null, vendor: null})

  # 3. Split pluginDiscovery -> pluginRecommendation + pluginInstall
  | (if .phases.pluginDiscovery then
       .phases.pluginRecommendation = {
         suggested: (.phases.pluginDiscovery.suggested // []),
         selected:  (.phases.pluginDiscovery.selected  // []),
         rationale: (.phases.pluginDiscovery.rationale // ""),
         frontendAddenda: []
       }
       | .phases.pluginInstall = {
           installed: (.phases.pluginDiscovery.installed // []),
           failed:    (.phases.pluginDiscovery.failed    // []),
           skipped:   (.phases.pluginDiscovery.skipped   // [])
         }
       | del(.phases.pluginDiscovery)
     else
       # Fresh state — initialize empty
       .phases.pluginRecommendation = (.phases.pluginRecommendation // {suggested: [], selected: [], rationale: "", frontendAddenda: []})
       | .phases.pluginInstall      = (.phases.pluginInstall      // {installed: [], failed: [], skipped: []})
     end)

  # 4. cicdAndDelivery.lockedYaml + adjustHistory
  | .phases.cicdAndDelivery.lockedYaml = (.phases.cicdAndDelivery.lockedYaml // null)
  | .phases.cicdAndDelivery.adjustHistory = (.phases.cicdAndDelivery.adjustHistory // [])

  # 5. Version bump + migration audit
  | .meta = (.meta // {})
  | .meta.schemaVersion = "alpha.7"
  | .meta.migrations = (.meta.migrations // []) + [{at: $ts, from: "alpha.6", to: "alpha.7"}]
'

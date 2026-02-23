#!/bin/bash
TITLE="${1:-Claude Code}"
MESSAGE="${2:-Notification}"
SOUND="${3:-Ping}"
ACTIVATE="${4:-com.microsoft.VSCode}"
terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound "$SOUND" -activate "$ACTIVATE"

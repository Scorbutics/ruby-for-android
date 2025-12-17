#!/bin/sh
# verify_ruby_extensions.sh
# Verifies that critical Ruby extensions requiring external libraries were built successfully
# Usage: verify_ruby_extensions.sh <build_log_file>

set -e

BUILD_LOG="$1"

if [ -z "$BUILD_LOG" ] || [ ! -f "$BUILD_LOG" ]; then
    echo "ERROR: Build log file not found: $BUILD_LOG" >&2
    exit 1
fi

# Critical extensions that require external dependencies
CRITICAL_EXTS="zlib openssl readline dbm"

echo "Checking for missing critical Ruby extensions..."

# Check if any extensions failed to compile
if grep -q "Following extensions are not compiled:" "$BUILD_LOG"; then
    echo ""
    echo "========================================" >&2
    echo "ERROR: Some extensions failed to build!" >&2
    echo "========================================" >&2
    echo "" >&2

    # Extract the list of failed extensions
    FAILED_EXTS=$(awk '/Following extensions are not compiled:/,/Fix the problems/' "$BUILD_LOG" | grep -E '^\w+:$' | sed 's/:$//')

    # Check if any critical extensions failed
    CRITICAL_FAILED=""
    for ext in $CRITICAL_EXTS; do
        if echo "$FAILED_EXTS" | grep -q "^${ext}$"; then
            CRITICAL_FAILED="$CRITICAL_FAILED $ext"
        fi
    done

    if [ -n "$CRITICAL_FAILED" ]; then
        echo "CRITICAL extensions that failed:$CRITICAL_FAILED" >&2
        echo "" >&2
        echo "These extensions require external libraries:" >&2
        echo "  - zlib: compression support (required by RubyGems)" >&2
        echo "  - openssl: SSL/TLS and crypto (required for HTTPS)" >&2
        echo "  - readline: line editing in IRB" >&2
        echo "  - dbm: DBM database support" >&2
        echo "" >&2
        echo "Full error details:" >&2
        awk '/Following extensions are not compiled:/,/Fix the problems/' "$BUILD_LOG" >&2
        echo "" >&2
        exit 1
    else
        echo "WARNING: Some non-critical extensions failed to build:" >&2
        echo "$FAILED_EXTS" >&2
        echo "" >&2
        echo "Build will continue, but some features may be unavailable." >&2
    fi
fi

echo "✓ All critical extensions built successfully"
exit 0

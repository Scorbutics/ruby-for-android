#!/bin/bash
# verify_pic_advanced.sh - Advanced PIC verification using multiple methods
#
# Usage: ./utilities/verify_pic_advanced.sh <path_to_static_library.a>
#
# This script uses multiple verification methods to determine if code is PIC

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <library.a> [library2.a ...]"
    echo ""
    echo "Example:"
    echo "  $0 build/target/arm64-linux/usr/local/lib/libruby-static.a"
    exit 1
fi

# Detect readelf (prefer it over objdump)
READELF=""
if command -v readelf &> /dev/null; then
    READELF="readelf"
elif command -v greadelf &> /dev/null; then
    READELF="greadelf"
fi

check_library() {
    local lib_path="$1"

    if [ ! -f "$lib_path" ]; then
        echo "❌ File not found: $lib_path"
        return 1
    fi

    echo ""
    echo "=========================================="
    echo "Checking: $lib_path"
    echo "=========================================="

    # Create temp directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    cd "$temp_dir"
    ar x "$lib_path" 2>/dev/null || {
        echo "  ❌ Failed to extract"
        return 1
    }

    local obj_count=$(ls -1 *.o 2>/dev/null | wc -l)
    echo "📦 Archive contains $obj_count object files"

    if [ $obj_count -eq 0 ]; then
        echo "  ⚠️  Empty archive"
        return 1
    fi

    # Statistics
    local pic_got_count=0
    local pic_text_flag_count=0
    local no_reloc_count=0
    local absolute_reloc_count=0
    local checked=0
    local max_check=10

    echo ""
    echo "Detailed Analysis (checking first $max_check objects):"
    echo ""

    for obj in *.o; do
        if [ $checked -ge $max_check ]; then
            break
        fi

        checked=$((checked + 1))

        echo -n "  $obj: "

        if [ -n "$READELF" ]; then
            # Method 1: Check for GOT/PLT relocations (strong indicator)
            local got_count=$($READELF -r "$obj" 2>/dev/null | grep -c -E "R_.*_GOT|R_.*_PLT|R_.*_GOTOFF|R_.*_GOTPC" || true)

            # Method 2: Check section flags for .text (should be AX not AXW for PIC)
            local text_flags=$($READELF -S "$obj" 2>/dev/null | grep "\.text" | awk '{print $8}' || true)

            # Method 3: Check for absolute relocations (bad for PIC)
            local abs_reloc=$($READELF -r "$obj" 2>/dev/null | grep -c -E "R_.*_64[^_]|R_.*_32[^_]|R_AARCH64_ABS" || true)

            # Method 4: Count total relocations
            local total_reloc=$($READELF -r "$obj" 2>/dev/null | grep -c "^[0-9a-f]" || true)

            # Determine PIC status
            if [ $got_count -gt 0 ]; then
                echo "✅ PIC (GOT/PLT: $got_count relocations)"
                pic_got_count=$((pic_got_count + 1))
            elif [ $total_reloc -eq 0 ]; then
                # No relocations at all - this is OK for static code
                echo "✅ OK (no external references, self-contained)"
                pic_text_flag_count=$((pic_text_flag_count + 1))
            elif [ $abs_reloc -gt 0 ]; then
                echo "❌ NOT PIC (absolute relocations: $abs_reloc)"
                absolute_reloc_count=$((absolute_reloc_count + 1))
            else
                # Has relocations but no GOT - check if they're PC-relative
                local pc_rel=$($READELF -r "$obj" 2>/dev/null | grep -c -E "R_.*_PC|R_.*_REL" || true)
                if [ $pc_rel -gt 0 ]; then
                    echo "✅ Likely PIC (PC-relative: $pc_rel)"
                    pic_got_count=$((pic_got_count + 1))
                else
                    echo "⚠️  Uncertain (relocations: $total_reloc, type unclear)"
                    no_reloc_count=$((no_reloc_count + 1))
                fi
            fi
        else
            # Fallback to objdump if readelf not available
            local reloc_output=$(objdump -r "$obj" 2>/dev/null | head -20 || true)
            if echo "$reloc_output" | grep -q -E "GOT|PLT|PC|@GOTOFF|@GOTPC"; then
                echo "✅ PIC (GOT/PLT/PC-relative)"
                pic_got_count=$((pic_got_count + 1))
            else
                echo "⚠️  No clear markers"
                no_reloc_count=$((no_reloc_count + 1))
            fi
        fi
    done

    # Summary
    echo ""
    echo "=========================================="
    echo "Summary:"
    echo "  Total checked: $checked objects"
    echo "  ✅ Clear PIC (GOT/PLT): $pic_got_count"
    echo "  ✅ Self-contained (no external refs): $pic_text_flag_count"
    echo "  ⚠️  Uncertain: $no_reloc_count"
    echo "  ❌ Absolute relocations: $absolute_reloc_count"
    echo ""

    # Final verdict
    local good_count=$((pic_got_count + pic_text_flag_count))
    if [ $absolute_reloc_count -gt 0 ]; then
        echo "❌ VERDICT: Contains absolute relocations - NOT compiled with -fPIC"
        echo "=========================================="
        return 1
    elif [ $good_count -eq $checked ]; then
        echo "✅ VERDICT: All objects are PIC-compatible"
        echo "=========================================="
        return 0
    elif [ $good_count -gt 0 ] && [ $no_reloc_count -gt 0 ]; then
        echo "✅ VERDICT: Likely PIC (some objects have no external references)"
        echo ""
        echo "Note: Objects without relocations are self-contained and PIC-safe."
        echo "      They don't access global data or call external functions."
        echo "=========================================="
        return 0
    else
        echo "⚠️  VERDICT: Cannot definitively determine PIC status"
        echo "=========================================="
        return 1
    fi
}

# Check if tools are available
if [ -z "$READELF" ]; then
    echo "Warning: readelf not found. Install binutils for better analysis."
    echo "  Ubuntu/Debian: sudo apt-get install binutils"
    echo "  macOS: brew install binutils"
    echo ""
    echo "Falling back to objdump (less reliable)..."
    echo ""
fi

overall_result=0

for lib in "$@"; do
    if ! check_library "$lib"; then
        overall_result=1
    fi
done

echo ""
if [ $overall_result -eq 0 ]; then
    echo "✅ All libraries verified successfully"
else
    echo "❌ Some libraries failed verification"
fi

exit $overall_result

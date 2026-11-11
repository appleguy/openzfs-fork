#!/bin/ksh -p
# SPDX-License-Identifier: CDDL-1.0
#
# Copyright (c) 2026, OpenZFS contributors.
#
# Exercise the libzpool-only root-ZAP ENXIO fault injector with disposable
# file-backed ztest pools.  No real disks or kernel pools are used.
#

. $STF_SUITE/include/libtest.shlib

verify_runnable "global"

# ztest spawns itself during initialization: give it an absolute executable.
ZTEST_BIN=$(whence -p ztest)
[[ -x "$ZTEST_BIN" ]] || log_fail "ztest executable unavailable"
ZTEST_AVZ_DIR="$TEST_BASE_DIR/ztest-avz-$$"

function cleanup
{
    rm -rf -- "$ZTEST_AVZ_DIR"
}

log_assert "Root-vdev ZAP activation defers on unavailable vdevs and retries"
log_onexit cleanup

for scenario in healthy fault remove write; do
    workdir="$ZTEST_AVZ_DIR/$scenario"
    logfile="$ZTEST_AVZ_DIR/$scenario.log"
    log_must mkdir -p "$workdir"
    log_must env ZTEST_AVZ_SCENARIO="$scenario" "$ZTEST_BIN" \
        -T 1 -P 1 -k 0 -v 1 -m 2 -r 2 -K raidz -d 1 -t 1 -s 64M \
        -p "ztestavz${scenario}$$" -f "$workdir" > "$logfile" 2>&1
    log_must grep -q 'AVZ_FAULT_TEST_HEALTHY_PASS' "$logfile"
    if [[ "$scenario" != healthy ]]; then
        log_must grep -q "AVZ_FAULT_TEST_DEFERRED_PASS mode=$scenario" \
            "$logfile"
    fi
done

log_pass "Root ZAP deferred and linked after vdev recovery"

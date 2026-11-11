#!/bin/ksh -p
# SPDX-License-Identifier: CDDL-1.0
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# https://opensource.org/license/CDDL-1.0.
#
# Copyright (c) 2026, OpenZFS contributors.
#
# Exercise root-ZAP activation with missing or unavailable vdevs in
# disposable file-backed ztest pools.  No physical disks are used.
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

# ztest may re-exec itself by basename, including via a libtool wrapper.
log_must cd "$(dirname "$ZTEST_BIN")"

for scenario in healthy fault remove write ordered; do
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
    if [[ "$scenario" == ordered ]]; then
        log_must grep -q 'AVZ_ORDERED_REMOVAL_PASS' "$logfile"
    fi
done

log_pass "Root ZAP deferred and linked after vdev recovery"

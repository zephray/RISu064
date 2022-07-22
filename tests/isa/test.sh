#!/bin/bash

PASS=0
FAIL=0
for test in *.bin; do
	if ../../sim/simulator --ram "$test" --cycles 200000 > /dev/null; then
		echo "Passed $test"
		PASS=$((PASS+1))
	else
		echo "Failed $test"
		FAIL=$((FAIL+1))
	fi
done
echo "Passed $PASS tests, failed $FAIL tests."
exit $FAIL

#!/bin/bash

PASS=0
FAIL=0
for test in *.bin; do
	for ilat in {0..5}
	do
		for dlat in {0..5}
		do
			if ../../sim/simulator --ram "$test" --cycles 100000 --ilat $ilat --dlat $dlat > /dev/null; then
				echo "Passed $test (IL=$ilat, DL=$dlat)"
				PASS=$((PASS+1))
			else
				echo "Failed $test (IL=$ilat, DL=$dlat)"
				FAIL=$((FAIL+1))
			fi
		done
	done
done
echo "Passed $PASS tests, failed $FAIL tests."
exit $FAIL

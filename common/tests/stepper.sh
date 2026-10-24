#!/bin/sh
# Exercise the public runner protocol with real processes and private fixtures.
set -u
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runner=$root/lib/stepper.sh
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' 0
trap 'exit 130' INT
trap 'exit 143' TERM
shell=${1:-sh}
checks=0

# Each case asserts a grading result and a diagnostic, then checks cleanup.
check() {
    name=$1; expected=$2; diagnostic=$3
    case_root=$test_root/$name
    mkdir -p "$case_root/inputs" "$case_root/tmp"
    cat > "$case_root/inputs/test.transcript"
    printf '%s\n' "$program" > "$case_root/student.sh"
    (
        cd "$case_root" || exit 2
        export TMPDIR=$case_root/tmp STEPPER_TIMEOUT=1 STEPPER_DIR=inputs
        export STEPPER_POSTERRORLINES=15 STEPPER_GRADE=false
        "$shell" "$runner" -- sh student.sh
    ) > "$case_root/log" 2>&1
    actual=$?
    if [ "$actual" -ne "$expected" ] || ! grep -Eq -- "$diagnostic" "$case_root/log"; then
        printf 'FAIL %s: status %s, expected %s; diagnostic %s\n' "$name" "$actual" "$expected" "$diagnostic"
        cat "$case_root/log"
        exit 1
    fi
    if [ -n "$(ls -A "$case_root/tmp")" ]; then
        printf 'FAIL %s: temporary files remain\n' "$name"
        exit 1
    fi
    checks=$((checks + 1))
}

# EOF is required even when no input actions exist, and after the last input.
program='cat >/dev/null; printf "done\n"'
check no-input 0 '✔ Test Passed' <<'EOF'
> done
EOF
program='printf "prompt\n"; IFS= read -r line; printf "%s\n" "$line"; cat >/dev/null; printf "done\n"'
check dialogue 0 '✔ Test Passed' <<'EOF'
> prompt
< a b \ c
> a b \ c
> done
EOF
program='exit 0'
check empty 0 '✔ Test Passed' <<'EOF'
EOF

# Streams have independent ordering; their terminal display follows the fixture.
program='printf "err\n" >&2; printf "out\n"'
check interleaved 0 '✔ Test Passed' <<'EOF'
> out
! err
EOF
program='printf "one\ntwo\n" >&2; printf "three\n"'
check display-order 0 '✔ Test Passed' <<'EOF'
! one
> three
! two
EOF
escape=$(printf '\033')
sed "s/$escape\[[0-9;]*m//g" "$case_root/log" > "$case_root/plain"
awk '/^one⏎$/ { a=NR } /^three⏎$/ { b=NR } /^two⏎$/ { c=NR }
    END { exit !(a && a < b && b < c) }' "$case_root/plain" || exit 1

# The student waits for release until its first line reaches the console log.
# Exercise both modes and verify forwarding neither repeats nor reorders lines.
for live_grade in false true; do
    case_root=$test_root/live-$live_grade
    mkdir -p "$case_root/inputs" "$case_root/tmp"
    printf '> early\n> late\n' > "$case_root/inputs/test.transcript"
    (
        cd "$case_root" || exit 2
        export TMPDIR=$case_root/tmp STEPPER_DIR=inputs STEPPER_TIMEOUT=10
        export STEPPER_GRADE=$live_grade
        exec "$shell" "$runner" -- sh -c '
            printf "early\n"
            while [ ! -f release ]; do sleep 1; done
            printf "late\n"
        '
    ) > "$case_root/log" 2>&1 & manager=$!
    attempt=0
    while ! grep -q '^early' "$case_root/log" && [ "$attempt" -lt 5 ]; do
        sleep 1
        attempt=$((attempt + 1))
    done
    if ! grep -q '^early' "$case_root/log" || ! kill -0 "$manager" 2>/dev/null; then
        printf 'FAIL live-%s: feedback unavailable while case is running\n' "$live_grade"
        kill -TERM "$manager" 2>/dev/null || :
        wait "$manager"
        cat "$case_root/log"
        exit 1
    fi
    : > "$case_root/release"
    wait "$manager" || { cat "$case_root/log"; exit 1; }
    sed "s/$escape\[[0-9;]*m//g" "$case_root/log" > "$case_root/plain"
    awk '/^early⏎$/ { a=NR; early++ } /^late⏎$/ { b=NR; late++ }
        /✔ Test Passed/ { c=NR } /^Passed / { d=NR }
        END { exit !(early == 1 && late == 1 && a < b && b < c && c < d) }' \
        "$case_root/plain" || exit 1
    [ -z "$(ls -A "$case_root/tmp")" ] || exit 1
    if [ "$live_grade" = true ]; then
        grep -q 'tests="1" failures="0"' "$case_root/test_detail.xml" || exit 1
    fi
    checks=$((checks + 1))
done

# Output failures retain the mismatched record, partial tail, and next input.
program='printf "wrong\nmore\n"'
check mismatch 1 'MISMATCHED LINE:.*wrong' <<'EOF'
> right
> more
< next
EOF
program='printf "wrong\n" >&2'
check stderr-mismatch 1 'Output mismatch on stderr' <<'EOF'
! right
EOF
program='printf "partial"'
check partial 1 'no newline' <<'EOF'
> partial
EOF
program='printf "extra\n"'
check extra 1 'unexpected extra output after completion' <<'EOF'
EOF
program='printf "\000ok\n"'
check binary 1 'Reason:' <<'EOF'
> ok
EOF
program='printf "early\n"; sleep 5'
check early 1 'before expected input' <<'EOF'
< input
> early
EOF
program='printf "early\n" >&2; sleep 5'
check early-stderr 1 'before expected input' <<'EOF'
< input
! early
EOF

# Termination, missing output, and blocked writes all have bounded waits.
program='exit 7'
check nonzero 1 'non-zero status code: 7' <<'EOF'
EOF
program='exit 7'
check missing 1 'before producing expected output' <<'EOF'
> absent
EOF
program='sleep 5'
check timeout-output 1 'Timeout' <<'EOF'
> absent
EOF
program='printf "done\n"; sleep 5'
check timeout-exit 1 'Timeout' <<'EOF'
> done
EOF
program='sleep 5'
awk 'BEGIN { printf "< "; for(i=0;i<100000;i++) printf "x"; print "" }' > "$test_root/large"
check blocked-input 1 'Timeout' < "$test_root/large"
program='IFS= read -r line; printf "%s\n" "$line"'
sed 's/^< /> /' "$test_root/large" >> "$test_root/large.expected"
cat "$test_root/large" "$test_root/large.expected" > "$test_root/large.dialogue"
check long-line 0 '✔ Test Passed' < "$test_root/large.dialogue"
program='exec 0<&-; printf "ready\n"; sleep 5'
printf '> ready\n' > "$test_root/closed-input.transcript"
cat "$test_root/large" >> "$test_root/closed-input.transcript"
check closed-input 1 'closed its input stream prematurely' < "$test_root/closed-input.transcript"
grep -q 'EXPECTED STDIN:' "$case_root/log" || exit 1

# Author errors fail cleanly before starting the program.
program='exit 0'
check invalid-record 1 'Invalid transcript record on line 1' <<'EOF'
bad
EOF
printf '> no newline' > "$test_root/invalid"
check invalid-ending 1 'Transcript must end with a newline' < "$test_root/invalid"
printf '> \000\n' > "$test_root/invalid"
check invalid-nul 1 'Transcript contains NUL bytes' < "$test_root/invalid"

# Placeholder substitution preserves whole arguments, including shell syntax.
case_root=$test_root/arguments
mkdir -p "$case_root/inputs with spaces"
printf '> done\n' > "$case_root/inputs with spaces/test.transcript"
printf 'done\n' > "$case_root/inputs with spaces/test.input"
(
    cd "$case_root" || exit 2
    export STEPPER_DIR='inputs with spaces' STEPPER_TIMEOUT=1
    "$shell" "$runner" -- sh -c '
        [ "$1" = "inputs with spaces/test.input" ] || exit 3
        [ "$2" = "preinputs with spaces/test.input:inputs with spaces/test.input" ] || exit 4
        [ "$3" = "literal \$(touch unexpected)" ] || exit 5
        cat "$1"
    ' student '@INPUT@' 'pre@INPUT@:@INPUT@' 'literal $(touch unexpected)'
) > "$case_root/log" 2>&1 || { cat "$case_root/log"; exit 1; }
[ ! -e "$case_root/unexpected" ] || exit 1
checks=$((checks + 1))

# Grade mode continues after failures and exports readable, XML-safe feedback.
case_root=$test_root/grade
mkdir -p "$case_root/inputs"
printf '> <bad>& "quote"\n' > "$case_root/inputs/1.transcript"
printf '> <tag>& "quote"\n' > "$case_root/inputs/2.transcript"
(
    cd "$case_root" || exit 2
    export STEPPER_DIR=inputs STEPPER_TIMEOUT=1 STEPPER_GRADE=true
    "$shell" "$runner" -- sh -c 'printf '\''<tag>& "quote"\n'\'''
) > "$case_root/log" 2>&1
[ "$?" -eq 1 ] || { cat "$case_root/log"; exit 1; }
grep -q 'tests="2" failures="1"' "$case_root/test_detail.xml" || exit 1
grep -q 'status="failed"' "$case_root/test_detail.xml" || exit 1
grep -q 'MISMATCHED LINE:.*&lt;tag&gt;&amp;' "$case_root/test_detail.xml" || exit 1
if grep -q "$escape" "$case_root/test_detail.xml"; then exit 1; fi
if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout "$case_root/test_detail.xml" || exit 1
fi
checks=$((checks + 1))

# Feedback mode reports attempted counts rather than counting unrun tests as passes.
(
    cd "$case_root" || exit 2
    export STEPPER_DIR=inputs STEPPER_TIMEOUT=1 STEPPER_GRADE=false
    "$shell" "$runner" -- sh -c 'printf '\''<tag>& "quote"\n'\'''
) > "$case_root/log" 2>&1
[ "$?" -eq 1 ] || exit 1
grep -q 'Passed 0/1 tests.*(2 total)' "$case_root/log" || exit 1
checks=$((checks + 1))

# Interrupting the manager also terminates the supervised process and helpers.
case_root=$test_root/interrupted
mkdir -p "$case_root/inputs" "$case_root/tmp"
printf '> absent\n' > "$case_root/inputs/test.transcript"
(
    cd "$case_root" || exit 2
    export TMPDIR=$case_root/tmp STEPPER_DIR=inputs STEPPER_TIMEOUT=5
    exec "$shell" "$runner" -- sh -c 'echo $$ > student.pid; exec sleep 30'
) > "$case_root/log" 2>&1 & manager=$!
attempt=0
while [ ! -f "$case_root/student.pid" ] && [ "$attempt" -lt 5 ]; do
    sleep 1
    attempt=$((attempt + 1))
done
[ -f "$case_root/student.pid" ] || { kill -TERM "$manager"; wait "$manager"; exit 1; }
student=$(cat "$case_root/student.pid")
kill -TERM "$manager"
wait "$manager"
[ "$?" -eq 143 ] || exit 1
if kill -0 "$student" 2>/dev/null; then printf 'FAIL interrupted: student remains\n'; exit 1; fi
[ -z "$(ls -A "$case_root/tmp")" ] || exit 1
checks=$((checks + 1))
printf 'PASS %s: %s cases\n' "$shell" "$checks"

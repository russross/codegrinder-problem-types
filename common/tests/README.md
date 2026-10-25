Stepper review and regression checks
====================================

Run the regression suite from the project root:

```sh
make -C common test
```

The test script's optional argument selects the shell that runs `common/stepper.sh`:
`sh common/tests/stepper.sh /path/to/shell`. To test a
BusyBox environment, install its applet links in a temporary directory, put
that directory first in `PATH`, and select its `sh`. The suite uses standard
Unix utilities. It also validates XML with `xmllint` when available.

Behavioral comparison
---------------------

Both runners compare complete lines, preserve order within each output stream,
send transcript input, require a zero exit status, reject trailing output, and
stop on the first failed test unless grading. Grade mode runs every fixture and
writes `test_detail.xml` with a failure element for each failed case.

The shell implementation compiles transcript records into per-stream expected
files and output phases ending at input records. Independent readers capture
stdout and stderr while a separate writer delivers input. The manager checks
matched records, input acknowledgments, exit status, and stream EOF. A pass
also requires an exact comparison of each complete raw stream, so shell `read`
discarding a NUL cannot cause incorrect acceptance.

Retained differences are:

*   Output beyond a phase's expected byte count fails before the next input is
    supplied. Python buffers that output for later comparison. This stricter
    rule is intentional. The next phase opens before the input writer wakes,
    permitting responses without requiring synchronous input consumption.
*   Shell timeouts use integer, one-second ticks and reset on matched output or
    input acknowledgment. They cover blocked writes and final termination.
    Python has no bounded wait after its transcript loop, can block writing
    stdin, and leaves stdin open when there are no input records.
*   The shell validates exact record prefixes, a final newline, and absence of
    NUL bytes. Python validates only the action character and normalizes CRLF
    when reading transcripts. Shell comparisons preserve carriage returns and
    compare bytes; Python decodes output as UTF-8 with replacement.
*   Shell command arguments are supplied separately after `--`. Embedded
    `@INPUT@` substitution preserves argument boundaries and cannot execute
    shell syntax. `STEPPER_INPUT_TRANSFORM` uses portable sed expressions;
    Python uses Python regular expressions and reparses the substituted command.
*   Successful display follows transcript order: stdout uses the default foreground,
    stdin cyan, and stderr magenta. Actual newline markers use the stream color
    with ANSI dim. Commands use a simple `$` prompt with arguments displayed
    literally; execution preserves argument boundaries independently.
*   Failure reports show one inverse-video block from the failing stream, followed
    by a bold red explanation and expected output when applicable. Both blocks
    stop at five lines and 20,000 bytes, with explicit truncation notices; expected
    context also stops before the next input. This fixed limit replaces
    `STEPPER_POSTERRORLINES`. Control bytes are escaped, UTF-8 remains readable,
    and unterminated fragments have `[no newline]` rather than a newline marker.
    Subsequent output is captured until cleanup rather than actively awaited.

Each test ends with a green checkmark or one bold red failure line, then one
blank line. Failures distinguish incorrect output, early or extra output,
premature EOF, timeouts, input closure, and observed nonzero exit status.
Only an exit status observed before cleanup appears in the report. The runner
reports the first detected failure and retains the single-line test summary.

JUnit failure text contains the substituted command and failure report, without
ANSI codes or the preceding successful dialogue. Test durations are integral.
The console summary counts attempted tests, so unrun fixtures are not counted
as passes. Any grading failure returns a nonzero status; the shell returns 1
rather than Python's failure count.

Boundaries
----------

Strict phase detection observes captured bytes, not the exact instant of a
student write. Scheduling can let output cross a phase boundary before it is
observed. This agrees with tolerating minor concurrency artifacts, but is not
a guarantee about when student code consumed stdin.

Cleanup terminates helpers and the supervised process, and makes a best-effort
attempt to terminate its descendants. An already orphaned or detached process
is outside that tree. Raw output and compiled transcript files have no disk
quota; the surrounding autograder's resource limits remain relevant. The
20,000-byte limit bounds displayed failure context, not capture storage.

Tests cover EOF without input, EOF after the last input, empty transcripts,
live feedback before case completion in both modes, stream interleaving and
display order, mismatches, partial lines, extra and
binary output, early output on both streams, nonzero exit, missing output,
timeouts, blocked and prematurely closed stdin, long lines, malformed
transcripts, argument substitution, XML logs, grading continuation, feedback
counts, and interruption cleanup.

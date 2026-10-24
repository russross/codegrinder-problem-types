Stepper review and regression checks
====================================

Run the regression suite from the project root:

```sh
sh tests/stepper.sh dash
sh tests/stepper.sh bash
sh tests/stepper.sh /path/to/bash-3.2
```

The optional argument selects the shell that runs `lib/stepper.sh`. To test a
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
*   Successful display follows transcript order and uses the same stream colors
    and visible line endings as Python. Failure reports use the same principal
    sections and aligned labels. Byte representations use double quotes and
    octal escapes for non-ASCII bytes. Context is bounded by bytes and lines;
    subsequent output is captured until cleanup rather than actively awaited.

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

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Reference transcript runner with nonblocking input and independent streams."""

from collections import deque
from dataclasses import dataclass, field
from enum import Enum
from os import environ, killpg, read, set_blocking, write
from pathlib import Path
from selectors import DefaultSelector, EVENT_READ, EVENT_WRITE
from shlex import split
from signal import SIGINT, SIGKILL, SIGTERM, SIGHUP, SIG_IGN, getsignal, signal
from subprocess import PIPE, Popen, TimeoutExpired, run
from sys import argv, exit, stderr
from time import monotonic
from typing import IO
from xml.etree.ElementTree import Element, ElementTree, SubElement


class Action(Enum):
    INPUT = b"< "
    OUTPUT = b"> "
    ERROR = b"! "


@dataclass(frozen=True)
class Record:
    action: Action
    content: bytes
    number: int


@dataclass
class Phase:
    output: deque[Record] = field(default_factory=deque)
    error: deque[Record] = field(default_factory=deque)
    input: Record | None = None


@dataclass
class Stream:
    name: str
    file: IO[bytes]
    expected: deque[Record]
    buffer: bytes = b""
    closed: bool = False


@dataclass(frozen=True)
class Result:
    name: str
    passed: bool
    log: str
    duration: float


class TestFailure(Exception):
    """An expected failure of student behavior, suitable for a concise report."""


# Parse before launching student code. Preserve bytes, including whitespace and
# carriage returns, and require explicit newlines on every transcript record.
def parse_transcript(path: Path) -> tuple[list[Record], list[Phase]]:
    records: list[Record] = []
    phases = [Phase()]
    data = path.read_bytes()
    if b"\0" in data:
        raise ValueError("Transcript contains NUL bytes")
    if data and not data.endswith(b"\n"):
        raise ValueError("Transcript must end with a newline")
    for number, line in enumerate(data.split(b"\n")[:-1], 1):
        try:
            action = Action(line[:2])
        except ValueError:
            raise ValueError(f"Invalid transcript record on line {number}") from None
        record = Record(action, line[2:] + b"\n", number)
        records.append(record)
        if action is Action.INPUT:
            phases[-1].input = record
            phases.append(Phase())
        elif action is Action.OUTPUT:
            phases[-1].output.append(record)
        else:
            phases[-1].error.append(record)
    return records, phases


# Student bytes appear as escaped literals in diagnostics and XML. Bound context
# in bytes as well as lines, while retaining unterminated fragments.
def context_lines(data: bytes, limit: int) -> list[str]:
    return [repr(line) for line in data[:20_000].splitlines(keepends=True)[:limit]]


def accept_output(stream: Stream, chunk: bytes) -> bool:
    stream.buffer += chunk
    made_progress = False
    while b"\n" in stream.buffer:
        line, rest = stream.buffer.split(b"\n", 1)
        actual = line + b"\n"
        if not stream.expected:
            raise TestFailure(f"Unexpected extra or out-of-sequence output on {stream.name}")
        if actual != stream.expected[0].content:
            raise TestFailure(f"Output mismatch on {stream.name}")
        record = stream.expected.popleft()
        print(record.action.value.decode() + actual.decode("utf-8", "backslashreplace"), end="", flush=True)
        stream.buffer = rest
        made_progress = True
    if stream.buffer and not stream.expected:
        raise TestFailure(f"Unexpected extra or out-of-sequence output on {stream.name}")
    return made_progress


def stop_process(proc: Popen[bytes]) -> None:
    # The reference runner can establish a process group, so it also terminates
    # descendants that retain inherited streams after the direct child exits.
    handlers = {signum: getsignal(signum) for signum in (SIGINT, SIGTERM, SIGHUP)}
    for signum in handlers:
        signal(signum, SIG_IGN)
    try:
        killpg(proc.pid, SIGTERM)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=0.2)
    except TimeoutExpired:
        pass
    try:
        killpg(proc.pid, SIGKILL)
    except ProcessLookupError:
        pass
    proc.wait()
    for pipe in (proc.stdin, proc.stdout, proc.stderr):
        if pipe is not None:
            pipe.close()
    for signum, handler in handlers.items():
        signal(signum, handler)


def run_case(command: list[str], transcript: Path, timeout: int, context: int) -> tuple[bool, str]:
    records, phases = parse_transcript(transcript)
    proc = Popen(command, stdin=PIPE, stdout=PIPE, stderr=PIPE, bufsize=0, start_new_session=True)
    assert proc.stdin is not None and proc.stdout is not None and proc.stderr is not None
    selector = DefaultSelector()
    phase_index = 0
    phase = phases[phase_index]
    output = Stream("stdout", proc.stdout, phase.output)
    error = Stream("stderr", proc.stderr, phase.error)
    pending: bytes | None = None
    remaining_inputs = len(phases) - 1
    next_record = 1
    last_progress = monotonic()

    # All three student descriptors are nonblocking. Input readiness is watched
    # only while an authorized line still has bytes left to deliver.
    try:
        for stream in (output, error):
            set_blocking(stream.file.fileno(), False)
            selector.register(stream.file, EVENT_READ, stream)
        set_blocking(proc.stdin.fileno(), False)
        if remaining_inputs == 0:
            proc.stdin.close()
        while True:
            if not output.expected and not error.expected and pending is None:
                if phase.input is not None:
                    if proc.poll() is not None:
                        raise TestFailure("Program exited before all input was sent")
                    pending = phase.input.content
                    next_record = phase.input.number
                    print("< " + pending.decode("utf-8", "backslashreplace"), end="", flush=True)
                    phase_index += 1
                    phase = phases[phase_index]
                    output.expected = phase.output
                    error.expected = phase.error
                    selector.register(proc.stdin, EVENT_WRITE)
                elif output.closed and error.closed and proc.poll() is not None:
                    if proc.returncode != 0:
                        raise TestFailure(f"Program exited with status {proc.returncode}")
                    return True, ""

            # EOF and exit are separate facts: either may occur first, and both
            # must be observed. The deadline also bounds final shutdown.
            for stream in (output, error):
                if stream.closed and stream.expected:
                    raise TestFailure(f"EOF before expected output on {stream.name}")
            if monotonic() - last_progress >= timeout:
                raise TestFailure("Timeout waiting for expected output, input delivery, or program termination")
            events = selector.select(0.05)
            for key, mask in events:
                if mask & EVENT_WRITE:
                    assert pending is not None
                    try:
                        size = write(proc.stdin.fileno(), pending)
                    except BlockingIOError:
                        continue
                    except BrokenPipeError:
                        raise TestFailure("Program closed its input stream prematurely") from None
                    pending = pending[size:]
                    if not pending:
                        selector.unregister(proc.stdin)
                        pending = None
                        remaining_inputs -= 1
                        last_progress = monotonic()
                        if remaining_inputs == 0:
                            proc.stdin.close()
                    continue

                stream = output if key.fileobj is output.file else error
                try:
                    chunk = read(stream.file.fileno(), 65536)
                except BlockingIOError:
                    continue
                if not chunk:
                    selector.unregister(stream.file)
                    stream.closed = True
                    if stream.buffer:
                        raise TestFailure(f"Unterminated output on {stream.name}")
                    continue
                # Only successfully matched records reset the progress deadline.
                if stream.expected:
                    next_record = stream.expected[0].number
                if accept_output(stream, chunk):
                    last_progress = monotonic()
    except TestFailure as failure:
        lines = [f"FAIL: {failure}", "Expected next records:"]
        expected = list(output.expected) + list(error.expected)
        if phase.input is not None:
            expected.append(phase.input)
        first = min((record.number for record in expected), default=next_record)
        lines.extend(repr(record.action.value + record.content) for record in records[first - 1:first - 1 + context])
        for stream in (output, error):
            lines.append(f"Actual {stream.name} (unmatched bytes):")
            lines.extend(context_lines(stream.buffer, context))
            if not stream.buffer:
                lines.append("(none)")
        status = proc.poll()
        if status is not None:
            lines.append(f"Exit status: {status}")
        return False, "\n".join(lines)
    finally:
        selector.close()
        stop_process(proc)


# Both implementations use portable sed basic regular expressions. Argument
# substitution happens after tokenization, preserving embedded spaces literally.
def input_path(transcript: Path, transform: str) -> str:
    result = run(["sed", transform], input=f"{transcript}\n", capture_output=True, text=True, check=False)
    if result.returncode:
        raise ValueError(f"Invalid input transform: {result.stderr.strip()}")
    return result.stdout.removesuffix("\n")


def xml_text(text: str) -> str:
    return "".join(char if char in "\t\n\r" or 32 <= ord(char) <= 0xD7FF or 0xE000 <= ord(char) <= 0xFFFD
                   or 0x10000 <= ord(char) <= 0x10FFFF else f"\\x{ord(char):02x}" for char in text)


def write_report(results: list[Result], duration: float) -> None:
    failures = sum(not result.passed for result in results)
    attributes = {
        "tests": str(len(results)), "failures": str(failures), "time": f"{duration:.3f}",
        "errors": "0", "skipped": "0", "disabled": "0",
    }
    root = Element("testsuites", attributes)
    suite = SubElement(root, "testsuite", attributes)
    for result in results:
        case = SubElement(suite, "testcase", {"name": xml_text(result.name), "time": f"{result.duration:.3f}"})
        if not result.passed:
            SubElement(case, "failure", {"type": "failure"}).text = xml_text(result.log)
    ElementTree(root).write("test_detail.xml", encoding="utf-8", xml_declaration=True)


def interrupted(signum: int, _frame: object) -> None:
    raise SystemExit(128 + signum)


def main() -> int:
    for signum in (SIGINT, SIGTERM, SIGHUP):
        signal(signum, interrupted)
    command = argv[1:]
    if command[:1] == ["--"]:
        command = command[1:]
    if not command:
        command = split(environ.get("STEPPER_CMD", ""))
    if not command:
        raise ValueError("usage: stepper.py -- command [argument ...]")
    directory = Path(environ.get("STEPPER_DIR", "inputs"))
    timeout = int(environ.get("STEPPER_TIMEOUT", "5"))
    context = int(environ.get("STEPPER_POSTERRORLINES", "15"))
    grade_value = environ.get("STEPPER_GRADE", "false")
    if timeout <= 0 or context < 0 or grade_value not in ("true", "false"):
        raise ValueError("Invalid timeout, context limit, or grade setting")
    if not directory.is_dir():
        raise ValueError(f"Not a directory: {directory}")
    if grade_value == "true":
        Path("test_detail.xml").unlink(missing_ok=True)
    transform = environ.get("STEPPER_INPUT_TRANSFORM", r"s/\.transcript$/.input/")

    # Count only attempted tests. Grade mode continues through invalid fixtures
    # and launch failures, which remain visible as failed cases in the XML.
    transcripts = sorted(directory.glob("*.transcript"))
    results: list[Result] = []
    start = monotonic()
    for transcript in transcripts:
        print(f"\n{transcript}", flush=True)
        case_start = monotonic()
        try:
            path = input_path(transcript, transform)
            actual_command = [arg.replace("@INPUT@", path) for arg in command]
            passed, log = run_case(actual_command, transcript, timeout, context)
        except (OSError, ValueError) as failure:
            passed, log = False, f"Stepper: {failure}"
        results.append(Result(transcript.name, passed, log, monotonic() - case_start))
        print("PASS" if passed else log, flush=True)
        if not passed and grade_value == "false":
            break
    failures = sum(not result.passed for result in results)
    print(f"\nPassed {len(results) - failures}/{len(results)} attempted tests ({len(transcripts)} total)")
    if not transcripts:
        print("Warning: no transcript files found", file=stderr)
    if grade_value == "true":
        write_report(results, monotonic() - start)
    return int(failures > 0)


if __name__ == "__main__":
    try:
        exit(main())
    except (OSError, ValueError) as failure:
        print(f"Stepper: {failure}", file=stderr)
        exit(2)

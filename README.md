CodeGrinder problem types
=========================

Container definitions, grading support files, and problem-type configuration for [CodeGrinder](https://github.com/russross/codegrinder).

Problem types
-------------

| Type | Grading strategy |
| --- | --- |
| `cinout` | Compile C with strict diagnostics and sanitizers, then match I/O transcripts exactly. |
| `forthinout` | Run Gforth programs against expected I/O transcripts. |
| `goinout` | Format and build Go programs, then match I/O transcripts exactly. |
| `gounittest` | Run native Go tests and convert their results to xUnit. |
| `javascriptunittest` | Run Jest tests and report their results as xUnit. |
| `nand2tetris` | Run Nand2Tetris hardware or assembly test scripts and compare expected output. |
| `prologinout` | Run SWI-Prolog programs against expected I/O transcripts. |
| `prologunittest` | Run SWI-Prolog unit tests and convert their results to xUnit. |
| `python3inout` | Require strict static typing, then compare program output exactly. |
| `python3unittest` | Run Python `unittest` suites and report their results as xUnit. |
| `riscv` | Run RISC-V assembly with ABI checks and match I/O transcripts exactly. |
| `rustinout` | Build Rust programs and match I/O transcripts exactly. |
| `rustunittest` | Run native Rust tests and convert their results to xUnit. |
| `sqliteinout` | Rebuild the SQLite database, run each query, and match output transcripts. |
| `standardmlinout` | Compile Standard ML programs and match I/O transcripts. |
| `standardmlunittest` | Compile and run a Standard ML test executable. |
| `typescriptunittest` | Lint TypeScript and run Jest tests with xUnit output. |

Repository layout
-----------------

`containers/` holds Dockerfiles, `types/TYPE/files/` holds files installed into problems, and `common/` holds shared grading tools. Each `types/TYPE/type.conf` selects a container, sets CPU, memory, file, descriptor, and thread limits, and declares actions as `name|command|result-format`.

Build and install
-----------------

```sh
# Build every container, or selected containers by name.
bin/build-containers
bin/build-containers python rust

# Install every configured type's actions and support files.
bin/sync-actions
bin/sync-files

# Install one type.
bin/sync-actions python3unittest
bin/sync-files python3unittest
```

Container names come from `containers/`; install names come from `types/`. The sync commands publish through the `grind` CLI.

`types/cunittest/files/` is preserved support material, but it is not a configured problem type because it has no `type.conf`.

---
name: fuzz-testing
description: Coverage-guided fuzz testing for Rust — cargo-fuzz, corpus management, and CI integration
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - WebFetch
---

# Fuzz Testing for Rust Projects

Coverage-guided fuzzing uses libFuzzer to generate random inputs that exercise code paths, catching panics, buffer overflows, and logic bugs that unit tests miss. Rust's `cargo-fuzz` wraps libFuzzer with a Cargo-native workflow.

## Getting Started

Install and initialize:

```bash
cargo install cargo-fuzz --locked
cargo fuzz init                    # creates fuzz/ directory
cargo fuzz add parse_input         # creates a fuzz target
```

Directory structure after init:

```
fuzz/
  Cargo.toml              # workspace member with [[bin]] per target
  corpus/
    parse_input/           # seed corpus for each target
  fuzz_targets/
    parse_input.rs         # fuzz harness source
```

The `fuzz/Cargo.toml` declares each target as a `[[bin]]` entry and depends on your crate via `path = ".."`.

## Writing Effective Fuzz Targets

### Basic `&[u8]` Harness

The simplest form — feed raw bytes to your parser:

```rust
#![no_main]
use libfuzzer_sys::fuzz_target;
use my_crate::parse;

fuzz_target!(|data: &[u8]| {
    let _ = parse(data);
});
```

### Structured Harness with `Arbitrary`

For APIs that take structured types, derive `Arbitrary` to generate valid inputs:

```rust
#![no_main]
use libfuzzer_sys::fuzz_target;
use arbitrary::Arbitrary;

#[derive(Arbitrary, Debug)]
struct FuzzInput {
    header: u8,
    payload: Vec<u8>,
    flag: bool,
}

fuzz_target!(|input: FuzzInput| {
    my_crate::process(input.header, &input.payload, input.flag);
});
```

Add `arbitrary` as a dependency in `fuzz/Cargo.toml`:
```toml
[dependencies]
arbitrary = { version = "1", features = ["derive"] }
```

### Common Target Types

| Target Type | Input Strategy | What It Finds |
|-------------|---------------|---------------|
| Parser | `&[u8]` or `&str` | Panics, infinite loops, stack overflows |
| Serializer | Roundtrip: deserialize then re-serialize | Data corruption, lossy encoding |
| Unsafe code | Structured inputs targeting unsafe blocks | Memory safety violations |
| Format handler | File-like `&[u8]` (image, binary format) | Buffer overflows, OOB reads |
| State machine | Sequence of `Arbitrary` operations | Invalid state transitions, panics |

## Arbitrary vs Manual Fuzzing

| Approach | When to Use |
|----------|------------|
| `&[u8]` raw bytes | Parsers, decoders, anything that accepts bytes directly |
| `Arbitrary` derive | Structured API inputs, multiple parameters, enum variants |
| Manual construction | Complex invariants the fuzzer can't satisfy (e.g., valid checksums, cryptographic structures) |

Use `Arbitrary` when the raw-byte-to-type conversion would waste most fuzzer cycles on invalid inputs. Use manual construction when even `Arbitrary` produces mostly rejected inputs.

## Corpus Management

### Seed Corpus

Place interesting inputs in `fuzz/corpus/<target>/`:

```bash
# Add a seed file
echo -n "valid input example" > fuzz/corpus/parse_input/seed1
# Copy real-world samples
cp test_fixtures/*.bin fuzz/corpus/parse_input/
```

Good seeds: valid inputs, edge cases, minimum-size inputs, inputs from bug reports.

### Minimization

After running, shrink the corpus to remove redundant entries:

```bash
cargo fuzz cmin parse_input        # minimize corpus
```

### .gitignore Guidance

```gitignore
# Ignore crash artifacts (contain failing inputs, regenerate locally)
fuzz/artifacts/

# Selectively keep seed corpus — commit manually curated seeds,
# but consider ignoring auto-generated corpus entries
# fuzz/corpus/
```

Commit curated seeds that represent important edge cases. Auto-generated corpus entries are large and can be regenerated.

## Running and Interpreting Results

### Local Run

```bash
cargo +nightly fuzz run parse_input              # run until stopped (Ctrl+C)
cargo +nightly fuzz run parse_input -- -max_len=4096   # limit input size
cargo +nightly fuzz run parse_input -- -timeout=10     # 10s per input timeout
```

### Time-Limited Runs

```bash
cargo +nightly fuzz run parse_input -- -max_total_time=120   # run for 2 minutes
```

### Parallel Fuzzing

```bash
cargo +nightly fuzz run parse_input -- -fork=4   # 4 parallel workers
```

### Crash Artifacts

When a crash is found, the failing input is saved to `fuzz/artifacts/<target>/`:

```
fuzz/artifacts/parse_input/crash-da39a3ee5e6b4b0d3255...
```

### Reproducing and Minimizing Crashes

```bash
cargo +nightly fuzz run parse_input fuzz/artifacts/parse_input/crash-da39a3...
cargo +nightly fuzz tmin parse_input fuzz/artifacts/parse_input/crash-da39a3...
```

`tmin` produces the smallest input that still triggers the crash — much easier to debug.

### Reading ASan Output

Address Sanitizer output shows the crash type and stack trace:

```
==12345==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x...
    #0 in my_crate::parse::decode at src/parse.rs:42
    #1 in parse_input::main at fuzz/fuzz_targets/parse_input.rs:7
```

Key crash types: `heap-buffer-overflow`, `stack-buffer-overflow`, `use-after-free`, `null-dereference`, `stack-overflow` (infinite recursion).

## CI Integration

Run fuzz targets in CI with time-limited runs on a schedule:

```yaml
on:
  schedule:
    - cron: '0 6 * * 1'      # weekly Monday 6am UTC
  pull_request:
    paths:
      - 'src/**'
      - 'fuzz/**'

jobs:
  fuzz:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        target: [parse_input, decode_format]   # {{FUZZ_TARGETS}} as matrix
    steps:
      - uses: actions/checkout@...
      - uses: dtolnay/rust-toolchain@...
        with:
          toolchain: nightly
      - run: cargo install cargo-fuzz --locked
      - uses: actions/cache@...
        with:
          path: fuzz/corpus/${{ matrix.target }}
          key: fuzz-corpus-${{ matrix.target }}-${{ github.sha }}
          restore-keys: fuzz-corpus-${{ matrix.target }}-
      - run: cargo +nightly fuzz run ${{ matrix.target }} -- -max_total_time=120
      - uses: actions/upload-artifact@...
        if: failure()
        with:
          name: fuzz-artifacts-${{ matrix.target }}
          path: fuzz/artifacts/${{ matrix.target }}/
```

Key CI decisions:
- **Target names must be hardcoded in the workflow file** — never use `workflow_dispatch` inputs or PR labels as target names, as this creates a command injection vector
- **120s per target** — enough to find regressions, not enough to block PRs
- **Nightly toolchain required** — cargo-fuzz depends on `-Z` flags
- **Cache corpus** — corpus grows across runs, improving coverage over time
- **Upload artifacts on failure** — crash inputs are preserved for debugging
- **Matrix per target** — parallelizes across targets, isolates failures

## Coverage Analysis

Generate coverage reports to see which code paths the fuzzer reaches:

```bash
cargo +nightly fuzz coverage parse_input
# Output: fuzz/coverage/parse_input/

# Generate HTML report
cargo install cargo-binutils rustfilt
cargo cov -- show fuzz/coverage/parse_input/coverage.profdata \
  --format=html --instr-profile=... -o coverage-report/
```

Alternatively, use `llvm-cov` directly:

```bash
llvm-profdata merge -sparse fuzz/coverage/parse_input/raw -o fuzz.profdata
llvm-cov report ./target/.../parse_input --instr-profile=fuzz.profdata
```

Low-coverage areas indicate where to add seeds or restructure targets.

## Common Gotchas

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| Missing nightly | `error: cargo-fuzz requires nightly` | `rustup install nightly` or use `cargo +nightly fuzz` |
| No `#![no_main]` | `error: duplicate lang item` | Add `#![no_main]` as the first line of every fuzz target |
| OOM on large inputs | Fuzzer killed, no crash artifact | Add `-- -max_len=4096` (or appropriate limit) |
| Slow targets (>100ms) | Low executions/sec, poor coverage | Simplify target, remove I/O, avoid allocation-heavy paths |
| Corpus too large for git | Repo bloat | `.gitignore` auto-generated corpus, only commit curated seeds |
| cargo-fuzz MSRV conflict | Build failure on install | Use `cargo install cargo-fuzz --locked` |
| Nightly breakage | Build failure after toolchain update | Pin nightly: `cargo +nightly-2025-01-15 fuzz run ...` |

## Template

Reference: `templates/workflows/fuzz.yml` — GitHub Actions workflow for scheduled + PR-triggered fuzz testing with matrix targets and corpus caching.

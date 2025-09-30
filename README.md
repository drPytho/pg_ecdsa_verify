# `pg_ecdsa_verify`: A PostgreSQL Extension for ECDSA Signature Verification

![CI](https://github.com/joelonsql/pg_ecdsa_verify/actions/workflows/test.yml/badge.svg)
[![Crates.io](https://img.shields.io/crates/v/pg_ecdsa_verify.svg)](https://crates.io/crates/pg_ecdsa_verify)

## Overview

`pg_ecdsa_verify` is a PostgreSQL extension for verifying ECDSA signatures,
implemented in Rust. It leverages
the [pgrx](https://github.com/pgcentralfoundation/pgrx) framework for creating
PostgreSQL extensions in Rust. Is uses the
[ecdsa_verify](https://github.com/joelonsql/ecdsa_verify) Rust crate by the
same author for the core ECDSA signature verification logic.

This extension aims to be a compatible drop-in replacement for the C-based
[pg-ecdsa](https://github.com/ameensol/pg-ecdsa), with the same `ecdsa_verify()`
function signature for ease of integration.

## Why Only Verification?

By limiting the scope to verification, the extension remains simpler and easier
to implement and audit. Since verification only involves public keys and no
private keys, it is inherently secure against side-channel attacks and much
easier to implement correctly than the signature generation algorithm.

The typical use case would be a client needing to authenticate against a server
where the public keys are stored in a PostgreSQL server. In this scenario, only
the signature verification algorithm is needed on the server side. This is why
the `pg_ecdsa_verify` crate only exposes the ECDSA signature verification
algorithm.

## Features

- **Compatibility**: Supports multiple PostgreSQL versions (13 to 18).
- **Elliptic Curves**: Supports `secp256r1` and `secp256k1` curves.
- **Hash Functions**: Supports SHA-256 for hashing input data.
- **Performance**: Written in Rust for better safety and performance.
- **Testing**: Comprehensive test suite to ensure reliability.
- **Benchmarking**: Includes benchmarks to measure performance.

## Getting Started

### Prerequisites

- [Rust](https://rustup.rs/)
- [PostgreSQL](https://www.postgresql.org/download/linux/ubuntu/)
- [pgrx](https://github.com/pgcentralfoundation/pgrx)

Skip these steps if you've already installed these, or if you're on a different
platform than Ubuntu/Debian in which case you should visit the links and
follow the instructions for your platform.

1. Install Rust:

    [https://rustup.rs/](https://rustup.rs/)
    ```sh
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source $HOME/.cargo/env
    ```

2. Install latest PostgreSQL:

    [https://www.postgresql.org/download/linux/ubuntu/](https://www.postgresql.org/download/linux/ubuntu/)
    ```sh
    sudo apt install -y postgresql-common
    sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
    sudo apt -y install postgresql
    sudo -u postgres createuser --superuser "$USER"
    createdb "$USER"
    ```

3. Install pgrx:

    [https://github.com/pgcentralfoundation/pgrx/](https://github.com/pgcentralfoundation/pgrx/)
    ```sh
    sudo apt install -y libclang-dev build-essential libreadline-dev \
        zlib1g-dev flex bison libxml2-dev libxslt-dev libssl-dev libxml2-utils \
        xsltproc ccache pkg-config
    cargo install --locked cargo-pgrx
    cargo pgrx init
    ```

### Installation

1. Clone the repository:

    ```sh
    git clone https://github.com/joelonsql/pg_ecdsa_verify.git
    cd pg_ecdsa_verify
    ```

2. Build and test the extension:

    ```sh
    cargo pgrx test
    ```

3. Install the extension to PostgreSQL:

    ```sh
    cargo pgrx install --sudo
    ```

## Usage

### SQL Function

The extension provides a single SQL function `ecdsa_verify` to verify ECDSA signatures.

#### Function Signature

```sql
\dx+ pg_ecdsa_verify
             Objects in extension "pg_ecdsa_verify"
                       Object description
-----------------------------------------------------------------
 function ecdsa_verify.ecdsa_verify(bytea,bytea,bytea,text,text)
 schema ecdsa_verify
(2 rows)
```

#### Example Usage

```sh
psql
```

```sql
CREATE EXTENSION pg_ecdsa_verify;

SELECT ecdsa_verify.ecdsa_verify(
    public_key := '\x7fa92dd0666eee7c13ddb7b6249b0c8f9fba4360857c4e15d2fc634a2b5a1f8fdb9983b319469d35e719a3b93e1ac292854cd3ff2ad50898681b0a32ffbcbc6a'::bytea,
    input_data := '\x49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d9763010000000117bd119a942a38b92bfc3b90a21f7eaa37fe1a7fa0abe27fd15dd20683b14d54'::bytea,
    signature := '\x10fab01307f3eed59bc11601265efaab524b50d017bd9cdfeec4f61b01caa8d669c6e9f8d9bcbdba4e5478cb75b084332d51b0be2c21701b157c7c87abb98057'::bytea,
    hash_func := 'sha256',
    curve_name := 'secp256r1'
);

 ecdsa_verify
--------------
 t
(1 row)
```

### Supported Curves

- `secp256r1`
- `secp256k1`

### Supported Hash Functions

- `sha256`

## Development

### Project Structure

```sh
.
├── Cargo.toml
├── LICENSE
├── benches
│   └── ecdsa_verify.rs
├── pg_ecdsa_verify.control
├── sql
└── src
    └── lib.rs
```

- **Cargo.toml**: Project metadata and dependencies.
- **src/lib.rs**: Main implementation file.
- **benches/ecdsa_verify.rs**: Benchmarking script.
- **pg_ecdsa_verify.control**: PostgreSQL extension control file.

### Running Tests

To run the tests, use the following command:

```sh
cargo pgrx test
```

### Benchmarking

To benchmark the extension, ensure you are using the Rust Nightly toolchain,
then use the following command:

```sh
cargo bench
```

#### Benchmark Results

The benchmarks were run on an Intel Core i9-14900K. The results are as follows:

```
$ cargo bench

     Running benches/ecdsa_verify.rs (target/release/deps/ecdsa_verify-c81f65e672ca3ad2)

test bench_ecdsa_verify ... bench:     840,849 ns/iter (+/- 11,204)
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgements

- The separate `ecdsa_verify` crate is based on v2.2.0 of the [starkbank-ecdsa](https://github.com/starkbank/ecdsa-python/commit/9acdc661b7acde453b9bd6b20c57b88d5a3bf7e3) Python library by Star Bank.
- Built using the [pgrx](https://github.com/pgcentralfoundation/pgrx) framework.

## Contributing

Bugfixes, optimizations and simplifications are welcome, but no more features.
Please open an issue or submit a pull request.

# Sus::Fixtures::Async::HTTP

Provides a convenient fixture for running a web server.

[![Development Status](https://github.com/socketry/sus-fixtures-async-http/workflows/Test/badge.svg)](https://github.com/socketry/sus-fixtures-async-http/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/sus-fixtures-async-http/) for more details.

  - [Getting Started](https://socketry.github.io/sus-fixtures-async-http/guides/getting-started/index) - This guide explains how to use the `sus-fixtures-async-http` gem to test HTTP clients and servers.

## Releases

Please see the [project releases](https://socketry.github.io/sus-fixtures-async-http/releases/index) for all releases.

### v0.12.0

  - Add agent context.

### v0.11.0

  - 100% documentation coverage.
  - Remove unused outer server task.

### v0.10.0

  - Make it easier to override endpoint options like `timeout`.
  - Remove default connection timeout.

### v0.9.1

  - Remove default connection timeout.

### v0.9.0

  - Add optional `after(error)` argument.
  - Add Getting Started guide.

### v0.8.1

  - Add a timeout to prevent hangs during `@client.close`.

### v0.8.0

  - Don't depend on `async-io` directly.

### v0.7.0

  - Pass through the timeout.

### v0.6.0

  - Expose `make_client` similar to `make_server`.

### v0.5.0

  - Fix `make_server` to use endpoint argument.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.

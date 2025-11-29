Contributing to MAMEScripts
==========================

Thank you for your interest in contributing to MAMEScripts! This document explains the preferred workflow for reporting issues, proposing changes, and submitting pull requests.

Reporting issues
- Open an issue on the repository with a clear title and reproduction steps.
- Include MAME version, platform, and any relevant logs or error messages where applicable.

Pull requests
- Fork the repository and create a branch for your change (feature/<name> or fix/<short-desc>). Keep commits focused and atomic.
- Run and verify any scripts you add; include example usage in the README or an `examples/` file.
- Provide tests where reasonable (for complicated helpers or code transformations). This repository primarily contains small Lua scripts for use with MAME; include usage notes if behavior depends on a particular MAME version.

Coding style
- Lua scripts in `scripts/` should be simple and readable. Use descriptive variable names and avoid overly terse idioms.
- Keep files small and focused. If adding new functionality, include documentation in the README or a short example in `examples/`.

Licensing
- This repository is distributed under the MIT license (see `LICENSE`). By contributing code you agree to license your contribution under the repository license.

Communication
- If you're unsure about a larger change, open an issue first to discuss design before writing large patches.

Thanks again — your contributions are appreciated!

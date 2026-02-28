# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0-beta.7] - 2026-02-28

### Bug Fixes

- *(template)* Update deps and extract Homebrew formula from CD workflow (#69) by @claylo in [#69](https://github.com/claylo/claylo-rs/pull/69)




**Full Changelog**: [v1.0.0-beta.6...v1.0.0-beta.7](https://github.com/claylo/claylo-rs/compare/v1.0.0-beta.6...v1.0.0-beta.7)

## [1.0.0-beta.6] - 2026-02-28

### Features

- *(template)* Add scripts/add-crate for post-generation workspace crate scaffolding (#67) by @claylo in [#67](https://github.com/claylo/claylo-rs/pull/67)
- *(wrapper)* Add `about` subcommand with embedded template manifest (#68) by @claylo in [#68](https://github.com/claylo/claylo-rs/pull/68)

### Bug Fixes

- *(template)* Harden npm scripts, fix config boundary, clean up formatting (#63) by @claylo in [#63](https://github.com/claylo/claylo-rs/pull/63)
- *(template)* Pass config sources through instead of re-discovering (#64) by @claylo in [#64](https://github.com/claylo/claylo-rs/pull/64)
- *(template)* Address remaining code review items (#66) by @claylo in [#66](https://github.com/claylo/claylo-rs/pull/66)

### Refactor

- *(template)* Always include .justfile, switch to prettier, add rule files (#65) by @claylo in [#65](https://github.com/claylo/claylo-rs/pull/65)




**Full Changelog**: [v1.0.0-beta.5...v1.0.0-beta.6](https://github.com/claylo/claylo-rs/compare/v1.0.0-beta.5...v1.0.0-beta.6)

## [1.0.0-beta.5] - 2026-02-26

### Bug Fixes

- *(copier)* Account for copier's ridiculous strategy around .rej files (#62) by @claylo in [#62](https://github.com/claylo/claylo-rs/pull/62)




**Full Changelog**: [v1.0.0-beta.4...v1.0.0-beta.5](https://github.com/claylo/claylo-rs/compare/v1.0.0-beta.4...v1.0.0-beta.5)

## [1.0.0-beta.4] - 2026-02-26

### Bug Fixes

- *(wrapper)* Default update conflicts to inline markers instead of .rej files (#61) by @claylo in [#61](https://github.com/claylo/claylo-rs/pull/61)




**Full Changelog**: [v1.0.0-beta.3...v1.0.0-beta.4](https://github.com/claylo/claylo-rs/compare/v1.0.0-beta.3...v1.0.0-beta.4)

## [1.0.0-beta.3] - 2026-02-26

### Bug Fixes

- *(wrapper)* Merge-based precedence so data-file preferences are respected (#59) by @claylo in [#59](https://github.com/claylo/claylo-rs/pull/59)

### Documentation

- Fix inaccuracies in reference, presets, development, and README (#60) by @claylo in [#60](https://github.com/claylo/claylo-rs/pull/60)




**Full Changelog**: [v1.0.0-beta.2...v1.0.0-beta.3](https://github.com/claylo/claylo-rs/compare/v1.0.0-beta.2...v1.0.0-beta.3)

## [1.0.0-beta.2] - 2026-02-24

### Features

- *(template)* Add site package manager choice, fix answers file and wrapper bugs (#57) by @claylo in [#57](https://github.com/claylo/claylo-rs/pull/57)
- *(template)* Move docs into Starlight, ncu-based deps, bump actions (#58) by @claylo in [#58](https://github.com/claylo/claylo-rs/pull/58)




**Full Changelog**: [v1.0.0-beta.1...v1.0.0-beta.2](https://github.com/claylo/claylo-rs/compare/v1.0.0-beta.1...v1.0.0-beta.2)

## [1.0.0-beta.1] - 2026-02-17

### Features

- *(template)* Replace site placeholder with Astro Starlight docs site (#55) by @claylo in [#55](https://github.com/claylo/claylo-rs/pull/55)
- *(template)* Add rename tool, vendor site plugins, and polish for beta (#56) by @claylo in [#56](https://github.com/claylo/claylo-rs/pull/56)




**Full Changelog**: [v1.0.0-alpha.4...v1.0.0-beta.1](https://github.com/claylo/claylo-rs/compare/v1.0.0-alpha.4...v1.0.0-beta.1)

## [1.0.0-alpha.4] - 2026-02-07

### Features

- *(template)* Set workspace resolver based on edition (#54) by @claylo in [#54](https://github.com/claylo/claylo-rs/pull/54)




**Full Changelog**: [v1.0.0-alpha.3...v1.0.0-alpha.4](https://github.com/claylo/claylo-rs/compare/v1.0.0-alpha.3...v1.0.0-alpha.4)

## [1.0.0-alpha.3] - 2026-02-06

### Bug Fixes

- *(template)* Project-specific env vars, CLI config flag, and dep updates (#53) by @claylo in [#53](https://github.com/claylo/claylo-rs/pull/53)

### Documentation

- Add inquire, indicatif, and doctor command to reference (#52) by @claylo in [#52](https://github.com/claylo/claylo-rs/pull/52)




**Full Changelog**: [v1.0.0-alpha.2...v1.0.0-alpha.3](https://github.com/claylo/claylo-rs/compare/v1.0.0-alpha.2...v1.0.0-alpha.3)

## [1.0.0-alpha.2] - 2026-02-05

### Features

- *(template)* Add XDG support, doctor command, and CLI sugar (#51) by @claylo in [#51](https://github.com/claylo/claylo-rs/pull/51)




**Full Changelog**: [v1.0.0-alpha.1...v1.0.0-alpha.2](https://github.com/claylo/claylo-rs/compare/v1.0.0-alpha.1...v1.0.0-alpha.2)

## [1.0.0-alpha.1] - 2026-02-04

### Features

- Initial template infrastructure (#1) by @claylo in [#1](https://github.com/claylo/claylo-rs/pull/1)
- Add local crates.io registry for publish testing (#4) by @claylo in [#4](https://github.com/claylo/claylo-rs/pull/4)
- *(template)* Add post-copy messages and configurable clippy lint tiers (#6) by @claylo in [#6](https://github.com/claylo/claylo-rs/pull/6)
- Add bin/claylo-rs wrapper for copier CLI (#7) by @claylo in [#7](https://github.com/claylo/claylo-rs/pull/7)
- *(template)* Add git-cliff release automation system (#43) by @claylo in [#43](https://github.com/claylo/claylo-rs/pull/43)
- *(template)* Add npm scaffold for binary distribution (#46) by @claylo in [#46](https://github.com/claylo/claylo-rs/pull/46)
- *(template)* Add artifact attestations for supply chain security (#47) by @claylo in [#47](https://github.com/claylo/claylo-rs/pull/47)
- *(template)* Add MCP server tests and fix export exclusions (#48) by @claylo in [#48](https://github.com/claylo/claylo-rs/pull/48)
- *(template)* Optimize compile times and test infrastructure (#49) by @claylo in [#49](https://github.com/claylo/claylo-rs/pull/49)

### Bug Fixes

- *(template)* Resolve OTel HTTP exporter and Copier 9.x compatibility issues (#13) by @claylo in [#13](https://github.com/claylo/claylo-rs/pull/13)
- *(template)* Address code review findings and wire up CLI flags (#17) by @claylo in [#17](https://github.com/claylo/claylo-rs/pull/17)
- *(test)* Correct preset filename and test assertions (#18) by @claylo in [#18](https://github.com/claylo/claylo-rs/pull/18)
- *(template)* Resolve feature dependency issues in progressive enhancement (#50) by @claylo in [#50](https://github.com/claylo/claylo-rs/pull/50)

### Documentation

- Update ADRs and clean up stale scripts (#44) by @claylo in [#44](https://github.com/claylo/claylo-rs/pull/44)

### Performance

- Remove crates-io submodule to fix slow copier invocations (#15) by @claylo in [#15](https://github.com/claylo/claylo-rs/pull/15)

### Refactor

- *(test)* Add bats-core testing framework (#2) by @claylo in [#2](https://github.com/claylo/claylo-rs/pull/2)
- Remove release automation and cocogitto, quiet test output by @claylo
- *(config)* Replace config crate with figment for better layering ergonomics (#5) by @claylo in [#5](https://github.com/claylo/claylo-rs/pull/5)
- *(wrapper)* Switch toggle aliases from dashes to underscores (#12) by @claylo in [#12](https://github.com/claylo/claylo-rs/pull/12)
- *(template)* Modernize conditional patterns and documentation (#14) by @claylo in [#14](https://github.com/claylo/claylo-rs/pull/14)
- *(ci)* Modernize GitHub Actions and improve release documentation (#45) by @claylo in [#45](https://github.com/claylo/claylo-rs/pull/45)

### Testing

- *(otel)* Add OTEL integration tests with Docker (#3) by @claylo in [#3](https://github.com/claylo/claylo-rs/pull/3)

### Miscellaneous Tasks

- Initial commit by @claylo
- Mcp-server plan notes (#8) by @claylo in [#8](https://github.com/claylo/claylo-rs/pull/8)
- Post-merge housekeeping for MCP server feature (#9) by @claylo in [#9](https://github.com/claylo/claylo-rs/pull/9)
- Update agent instructions (#10) by @claylo in [#10](https://github.com/claylo/claylo-rs/pull/10)
- Fix rust-toolchain (#11) by @claylo in [#11](https://github.com/claylo/claylo-rs/pull/11)
- Clean up diagrams (#16) by @claylo in [#16](https://github.com/claylo/claylo-rs/pull/16)

### New Contributors
* @claylo made their first contribution in [#50](https://github.com/claylo/claylo-rs/pull/50)





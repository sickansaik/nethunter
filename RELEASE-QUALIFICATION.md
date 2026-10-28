# NetHunter Toolkit v0.5.0

## Release Identity

- Version: 0.5.0
- Codename: Evolution
- Status: Stable
- Parent Release: v0.4.4 Runtime — Stable
- Parent Golden Baseline: `NetHunter-Toolkit/backups/v0.4.4-runtime/final-release-20260827-032440`
- Final Release Qualification: QUALIFIED
- Stable Release Freeze: QUALIFIED

## Qualified Scope

### Feature Framework

- Feature loader: PASS
- Feature registry: PASS
- NHT feature dispatch: PASS
- Runtime feature surface: PASS
- Network feature surface: PASS
- System feature surface: PRESENT
- Security feature surface: PRESENT

### Network Diagnostics

- Intelligence mode: PASS
- Scan mode: PASS
- Quick profile: PASS
- Standard profile: PASS
- Diagnostic profile: PASS
- Tool discovery: PASS
- Human-readable report: PASS

### Network Data Model

- Schema: `nht.network.v1`
- JSON generation: PASS
- JSON validation: PASS
- IPv4 connectivity model: PASS
- IPv6 detection model: PASS
- Tool inventory model: PASS

### Snapshot Persistence

- Snapshot creation: PASS
- Snapshot JSON validation: PASS
- Snapshot history listing: PASS
- `latest.json` consistency: PASS
- CLI latest consistency: PASS
- Same-second collision protection: PASS
- Invalid JSON rejection: PASS
- Temporary-file hygiene: PASS

### Persistence Semantics

- Toolkit backup preserves `runtime/network/**`: PASS
- Toolkit restore preserves `runtime/network/**`: PASS
- Toolkit update preserves `runtime/network/**`: PASS
- Update rollback preserves persistent state: PASS
- Generated network state remains project-anchored: PASS

## Release / Runtime Ownership

Release-owned source:

- `runtime/ubuntu-gui.sh`
- `lib/network/snapshot.sh`
- Toolkit source, configuration, modules and release documentation

Installation-owned persistent state:

- `runtime/network/latest.json`
- `runtime/network/snapshots/**`

Installation-owned state must not be included in the release package or release manifest.

## Release Boundary Qualification

- Candidate release inventory: 45 files
- `runtime/network/**` excluded: PASS
- `backups/**` excluded: PASS
- `logs/**` excluded: PASS
- `updates/**` excluded: PASS
- Development patch artifacts excluded: PASS
- Required v0.5.0 source files present: PASS
- `runtime/ubuntu-gui.sh` present: PASS
- Snapshot engine source present: PASS

## Runtime Regression

- Termux:X11 runtime: GREEN
- XFCE runtime: GREEN
- Toolkit control runtime: GREEN
- Doctor: GREEN
- Legacy network actions: GREEN

## Parent Golden Baseline

Parent release:

**NetHunter Toolkit v0.4.4 — Runtime — Stable**

Verified Golden Baseline:

`NetHunter-Toolkit/backups/v0.4.4-runtime/final-release-20260827-032440`

The parent release manifest verifies successfully.

The parent Golden Baseline is frozen and must not be modified by v0.5.0 development.

## Manifest Policy

The current project `release.manifest` still represents the previous frozen release.

It is not the final v0.5.0 manifest.

The v0.5.0 manifest must only be generated from the final clean staged release tree.

It must:

- include all release-owned files,
- exclude `runtime/network/**`,
- exclude `backups/**`,
- exclude `logs/**`,
- exclude `updates/**`,
- exclude development-only backup artifacts,
- include `runtime/ubuntu-gui.sh`,
- include `lib/network/snapshot.sh`,
- reject unexpected unmanifested release files.

## Current Qualification Status

**STEP 4F — NETWORK DATA PERSISTENCE: PASS**

**STEP 4G — RELEASE ENGINEERING: PASS**

**FINAL RELEASE QUALIFICATION: PASS**

**STABLE RELEASE FREEZE: PASS**

NetHunter Toolkit v0.5.0 is **Stable** following final release qualification.

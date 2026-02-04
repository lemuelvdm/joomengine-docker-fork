# Joomla Component Builder – Official Docker Images

[![JoomEngine – Automated Build & Version Tracking](https://github.com/octoleo/joomengine/actions/workflows/joomengine.yml/badge.svg?branch=master)](https://github.com/octoleo/joomengine/actions/workflows/joomengine.yml)

This repository contains the **official Docker image build system** for
**Joomla Component Builder (JCB)**.

It is the canonical source for generating, tagging, and publishing all
Joomla Component Builder Docker images across supported:

- Joomla versions
- PHP versions
- Runtime variants (Apache / FPM)
- Stable and prerelease channels

All images are **generated, versioned, and published automatically** from
authoritative upstream release data.

---

## 🧠 What This Repository Is (and Is Not)

### ✅ What it *is*

- The **official Docker image source** for Joomla Component Builder
- A **fully automated build engine** driven by upstream JCB releases
- A **deterministic and auditable system** that:
  - Tracks release hashes describing what was built
  - Generates Dockerfiles automatically
  - Emits a complete build manifest
  - Builds, tags, and publishes images consistently

### ❌ What it is *not*

- A manually curated set of Dockerfiles
- A place to hand-edit image definitions
- A CI script that hides build logic in YAML

> **All build logic lives in `joomengine.sh`.**
> CI only authenticates, runs it, and commits the results.

---

## 📦 Published Images

All images are published to Docker Hub under:

[https://hub.docker.com/r/octoleo/joomengine](https://hub.docker.com/r/octoleo/joomengine)

You can pull images directly, for example:

```bash
docker pull octoleo/joomengine:latest
docker pull octoleo/joomengine:6.5.7
docker pull octoleo/joomengine:6.5.7-php8.2-apache
````

[Docker details ->](https://github.com/octoleo/joomengine/blob/master/DOCKER.md)

---

## 🏗️ How Images Are Built

Image generation is driven entirely by the script:

```
./joomengine.sh
```

At a high level, the build engine performs the following steps:

1. **Discovers upstream JCB releases**

   * Fetches official update XML files per major version
   * Extracts version numbers, download URLs, and SHA512 hashes
   * Refuses to build if hashes are missing

2. **Expands build matrices**

   * Joomla major versions
   * Supported PHP versions (per Joomla)
   * Runtime variants (`apache`, `fpm`)

3. **Generates build contexts**

   * Creates versioned directory trees under `build/`
   * Generates Dockerfiles from templates
   * Injects release metadata as build arguments
   * Copies and configures the Docker entrypoint

4. **Tracks build state**

   * Records processed builds in `hashes.txt`
   * Prevents rebuilding identical release+PHP+variant combinations

5. **Calculates tag leadership**

   * Determines highest stable versions per major
   * Determines global highest stable version
   * Handles prerelease channels (`alpha`, `beta`, `rc`) correctly
   * Ensures **no tag collisions**

6. **Emits a build manifest**

   * Outputs a machine-readable NDJSON manifest (`manifest.ndjson`)
   * Each line describes exactly one buildable image and its tags

7. **Builds and publishes images**

   * Builds base images only if they do not already exist
   * Applies all calculated tags
   * Pushes images to the registry (unless disabled)

---

## 🏷️ Tagging Strategy (Important)

This repository follows a **strict, predictable tagging policy**.

### Base tags (always present)

```
<version>-php<php>-<variant>
```

Example:

```
6.5.7-php8.2-apache
```

---

### Apache shorthand tags

If the variant is `apache`, a shorthand tag is added:

```
<version>-php<php>
```

---

### Highest PHP shorthand

If the PHP version is the **highest supported PHP** for that Joomla major:

```
<version>-<variant>
<version>
```

(when `apache`)

---

### Stable rolling tags (per major)

If a version is the **highest stable release** of its major:

```
<minor>-php<php>-<variant>
<major>-php<php>-<variant>
<minor>-<variant>
<major>-<variant>
<minor>
<major>
```

(variant-dependent)

---

### Global `latest`

Only one image ever receives:

```
latest
```

Criteria:

* Stable release
* Highest version globally
* Apache variant
* Highest supported PHP

---

### Prerelease channels (`alpha`, `beta`, `rc`)

Prereleases are tagged **without polluting stable tags**.

Examples:

```
6.6-rc
6.6-rc1
6.6-rc1-php8.3-apache
```

Rules:

* Numbered prereleases roll forward correctly
* Unnumbered prereleases are treated as “highest in channel”
* Stable tags are never reused for prereleases

---

## 📁 Repository Structure

```
.
├── joomengine.sh          # The build engine (authoritative logic)
├── versions.json          # Supported Joomla / PHP / variant matrix
├── maintainers.json       # Image maintainer metadata
├── Dockerfile.template    # Template used to generate Dockerfiles
├── docker-entrypoint.sh   # Runtime entrypoint copied into images
├── hashes.txt             # Tracks built release combinations
├── manifest.ndjson        # Generated build manifest (NDJSON)
├── build/                 # Generated build contexts
└── .github/workflows/     # Automation (thin by design)
```

> **Do not edit generated files manually.**
> They are overwritten by `joomengine.sh`.

---

## 🤖 Automation & CI

This repository uses GitHub Actions to run the build engine automatically.

### Triggers

* Once per day (scheduled)
* On merge to `master`
* Manual dispatch

### What CI does

1. Checks out the repository
2. Installs required tooling
3. Authenticates with Docker
4. Runs `./joomengine.sh`
5. Commits **any generated changes** back to the repository

### What CI does *not* do

* It does **not** contain build logic
* It does **not** define tagging rules
* It does **not** hide behavior in YAML

All logic remains reviewable and reproducible locally.

---

## 🧪 Running Locally

You can run the build engine locally:

```bash
./joomengine.sh
```

Useful flags:

```bash
--dry-run      # No build, no push
--build-only   # Build locally, do not push
--quiet        # Suppress stdout
```

This makes local testing identical to CI behavior.

---

## 🧾 License

```txt
Copyright (C) 2021–2026
Llewellyn van der Merwe

Licensed under the **GNU General Public License v2 (GPLv2)**
See `LICENSE` for details.
```

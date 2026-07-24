# AI Agent Instructions & User Preferences

This document outlines the operational preferences and workflow rules specified by the repository maintainer. All AI agents working on this codebase must adhere strictly to these rules.

## Core Rules & Workflow Preferences

### 1. Analyze First, Confirm Before Editing
* **Do NOT make code changes or commits immediately upon error detection.**
* When given an issue, bug log, or request, always:
  1. Inspect the codebase, logs, and technical context thoroughly.
  2. Identify the root cause(s) and formulate a clear diagnosis.
  3. Present the findings, technical rationale, and proposed resolution to the user.
  4. **Wait for the user's explicit command/confirmation** before modifying files, creating commits, or running destructive commands.

### 2. Multi-JDK & Multi-OS Compatibility
* This repository builds multi-vendor Java Docker images (`aio-7` through `aio-26`) based on Debian.
* Always consider vendor-specific differences (e.g., Amazon Corretto, Temurin, Zulu, Liberica, GraalVM) regarding default file locations, security providers, and system CA truststores (`cacerts`).
* Maintain path compatibility for both Debian (`/etc/ssl/certs/`) and RHEL/Amazon Linux (`/etc/pki/`) conventions.

### 3. File & Permission Safety
* Ensure all files copied or created within Docker images are readable by the non-root `container` user (`chmod 644` for files, `chmod 755` for directories).
* Keep build scripts (`scripts/entrypoint.sh`) robust against non-root runtime environments.

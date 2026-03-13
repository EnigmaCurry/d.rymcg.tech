# uv dependency cache seed for container builds.
#
# Problem: uv inline scripts in _scripts/ and _container/ declare their own
# dependencies, but they live inside the source tree. The Dockerfile COPYs the
# source tree late (so that earlier layers stay cached), which means `uv run`
# has to re-download every dependency on every build — even when only source
# code changed, not dependencies.
#
# Solution: this file aggregates every dependency used by any inline script
# into a single manifest. The Dockerfile COPYs and runs it *before* the source
# COPY, so uv's cache layer survives source-code changes. The later per-script
# `uv run` calls find everything already cached and become no-ops.
#
# Maintenance: when you add or update a dependency in any inline script under
# _scripts/ or _container/, add it here too. The list doesn't need to be exact
# — extra entries just pre-cache unused packages, and missing entries just fall
# back to a download at the later build step.
#
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "fastapi>=0.115",
#   "jinja2",
#   "markdown>=3.5",
#   "nats-py>=2.9",
#   "openai>=1.0",
#   "pydantic>=2.0",
#   "pyjwt>=2.0",
#   "pyyaml",
#   "rich",
#   "uvicorn>=0.34",
# ]
# ///

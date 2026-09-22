FROM mcr.microsoft.com/devcontainers/jekyll:2-bullseye

# pandoc — Phase 4 (setup/scripts/03_provision_sharepoint.ps1) builds the planted .docx from Markdown.
RUN apt-get update \
    && apt-get install -y --no-install-recommends pandoc \
    && rm -rf /var/lib/apt/lists/*

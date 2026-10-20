FROM mcr.microsoft.com/devcontainers/jekyll:3.3-bookworm

# pandoc — Phase 4 (setup/scripts/03_provision_sharepoint.ps1) builds the planted .docx from Markdown.
# python3-pip — on-create.sh installs Playwright with pip; the bookworm image ships Python without it.
RUN apt-get update \
    && apt-get install -y --no-install-recommends pandoc python3-pip \
    && rm -rf /var/lib/apt/lists/*

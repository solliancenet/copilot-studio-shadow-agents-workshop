#!/usr/bin/env python3
"""
FACILITATOR-ONLY. Render a local HTML file to PDF with headless Chromium, honouring the page's own
@page size and margins. 07d uses it for the attendee handouts.

  python3 setup/scripts/lib/print_pdf.py --html in.html --pdf out.pdf

Requires: playwright. Uses Chrome when installed, else Playwright's Chromium (the dev container's).
"""
import argparse, sys
from pathlib import Path
from playwright.sync_api import sync_playwright


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--html", required=True)
    ap.add_argument("--pdf", required=True)
    a = ap.parse_args()
    src = Path(a.html).resolve()
    with sync_playwright() as p:
        try: browser = p.chromium.launch(channel="chrome", headless=True)
        except Exception: browser = p.chromium.launch(headless=True)
        try:
            page = browser.new_page()
            page.goto(src.as_uri(), wait_until="load")
            page.pdf(path=a.pdf, prefer_css_page_size=True, print_background=True)
        finally:
            browser.close()
    print(f"PDF={a.pdf}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

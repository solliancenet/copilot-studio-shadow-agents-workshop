#!/usr/bin/env python3
"""
FACILITATOR-ONLY. The one piece of Phase 6 that needs a browser: authenticate a Power Platform connection
as its owner. PnP/pac and az cover everything else, but a connector's OAuth consent has no headless API -
so this drives a headless browser through the persona sign-in and the consent page and returns the short
connection code that the caller (06_provision_agents.ps1) posts to confirmConsentCode.

  python3 consent_browser.py --upn <persona-upn> --password <pw> --consent-url "<getConsentLink result>"

Prints one line to stdout: CODE=<code>   (or ERROR=<message> and exits 1). Lab-only: the password is the
shared lab password, passed by the engine; never use against a real tenant.

Requires: playwright (pip install playwright) and its Chromium (python3 -m playwright install chromium);
uses Google Chrome instead where it is installed.
"""
import argparse, re, sys, time, urllib.parse
from playwright.sync_api import sync_playwright

def get_code(upn: str, password: str, consent_url: str, timeout_s: int = 120) -> str:
    with sync_playwright() as p:
        # Google Chrome where it is installed; otherwise Playwright's bundled Chromium (the dev container,
        # and arm64 Linux, where Chrome doesn't exist). The flow only fills fields and clicks buttons.
        try:
            browser = p.chromium.launch(channel="chrome", headless=True)
        except Exception:
            browser = p.chromium.launch(headless=True)
        page = browser.new_context(locale="en-US").new_page()
        code = {}

        def on_request(r):
            # Entra's own auth code (1.A...) passes through the consent service first; the connection code
            # is short and alphanumeric. Capture only that one.
            if "consent.azure-apim.net" in r.url and "code=" in r.url:
                v = urllib.parse.parse_qs(urllib.parse.urlparse(r.url).query).get("code", [""])[0]
                if re.fullmatch(r"[A-Za-z0-9\-\.]{3,64}", v):
                    code["v"] = v

        page.on("request", on_request)
        page.goto(consent_url)
        deadline = time.time() + timeout_s
        try:
            while time.time() < deadline:
                if "v" in code:
                    break
                page.wait_for_timeout(1500)
                if page.locator("input[type=email]:visible").count():
                    page.fill("input[type=email]", upn); page.click("input[type=submit]"); continue
                if page.locator("input[type=password]:visible").count():
                    page.fill("input[type=password]", password); page.click("input[type=submit]"); continue
                if page.locator("#idBtn_Back:visible").count():          # "Stay signed in?" -> No
                    page.click("#idBtn_Back"); continue
                txt = page.locator("body").inner_text()[:3000]
                if re.search(r"Confirmation required", txt):             # owner confirms a connection they made
                    try: page.locator("input[type=checkbox]").first.check()
                    except Exception: pass
                    page.get_by_text("Allow access", exact=True).click(); continue
                if re.search(r"Pick an account", txt):
                    page.get_by_text(upn).first.click(); continue
            if "v" not in code:
                raise RuntimeError("no connection code; last page text: " + page.locator("body").inner_text()[:400])
        finally:
            browser.close()
        return code["v"]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--upn", required=True)
    ap.add_argument("--password", required=True)
    ap.add_argument("--consent-url", required=True)
    ap.add_argument("--timeout", type=int, default=120)
    a = ap.parse_args()
    try:
        print("CODE=" + get_code(a.upn, a.password, a.consent_url, a.timeout))
    except Exception as e:
        print("ERROR=" + str(e).replace("\n", " ")[:500]); sys.exit(1)

if __name__ == "__main__":
    main()

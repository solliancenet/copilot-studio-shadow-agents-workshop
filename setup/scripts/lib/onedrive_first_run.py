#!/usr/bin/env python3
"""
FACILITATOR-ONLY. Open a persona's OneDrive in a headless browser, the way the persona would the first time,
so SharePoint provisions their personal site. 03b calls it when the Graph touch hasn't produced the site.

  python3 setup/scripts/lib/onedrive_first_run.py --upn dev.kim.<estate>@<domain> --password <pw> \
      --host https://<tenant>-my.sharepoint.com --out /tmp/od

Prints FINAL_URL=... and RESULT=PASS when OneDrive's first-run page says it is ready, or OneDrive's home
page shows its My files, Recycle bin and Storage nav (an existing OneDrive), else RESULT=FAIL <reason>; exits 0/1.
Screenshots go to --out.

Why a browser: on 2026-10-23 the Graph touch (GET /me/drive) left stu05's site unprovisioned for 45 minutes
twice, and Request-PnPPersonalSite as a Global Admin, signed in by device code, was "unauthorized" twice. One
browser visit as the persona reached "Your OneDrive is ready" (MyBraryFirstRun.aspx) in about a minute.

Sign in as an ordinary licensed persona: an admin role brings MFA (CA-Require-MFA-Admins), and SharePoint
won't create a OneDrive for an unlicensed user. Lab-only password.

Requires: playwright. Uses Chrome when installed, else Playwright's Chromium (the dev container's).
"""
import argparse, sys, time
from pathlib import Path
from playwright.sync_api import sync_playwright

UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/141.0.0.0 Safari/537.36")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--upn", required=True)
    ap.add_argument("--password", required=True)
    ap.add_argument("--host", required=True, help="https://<tenant>-my.sharepoint.com")
    ap.add_argument("--out", required=True, help="folder for screenshots")
    ap.add_argument("--timeout", type=int, default=300, help="seconds to reach the ready page")
    a = ap.parse_args()
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        try:
            try: browser = p.chromium.launch(channel="chrome", headless=True)
            except Exception: browser = p.chromium.launch(headless=True)
        except Exception as e:
            print("RESULT=FAIL no browser: " + str(e).replace("\n", " ")[:300]); return 1
        page = browser.new_context(locale="en-US", user_agent=UA, viewport={"width": 1400, "height": 900}).new_page()
        try:
            page.goto(a.host.rstrip("/") + "/", wait_until="domcontentloaded")
            end, ready, body = time.time() + a.timeout, False, ""
            while time.time() < end and not ready:
                page.wait_for_timeout(3000)
                try:
                    if page.locator("input[type=email]:visible").count():
                        page.fill("input[type=email]", a.upn); page.click("input[type=submit]"); continue
                    if page.locator("input[type=password]:visible").count():
                        page.fill("input[type=password]", a.password); page.click("input[type=submit]"); continue
                    if page.locator("#idBtn_Back:visible").count():          # "Stay signed in?" -> No
                        page.click("#idBtn_Back"); continue
                    body = page.locator("body").inner_text()
                except Exception:
                    continue                                                    # the page navigated mid-step
                # First visit: the first-run page says it's ready. Later visits: OneDrive's home page, at the
                # host root, whose nav has My files, Recycle bin and Storage (its figure loads later).
                # Not the URL alone: an error or still-loading page can sit under /personal/ too.
                ready = ("Your OneDrive is ready" in body
                         or all(t in body for t in ("My files", "Recycle bin", "Storage")))
            page.screenshot(path=str(out / "onedrive-first-run.png"))
            print("FINAL_URL=" + page.url[:200])
            if not ready:
                print("RESULT=FAIL OneDrive never said it was ready; page: " + " | ".join(body.split("\n"))[:300]); return 1
            print("RESULT=PASS"); return 0
        except Exception as e:
            print("RESULT=FAIL " + str(e).replace("\n", " ")[:300]); return 1
        finally:
            browser.close()


if __name__ == "__main__":
    sys.exit(main())

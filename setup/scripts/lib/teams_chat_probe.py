#!/usr/bin/env python3
"""
FACILITATOR-ONLY. Chat with a published agent in Teams, as a persona, the way an attendee does in
Exercise 04: open the agent's install link, Add, then hold a short scripted conversation. Use it to check an
agent answers before a delivery or a recording, or to test a change to an agent's owner (issue #30).

  python3 setup/scripts/lib/teams_chat_probe.py --upn lena.ford.<estate>@<domain> --password <pw> \
      --agent "Policy Lookup Bot" --links setup/teams-links-<estate>.local.csv --out /tmp/probe \
      --say "look up a policy" --expect "policy id" --say "POL-1001" --expect "Policy POL-1001"

--links is Phase 6's handout (setup/teams-links-<estate>.local.csv); --link <url> instead takes one link.
Each --say is sent in turn and its --expect (a case-insensitive substring) must appear afterwards. Prints
TRANSCRIPT_TAIL=... then RESULT=PASS, or RESULT=FAIL <reason>, and exits 0/1. Screenshots go to --out.

Sign in as a licensed persona without an admin role: Teams refuses an unlicensed account, and an admin role
brings MFA (CA-Require-MFA-Admins). The persona must be in the agent's chat audience. Lab-only password.

Teams traps this handles, all seen 2026-10-22: the install link loses its app on the redirect to
teams.cloud.microsoft (re-open it once Teams has loaded); the dialog's Add button sits under an overlay
(force the click); after "Added successfully!" the chat opens only from Open; an agent added earlier is
opened from the chat list. Headless Chrome needs a normal user agent.

Requires: playwright (pip install playwright) with Chrome available (channel=chrome).
"""
import argparse, csv, re, sys, time
from pathlib import Path
from playwright.sync_api import sync_playwright

UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/141.0.0.0 Safari/537.36")


def link_for(links_csv: str, agent: str) -> str:
    with open(links_csv, newline="") as f:
        for row in csv.DictReader(f):
            if row.get("agent") == agent and row.get("teams_link"):
                return row["teams_link"]
    raise SystemExit(f"RESULT=FAIL no Teams link for '{agent}' in {links_csv} (re-run Phase 6)")


def open_chat(page, a, shot) -> object:
    """Sign in, install or open the agent, and return its chat's compose box (or None)."""
    deadline = time.time() + a.timeout
    relinked, last_relink = 0, time.time()
    while time.time() < deadline:
        page.wait_for_timeout(2500)
        if page.locator("input[type=email]:visible").count():
            page.fill("input[type=email]", a.upn); page.click("input[type=submit]"); continue
        if page.locator("input[type=password]:visible").count():
            page.fill("input[type=password]", a.password); page.click("input[type=submit]"); continue
        if page.locator("#idBtn_Back:visible").count():                      # "Stay signed in?" -> No
            page.click("#idBtn_Back"); continue
        for label in ("Use the web app instead", "Continue on this browser"):
            l = page.get_by_text(label, exact=False)
            if l.count() and l.first.is_visible():
                l.first.click(); break
        add = page.locator("[role=dialog] [data-tid='install-app-btn']:visible")
        if not add.count():
            add = page.locator(f"[role=dialog] [data-tid^='install-app-btn']:visible, "
                               f"[role=dialog] button[aria-label='Add {a.agent}']:visible")
        if add.count():
            shot(page, "dialog-add")
            try: add.first.click(timeout=8000)
            except Exception: add.first.click(force=True, timeout=8000)
            page.wait_for_timeout(10000); continue
        opn = page.locator("[role=dialog] button:visible", has_text=re.compile(r"^\s*Open\s*$"))
        if opn.count():
            shot(page, "dialog-open"); opn.first.click(timeout=8000); page.wait_for_timeout(6000); continue
        dialog_up = page.locator("[role=dialog]:visible").count() > 0
        if not dialog_up:                                                     # added earlier: open it from the list
            item = page.locator("[role=treeitem]:visible", has_text=a.agent)
            title = page.locator("h2:visible, [data-tid='chat-title']:visible").all_inner_texts() or [""]
            if item.count() and a.agent not in title[0]:
                item.first.click(timeout=8000); page.wait_for_timeout(5000)
        body = page.locator("body").inner_text()[:3000] if page.locator("body").count() else ""
        box = page.locator("[data-tid='ckeditor'], div[role=textbox][contenteditable=true]")
        if box.count() and box.first.is_visible() and a.agent in body and not dialog_up:
            return box.first
        if re.search(r"don't have the required permissions|do not have permission|isn't available", body, re.I):
            shot(page, "refused"); raise RuntimeError("Teams refused: " + body.replace("\n", " ")[:300])
        if (not dialog_up and "teams" in page.url and "titleId" not in page.url and relinked < 3
                and page.get_by_text("Chat").count() and time.time() - last_relink > 45):
            relinked += 1; last_relink = time.time(); shot(page, f"relink-{relinked}")
            page.goto(a.link, wait_until="domcontentloaded")
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--upn", required=True)
    ap.add_argument("--password", required=True)
    ap.add_argument("--agent", required=True, help="the agent's display name, as Teams shows it")
    ap.add_argument("--link", help="the agent's Teams install link")
    ap.add_argument("--links", help="Phase 6's setup/teams-links-<estate>.local.csv, to look the link up")
    ap.add_argument("--out", required=True, help="folder for screenshots")
    ap.add_argument("--say", action="append", default=[])
    ap.add_argument("--expect", action="append", default=[])
    ap.add_argument("--timeout", type=int, default=300, help="seconds to reach the chat")
    a = ap.parse_args()
    if not a.link:
        if not a.links: raise SystemExit("RESULT=FAIL pass --link or --links")
        a.link = link_for(a.links, a.agent)
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    n = [0]

    def shot(page, tag):
        n[0] += 1
        try: page.screenshot(path=str(out / f"{n[0]:02d}-{tag}.png"))
        except Exception: pass

    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome", headless=True)
        page = browser.new_context(locale="en-US", user_agent=UA, viewport={"width": 1400, "height": 900}).new_page()
        try:
            page.goto(a.link, wait_until="domcontentloaded")
            box = open_chat(page, a, shot)
            if not box:
                shot(page, "no-chat"); print("RESULT=FAIL never reached the agent's chat; url=" + page.url[:200]); return 1
            shot(page, "chat-open")
            for i, say in enumerate(a.say):
                expect = a.expect[i] if i < len(a.expect) else None
                seen = page.locator("body").inner_text().lower().count(expect.lower()) if expect else 0
                # The app's dialog can land on top of an already-open chat; Open (or Escape) clears it.
                for _ in range(3):
                    if not page.locator("[role=dialog]:visible").count(): break
                    opn = page.locator("[role=dialog] button:visible", has_text=re.compile(r"^\s*Open\s*$"))
                    if opn.count(): opn.first.click(timeout=8000)
                    else: page.keyboard.press("Escape")
                    page.wait_for_timeout(4000)
                box = page.locator("[data-tid='ckeditor'], div[role=textbox][contenteditable=true]").first
                box.click(); box.type(say, delay=20); page.keyboard.press("Enter")
                if not expect:
                    page.wait_for_timeout(5000); continue
                end = time.time() + 120
                while time.time() < end:
                    page.wait_for_timeout(3000)
                    if page.locator("body").inner_text().lower().count(expect.lower()) > seen:
                        break
                else:
                    shot(page, f"no-reply-{i}"); print(f"RESULT=FAIL no '{expect}' within 2 min of '{say}'"); return 1
                shot(page, f"reply-{i}")
            lines = [l for l in page.locator("body").inner_text().splitlines() if l.strip()][-12:]
            print("TRANSCRIPT_TAIL=" + " | ".join(lines)[:800])
            print("RESULT=PASS"); return 0
        except Exception as e:
            shot(page, "exception"); print("RESULT=FAIL " + str(e).replace("\n", " ")[:300]); return 1
        finally:
            browser.close()


if __name__ == "__main__":
    sys.exit(main())

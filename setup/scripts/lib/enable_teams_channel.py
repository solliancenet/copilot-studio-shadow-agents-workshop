#!/usr/bin/env python3
"""
FACILITATOR-ONLY. Add the Microsoft 365 and Microsoft Teams channel to a Copilot Studio agent, as its owner.

Attendees chat with the scenario agents in Teams (Lab 04), and an agent published with Microsoft
authentication is reachable only through that channel. There is no supported headless API for adding it -
Copilot Studio does it through its own UI - so, like consent_browser.py, this drives a headless browser
through the owner's sign-in and the agent's Channels page.

  python3 enable_teams_channel.py --upn <owner-upn> --password <pw> --env <environment-id> --bot <bot-id>

Prints OK=added | NOTFOUND=<what> (exit 2) | ERROR=<message> (exit 1), and on success LINK=<url>: the
agent's Teams install link (Availability options > Copy link) - the link attendees open; a plain chat link
says "You do not have permission to use this app here". It never reports success it didn't
see: a missing "Add channel" button may mean the channel is on, or that the page didn't load, so the caller
(06) checks the bot record's channels instead. The caller publishes afterwards.
Lab-only: the password is the shared lab password, passed by the engine; never use against a real tenant.

Requires: playwright with Chromium.
"""
import argparse, re, sys, time
from playwright.sync_api import sync_playwright

CS = "https://copilotstudio.microsoft.com"


def body(page):
    try:
        return page.locator("body").inner_text()
    except Exception:
        return ""


def sign_in(page, upn, password, timeout_s=180):
    """Persona sign-in (no MFA for non-admin personas). Stage-driven: act on whatever screen is showing."""
    # The portal's own host shows for a moment before it bounces to the login page, so "landed" only counts
    # once the login page has been seen (the same trap the walkthrough recorder's sign-in avoids).
    deadline = time.time() + timeout_s; saw_login = False
    while time.time() < deadline:
        page.wait_for_timeout(1500)
        host = re.sub(r"^https?://([^/]+).*", r"\1", page.url)
        if "login.microsoftonline.com" in host: saw_login = True
        t = body(page)[:2000]
        if saw_login and host == "copilotstudio.microsoft.com" and not page.locator("input[name=loginfmt]:visible").count():
            page.wait_for_timeout(4000); return True
        if "Stay signed in?" in t:
            page.click("#idBtn_Back"); continue
        if "Enter password" in t:
            page.fill("input[name=passwd]", password); page.click("#idSIButton9"); page.wait_for_timeout(4000); continue
        if page.locator("input[name=loginfmt]:visible").count():
            page.fill("input[name=loginfmt]", upn); page.click("#idSIButton9"); page.wait_for_timeout(4000); continue
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--upn", required=True); ap.add_argument("--password", required=True)
    ap.add_argument("--env", required=True); ap.add_argument("--bot", required=True)
    a = ap.parse_args()
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_context(locale="en-US", viewport={"width": 1600, "height": 1000},
                                   permissions=["clipboard-read", "clipboard-write"]).new_page()
        page.set_default_timeout(30000)
        try:
            page.goto(CS, wait_until="commit", timeout=90000)
            if not sign_in(page, a.upn, a.password):
                print("ERROR=sign-in did not complete"); return 1
            step = "open the agent"
            page.goto(f"{CS}/environments/{a.env}/bots/{a.bot}/overview", wait_until="domcontentloaded")
            page.wait_for_timeout(15000)
            # Channels sits in the agent header's overflow (+N) unless the window is wide enough to show it.
            step = "open the header overflow"
            # The overflow's entries are in the DOM even while it is closed, so open it whenever it shows, then
            # click only a VISIBLE "Channels".
            more = page.locator("text=/^\\+\\d+$/ >> visible=true")
            if more.count():
                more.first.click(); page.wait_for_timeout(2500)
            step = "open Channels"
            page.locator("text=Channels >> visible=true").last.click(); page.wait_for_timeout(12000)
            step = "open the Teams channel"
            page.locator("text=Microsoft Teams >> visible=true").first.click()
            page.wait_for_timeout(8000)
            step = "add the channel"
            def print_link():
                # Availability options > Copy link puts the install link on the clipboard.
                try:
                    page.get_by_text(re.compile("Availability options", re.I)).first.click(); page.wait_for_timeout(5000)
                    page.get_by_role("button", name=re.compile("Copy link", re.I)).first.click(); page.wait_for_timeout(1500)
                    link = page.evaluate("navigator.clipboard.readText()")
                    if link.startswith("https://teams.microsoft.com/"): print(f"LINK={link}")
                except Exception as e:
                    print("LINKERROR=" + (str(e).splitlines() or ["?"])[0][:120])
            add = page.get_by_role("button", name=re.compile(r"^\s*Add channel\s*$"))
            if not add.count():
                print_link()
                page.screenshot(path="/tmp/enable_teams_channel_error.png")
                print("NOTFOUND=no Add channel button (already on, or the panel didn't open)"); return 2
            add.first.click()
            for _ in range(30):
                page.wait_for_timeout(3000)
                if not page.get_by_role("button", name=re.compile(r"^\s*Add channel\s*$")).count():
                    print("OK=added"); print_link(); return 0
            print("ERROR=Add channel did not complete"); return 1
        except Exception as e:
            page.screenshot(path="/tmp/enable_teams_channel_error.png")
            msg = (str(e).splitlines() or [type(e).__name__])[0][:200]
            print(f"ERROR=({locals().get('step', 'sign in')}) " + msg); return 1
        finally:
            browser.close()


if __name__ == "__main__":
    sys.exit(main())

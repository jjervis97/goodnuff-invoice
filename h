cat << 'EOF' > ~/garage/gn
#!/usr/bin/env python3
"""
GOOD 'NUFF GARAGE - Main launcher

- Customer Menu  -> runs 'jobmenu' (your CSV customer tool)
- New Invoice    -> runs ~/garage/invoice
- Invoice History-> opens saved HTML invoices from ~/Outgoing
"""

import os
import sys
import subprocess
from pathlib import Path

HOME = Path("/home/goodnuffmechanic")
GARAGE = HOME / "garage"
BUSINESS = GARAGE / ".business"
OUTGOING = HOME / "Outgoing"


def pause(msg="\nPress Enter to return to menu..."):
    try:
        input(msg)
    except EOFError:
        pass


def run_customer_menu():
    """Call your existing customer menu (jobmenu)."""
    try:
        subprocess.run(["jobmenu"])
    except FileNotFoundError:
        print("\nERROR: 'jobmenu' command not found.")
        print("Make sure your customer script is installed as ~/.local/bin/jobmenu")
        pause()


def run_invoice():
    """Launch the invoice generator we just built."""
    script = GARAGE / "invoice"
    if not script.exists():
        print(f"\nERROR: invoice script not found at {script}")
        pause()
        return
    try:
        subprocess.run([str(script)])
    except FileNotFoundError:
        print("\nERROR running invoice script.")
        pause()


def view_invoice_history():
    """List recent HTML invoices in Outgoing and open one."""
    OUTGOING.mkdir(parents=True, exist_ok=True)
    # Look for HTML copies created by the invoice script
    files = sorted(
        OUTGOING.glob("GN-*.html"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )

    if not files:
        print("\nNo invoices found in Outgoing yet.")
        pause()
        return

    print("\n=== INVOICE HISTORY (HTML copies) ===\n")
    max_show = min(len(files), 25)
    for i in range(max_show):
        f = files[i]
        print(f"{i+1}) {f.name}")

    print("\nEnter invoice # to open, or just Enter to cancel.")
    choice = input("Select: ").strip()
    if not choice:
        return
    if not choice.isdigit():
        print("Invalid selection.")
        pause()
        return

    idx = int(choice)
    if idx < 1 or idx > max_show:
        print("Out of range.")
        pause()
        return

    target = files[idx - 1]
    print(f"\nOpening {target} ...\n")

    # Try to open in ChromeOS via xdg-open, fallback to less
    try:
        rc = subprocess.run(["xdg-open", str(target)]).returncode
        if rc != 0:
            raise RuntimeError
    except Exception:
        subprocess.run(["less", str(target)])


def system_tools():
    """Simple info screen for now."""
    print("\n=== SYSTEM / TOOLS ===\n")
    print(f"Garage root : {GARAGE}")
    print(f"Business dir: {BUSINESS}")
    print(f"Outgoing dir: {OUTGOING}")
    print("\nThis is just an info screen for now. We can add backup/check tools later.")
    pause()


def main():
    OUTGOING.mkdir(parents=True, exist_ok=True)

    while True:
        os.system("clear")
        print("=== GOOD 'NUFF GARAGE ===\n")
        print("1) Customer Menu")
        print("2) Create New Invoice")
        print("3) View Invoice History")
        print("4) System / Tools")
        print("5) Exit\n")

        choice = input("Choose an option [1-5]: ").strip()

        if choice == "1":
            run_customer_menu()
        elif choice == "2":
            run_invoice()
        elif choice == "3":
            view_invoice_history()
        elif choice == "4":
            system_tools()
        elif choice in ("5", "q", "Q"):
            print("\nGood 'Nuff out.\n")
            break
        else:
            print("\nInvalid choice.")
            pause()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nExiting...\n")
        sys.exit(0)
EOF
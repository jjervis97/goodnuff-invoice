#!/usr/bin/env bash
# GOODNUFF Chromebook Speed & Cleanup Script (Option C)
# Safe system + Linux + business cleanup

set -e

echo "========================================"
echo " GOODNUFF Chromebook Speed Maintenance "
echo "========================================"
echo "Start time: $(date)"
echo

### 1. Show disk + memory BEFORE cleanup
echo ">> Disk usage BEFORE:"
df -h ~ | tail -n 1
echo

echo ">> Memory usage BEFORE:"
free -h
echo

### 2. Clean apt packages (Linux container)
if command -v apt >/dev/null 2>&1; then
  echo ">> Cleaning old packages with apt (this may take a minute)..."
  sudo apt autoremove -y || echo "  (apt autoremove failed or not needed)"
  sudo apt clean || echo "  (apt clean failed or not needed)"
  echo
else
  echo ">> apt not found, skipping package cleanup."
  echo
fi

### 3. Vacuum system logs so they don't grow huge
if command -v journalctl >/dev/null 2>&1; then
  echo ">> Trimming system logs to 100M..."
  sudo journalctl --vacuum-size=100M || echo "  (journalctl vacuum skipped)"
  echo
fi

### 4. Clear user caches and temporary files
echo ">> Clearing user cache (~/.cache)..."
rm -rf ~/.cache/* 2>/dev/null || true
echo "   Done."
echo

echo ">> Clearing /tmp files older than 1 day..."
find /tmp -type f -mtime +1 -print -delete 2>/dev/null || true
echo "   Done."
echo

### 5. Ranger & thumbnail style junk (already in ~/.cache, but extra safety)
if [ -d "$HOME/.cache/thumbnails" ]; then
  echo ">> Clearing thumbnail cache..."
  rm -rf "$HOME/.cache/thumbnails" 2>/dev/null || true
  echo "   Done."
  echo
fi

### 6. GOODNUFF business folders – clean only SAFE temp stuff
echo ">> Ensuring GOODNUFF folders exist..."
mkdir -p "$HOME/.business" "$HOME/.business/.tmp" "$HOME/.business/.logs" "$HOME/Outgoing"
echo "   ~/.business, ~/.business/.tmp, ~/.business/.logs, and ~/Outgoing ready."
echo

# Only touch obvious junk: temp files, backup files, editor leftovers
echo ">> Cleaning temp/backup junk in .business and Outgoing (NOT invoices)..."
find "$HOME/.business" "$HOME/Outgoing" \
  -type f \( -name '*.tmp' -o -name '*~' -o -name '*.swp' -o -name '.DS_Store' \) \
  -print -delete 2>/dev/null || true
echo "   Done. Real invoices (PDF/HTML/JSON) are untouched."
echo

# Optional: logs older than 30 days in .business/.logs
if [ -d "$HOME/.business/.logs" ]; then
  echo ">> Deleting .business/.logs files older than 30 days..."
  find "$HOME/.business/.logs" -type f -mtime +30 -print -delete 2>/dev/null || true
  echo "   Done."
  echo
fi

### 7. Drop filesystem caches (frees RAM inside the container)
if [ -w /proc/sys/vm/drop_caches ]; then
  echo ">> Dropping filesystem caches to free RAM (requires sudo)..."
  sudo sync
  echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null || echo "  (drop_caches not allowed)"
  echo "   RAM cache dropped."
  echo
else
  echo ">> Can't access /proc/sys/vm/drop_caches, skipping RAM cache drop."
  echo
fi

### 8. Show top memory hogs (so you know what’s heavy)
echo ">> Top 10 memory-using processes NOW (for your info):"
ps aux --sort=-%mem | head -n 11
echo

### 9. Show disk + memory AFTER cleanup
echo ">> Disk usage AFTER:"
df -h ~ | tail -n 1
echo

echo ">> Memory usage AFTER:"
free -h
echo

echo "========================================"
echo " Cleanup complete. You can close this "
echo " window or run 'sysclean' again later. "
echo "========================================"
echo
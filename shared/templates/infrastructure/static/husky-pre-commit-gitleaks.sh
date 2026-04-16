#!/bin/sh
# Gitleaks pre-commit hook for secret detection
# Blocks commits containing secrets (API keys, tokens, credentials)

# Find gitleaks binary — check PATH first, then common install locations
GITLEAKS_BIN=""
if command -v gitleaks >/dev/null 2>&1; then
  GITLEAKS_BIN="gitleaks"
else
  # Windows: winget installs to AppData; also check common fallback paths
  for candidate in \
    "$LOCALAPPDATA/Microsoft/WinGet/Links/gitleaks.exe" \
    "$HOME/AppData/Local/Microsoft/WinGet/Links/gitleaks.exe" \
    "$HOME/go/bin/gitleaks" \
    "/usr/local/bin/gitleaks" \
    "/opt/homebrew/bin/gitleaks"; do
    if [ -x "$candidate" ] 2>/dev/null; then
      GITLEAKS_BIN="$candidate"
      break
    fi
  done
fi

if [ -z "$GITLEAKS_BIN" ]; then
  echo "❌ gitleaks not found in PATH or common locations."
  echo "Install: brew install gitleaks (macOS) / winget install gitleaks (Windows)"
  echo "         or: go install github.com/gitleaks/gitleaks/v8@latest"
  exit 1
fi

"$GITLEAKS_BIN" detect --staged --verbose --no-banner || {
  echo ""
  echo "❌ Secrets detected in staged files!"
  echo ""
  echo "Remove secrets before committing:"
  echo "  - Use .env files for environment variables"
  echo "  - Use config files for API keys"
  echo "  - Never commit credentials directly"
  echo ""
  echo "If this is a false positive, update .gitleaksignore"
  exit 1
}

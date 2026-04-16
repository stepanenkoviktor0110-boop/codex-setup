#!/bin/bash
# Safety hook for Codex CLI
# Receives JSON on stdin with tool call details
# Outputs JSON: {} to allow, {"stopReason": "..."} to block

# Read stdin (tool call JSON)
INPUT=$(cat)

# Extract command from JSON (the tool input contains the shell command)
CMD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # Codex passes tool input in 'input' field
    inp = data.get('input', {})
    # Shell commands can be in 'command', 'cmd', or as string input
    cmd = inp.get('command', inp.get('cmd', str(inp)))
    print(cmd)
except:
    print('')
" 2>/dev/null)

# If no command extracted, allow
if [ -z "$CMD" ]; then
    echo '{}'
    exit 0
fi

# Dangerous patterns
BLOCKED_PATTERNS=(
    'rm -rf /'
    'rm -rf /*'
    'rm -rf ~'
    'rm -rf ~/*'
    'sudo rm -rf'
    'mkfs\.'
    'dd if=.* of=/dev/'
    ':(){:|:&};:'
    'chmod 777 /'
    'chmod -R 777 /'
    '> /dev/sda'
    'curl .* | bash'
    'curl .* | sh'
    'wget .* | bash'
    'wget .* | sh'
    'shutdown'
    'reboot'
    'halt'
    'init 0'
    'init 6'
    'launchctl unload.*com.apple'
    'defaults delete /'
    'rm -rf /System'
    'rm -rf /Library'
    'rm -rf /Applications'
    'rm -rf /usr'
    'rm -rf /var'
    'rm -rf /etc'
    'rm -rf /bin'
    'rm -rf /sbin'
    'killall Finder'
    'killall Dock'
    'killall SystemUIServer'
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if echo "$CMD" | grep -qiE "$pattern"; then
        echo "{\"stopReason\": \"BLOCKED: dangerous command detected — $pattern\"}"
        exit 0
    fi
done

# Allow
echo '{}'

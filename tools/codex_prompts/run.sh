#!/usr/bin/env bash
# Kullanim: run.sh <gorev> <model>
cd /c/Users/31/Documents/we2
T="$1"; M="$2"
cat tools/codex_prompts/_header.md "tools/codex_prompts/$T.md" | codex exec -m "$M" -c model_reasoning_effort='"medium"' --skip-git-repo-check -C 'C:\Users\31\Documents\we2' -o "tools/codex_logs/${T}_last.md" - > "tools/codex_logs/$T.log" 2>&1
echo "EXIT $? $T"
tail -5 "tools/codex_logs/$T.log"

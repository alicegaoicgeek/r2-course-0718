#!/usr/bin/env bash
# Auto-backup r2-connect course map v4 → alicegaoicgeek/r2-course-0718
# Safe: only commits when files changed; never force-push.

set -euo pipefail

REPO_DIR="${REPO_DIR:-/Users/gaoyuan/Projects/r2-course-0718}"
SRC_DIR="${SRC_DIR:-/Users/gaoyuan/Desktop/r2-connect}"
LOG_DIR="${REPO_DIR}/logs"
LOG_FILE="${LOG_DIR}/backup.log"
LOCK_FILE="${REPO_DIR}/.backup.lock"

mkdir -p "$LOG_DIR" "$REPO_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# prevent overlapping cron runs
if [ -f "$LOCK_FILE" ]; then
  # stale lock > 8 minutes → remove
  if find "$LOCK_FILE" -mmin +8 | grep -q .; then
    log "WARN: stale lock removed"
    rm -f "$LOCK_FILE"
  else
    log "SKIP: previous backup still running"
    exit 0
  fi
fi
trap 'rm -f "$LOCK_FILE"' EXIT
touch "$LOCK_FILE"

cd "$REPO_DIR"

# ensure git identity for cron (no interactive)
git config user.email >/dev/null 2>&1 || git config user.email "alicegaoicgeek@users.noreply.github.com"
git config user.name  >/dev/null 2>&1 || git config user.name  "alicegaoicgeek-backup"

# pull first if remote has commits (avoid non-fast-forward)
if git rev-parse --verify origin/main >/dev/null 2>&1 || git ls-remote --heads origin main 2>/dev/null | grep -q main; then
  git fetch origin main 2>>"$LOG_FILE" || true
  if git rev-parse --verify main >/dev/null 2>&1; then
    git pull --rebase origin main 2>>"$LOG_FILE" || {
      log "WARN: pull --rebase failed, continue with local state"
    }
  fi
fi

# sync files from Desktop r2-connect
mkdir -p "$REPO_DIR/r2-connect"
FILES=(
  "课程地图-可视化-v4.html"
  "提示词加餐包-复制即用.md"
  "上线前检查SOP.md"
)

copied=0
for f in "${FILES[@]}"; do
  src="${SRC_DIR}/${f}"
  if [ -f "$src" ]; then
    cp -f "$src" "${REPO_DIR}/r2-connect/${f}"
    copied=$((copied + 1))
  else
    log "WARN: missing source: $src"
  fi
done

# always refresh README timestamp marker
cat > "$REPO_DIR/README.md" <<EOF
# r2-course-0718 · 自动备份

- **源目录**: \`~/Desktop/r2-connect\`
- **主文件**: \`r2-connect/课程地图-可视化-v4.html\`
- **频率**: 每 10 分钟（本机 cron）
- **脚本**: \`scripts/backup-push.sh\`
- **最近同步尝试**: $(date '+%Y-%m-%d %H:%M:%S %Z')

有变更才 commit + push；无变更跳过。
EOF

git add -A

if git diff --cached --quiet; then
  log "OK: no changes (synced $copied files checked)"
  exit 0
fi

# ensure branch main
if ! git rev-parse --verify main >/dev/null 2>&1; then
  git checkout -B main 2>>"$LOG_FILE" || git branch -M main
fi

MSG="backup: r2-connect v4 $(date '+%Y-%m-%d %H:%M:%S')"
git commit -m "$MSG" >>"$LOG_FILE" 2>&1
log "COMMIT: $MSG"

# push (no force)
if git push -u origin main >>"$LOG_FILE" 2>&1; then
  log "PUSH: success → origin/main"
else
  log "ERROR: push failed — see log"
  exit 1
fi

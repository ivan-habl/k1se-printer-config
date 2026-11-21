#!/usr/bin/env bash
# Installs the temperature_mcu_gd32 overlay into a Klipper checkout.
# Idempotent: safe to re-run. Does not restart Klipper.
#
#   bash ext/install.sh                       # ~/klipper
#   KLIPPER_DIR=/path/to/klipper bash ext/install.sh
set -euo pipefail

KLIPPER_DIR=${KLIPPER_DIR:-$HOME/klipper}
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/temperature_mcu_gd32.py"
REL=klippy/extras/temperature_mcu_gd32.py
UPSTREAM=klippy/extras/temperature_mcu.py

die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
info() { printf '%s\n' "$*"; }

[ -f "$SRC" ] || die "не найден $SRC"
[ -f "$KLIPPER_DIR/$UPSTREAM" ] || die "$KLIPPER_DIR не похож на checkout Klipper (нет $UPSTREAM)"
git -C "$KLIPPER_DIR" rev-parse --git-dir >/dev/null 2>&1 \
    || die "$KLIPPER_DIR не является git-репозиторием"

# 1. Symlink into klippy/extras/
ln -sfn "$SRC" "$KLIPPER_DIR/$REL"
info "symlink: $KLIPPER_DIR/$REL -> $SRC"

# 2. Hide it from git status (and thus from Moonraker's dirty check).
#    --git-path resolves the right file for linked worktrees as well.
EXCLUDE=$(git -C "$KLIPPER_DIR" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null \
          || (cd "$KLIPPER_DIR" && realpath -m "$(git rev-parse --git-path info/exclude)"))
mkdir -p "$(dirname "$EXCLUDE")"
if grep -qxF "$REL" "$EXCLUDE" 2>/dev/null; then
    info "exclude: запись уже есть в $EXCLUDE"
else
    printf '%s\n' "$REL" >> "$EXCLUDE"
    info "exclude: добавлено в $EXCLUDE"
fi

# 3. Leftover of the old patch approach: report, never revert automatically
if ! git -C "$KLIPPER_DIR" diff --quiet -- "$UPSTREAM"; then
    warn "$UPSTREAM изменён локально (вероятно, старый patches/temperature_mcu-gd32f303.patch)."
    warn "Откатите его: git -C $KLIPPER_DIR checkout -- $UPSTREAM"
elif grep -q gd32f303 "$KLIPPER_DIR/$UPSTREAM"; then
    # 4. Upstream caught up: the overlay is now redundant (harmless)
    info "NOTE: upstream $UPSTREAM уже поддерживает gd32f303 —"
    info "      оверлей и секцию [temperature_mcu_gd32] можно удалить."
fi

# 5. Syntax check
python3 -m py_compile "$SRC"
info "py_compile: OK"

if [ -n "$(git -C "$KLIPPER_DIR" status --porcelain)" ]; then
    warn "git status в $KLIPPER_DIR не пуст:"
    git -C "$KLIPPER_DIR" status --short >&2
fi

info ""
info "Готово. Примените: sudo systemctl restart klipper"

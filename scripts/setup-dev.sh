#!/bin/sh
# setup-dev.sh : installe les outils de développement d'IK+ Reforged.
#   - vasm (assembleur 68000), construit dans .tools/ ;
#   - Hatari (émulateur, essais) ;
#   - modules Python : capstone (listing du jeu), Pillow et numpy (analyse
#     des captures d'écran de Hatari).
# Sans effet sur ce qui est déjà installé. Lancé automatiquement au début de
# chaque session Claude Code sur le web (.claude/hooks/session-start.sh).
#
# Fichiers du jeu, jamais dans le dépôt : dossier IKPLUS_LOCAL (par défaut
# ../ikplus-local, à côté du dépôt) avec IK+.PRG et les ROM TOS
# (rom/tos104.img, rom/tos162.img, rom/tos206.img). S'il contient IK+.PRG,
# le script corrige aussi le jeu (make game) et vérifie les empreintes
# (make check).
set -e
cd "$(dirname "$0")/.."
LOCAL=${IKPLUS_LOCAL:-../ikplus-local}

if [ "$(id -u)" = 0 ]; then SUDO=; else SUDO=sudo; fi

# vasm
sh scripts/get-vasm.sh .tools

# Hatari
if ! command -v hatari >/dev/null 2>&1; then
    echo "setup-dev : installation de Hatari"
    $SUDO apt-get install -y -q hatari >/dev/null 2>&1 || {
        $SUDO apt-get update -q >/dev/null
        $SUDO apt-get install -y -q hatari >/dev/null
    }
fi

# modules Python
for m in capstone:capstone PIL:pillow numpy:numpy; do
    python3 -c "import ${m%%:*}" 2>/dev/null ||
        python3 -m pip install -q "${m##*:}" 2>&1 | grep -v -i warning || true
done

# construction
make -s all

if [ -f "$LOCAL/IK+.PRG" ]; then
    make -s game PRG="$LOCAL/IK+.PRG" >/dev/null
    make -s check
else
    echo "setup-dev : pas de $LOCAL/IK+.PRG ; make game et make check non lancés"
fi
for t in tos104 tos162 tos206; do
    [ -f "$LOCAL/rom/$t.img" ] || echo "setup-dev : ROM absente : $LOCAL/rom/$t.img"
done
echo "setup-dev : prêt"

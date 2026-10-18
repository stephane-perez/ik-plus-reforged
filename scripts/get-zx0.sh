#!/bin/sh
# Construit le compresseur ZX0 (Einar Saukas, licence BSD 3 clauses) dans
# .tools/zx0/. Version figée (commit ci-dessous) : le fichier compressé, et
# donc son empreinte dans `make check`, en dépendent.
# Il faut : un compilateur C, et curl ou git.
set -e
COMMIT=ecde3a2ae05061fe06469ed46df81a33b7de7d86
DEST="${1:-.tools}"
BIN="$DEST/zx0/zx0"
if [ -x "$BIN" ]; then
    echo "zx0 déjà construit : $BIN"
    exit 0
fi
mkdir -p "$DEST"
cd "$DEST"
rm -rf zx0 zx0.tar.gz
if curl -fsSL --max-time 60 -o zx0.tar.gz "https://codeload.github.com/einar-saukas/ZX0/tar.gz/$COMMIT" \
   && mkdir zx0 && tar xzf zx0.tar.gz -C zx0 --strip-components=1; then
    rm -f zx0.tar.gz
else
    rm -rf zx0 zx0.tar.gz
    git clone -q https://github.com/einar-saukas/ZX0 zx0
    git -C zx0 checkout -q "$COMMIT"
fi
${CC:-cc} -O2 -o zx0/zx0 zx0/src/zx0.c zx0/src/optimize.c zx0/src/compress.c zx0/src/memory.c
echo "zx0 construit : $DEST/zx0/zx0"

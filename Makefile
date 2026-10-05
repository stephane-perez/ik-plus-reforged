# IK+ Reforged - build
#
#   make                 builds everything that does not need the game:
#                        loaders, 3-player code, STE module, JOYTEST (French
#                        and English)
#   make game PRG=path/to/IK+.PRG
#                        also patches YOUR copy of the game and assembles the
#                        ready-to-copy folder build/IK_PLUS (one program for
#                        every machine: on an STE with 1 MB or more, the
#                        loader adds DMA sound and the blitter by itself)
#   make check           verifies the patched game against the expected checksums
#   make vasm            builds the vasm assembler into .tools/ (done automatically)
#
# Options: LIMIT=300 (length of a 3-player match, in seconds of fighting)
#          TAG=v1.0.9 (version shown on the intro page; by default the git
#          tag of the current commit, or the last tag followed by "+")

PY     ?= python3
LIMIT  ?= 300
PRG    ?= IK+.PRG
VASM   ?= $(shell command -v vasmm68k_mot 2>/dev/null || echo .tools/vasm/vasmm68k_mot)
B      := build
TAG    ?= $(shell git describe --tags --exact-match 2>/dev/null || \
            (t=$$(git describe --tags --abbrev=0 2>/dev/null); echo "$${t:-v?}+"))
VFLAGS := -quiet -m68000

TOOLS_OUT := $(B)/IK_PLUS.TOS $(B)/IK_PLUS_REF.TOS $(B)/p3.bin $(B)/p3b.bin $(B)/ste.bin $(B)/JOYTEST.TOS $(B)/JOYTSTEN.TOS

.PHONY: all game check vasm clean FORCE
all: $(TOOLS_OUT)

$(VASM):
	sh scripts/get-vasm.sh .tools

vasm: $(VASM)

$(B):
	mkdir -p $(B)

# --- our own programs (no game data involved) ------------------------------
# the loader includes the STE module, the table of its hooks and the version
$(B)/IK_PLUS.TOS: src/loader.s $(B)/ste.bin $(B)/stehooks.i $(B)/version.i | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Ftos -o $@ $<

# same loader with a fixed version text, for make check
$(B)/IK_PLUS_REF.TOS: src/loader.s $(B)/ste.bin $(B)/stehooks.i | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Ftos -DREFTAG -o $@ $<

# version text, rewritten only when the tag changes
$(B)/version.i: FORCE | $(B)
	@$(PY) -c "import sys; t='            dc.b    \'ENHANCED BY CLAUDE AI - 2026 - %s\',0\n' % sys.argv[1].upper(); \
p=sys.argv[2]; o=open(p).read() if __import__('os').path.exists(p) else ''; \
(o!=t) and open(p,'w').write(t)" "$(TAG)" $@

FORCE:

$(B)/stehooks.i: tools/patch_ste.py | $(B)
	$(PY) tools/patch_ste.py --asm $@

$(B)/p3.bin: src/p3.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Fbin -DLIMIT=$(LIMIT) -o $@ $<

$(B)/p3b.bin: src/p3b.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Fbin -o $@ $<

$(B)/ste.bin: src/ste.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Fbin -o $@ $<

$(B)/JOYTEST.TOS: src/joytest.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Ftos -o $@ $<

$(B)/JOYTSTEN.TOS: src/joytest.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Ftos -DENGLISH -o $@ $<

# --- the game: built from the user's own IK+.PRG ---------------------------
$(B)/IK_BASE.IMG: $(PRG) tools/patch_game.py tools/ikimg.py | $(B)
	$(PY) tools/patch_game.py "$(PRG)" $@

game: all $(B)/IK_BASE.IMG
	mkdir -p $(B)/IK_PLUS
	$(PY) tools/patch_p3.py $(B)/IK_BASE.IMG $(B)/p3.bin $(B)/IK_PLUS/IKPLUS.IMG $(B)/p3b.bin
	cp $(B)/IK_PLUS.TOS $(B)/IK_PLUS/
	$(PY) tools/textfile.py dist/README.TXT $(B)/IK_PLUS/README.TXT
	$(PY) tools/textfile.py dist/LISEZMOI.TXT $(B)/IK_PLUS/LISEZMOI.TXT
	@# control only: the image as the loader patches it on an STE
	$(PY) tools/patch_ste.py $(B)/IK_PLUS/IKPLUS.IMG $(B)/IK_STE_CHECK.IMG
	@echo
	@echo "Copy build/IK_PLUS to your Atari and run IK_PLUS.TOS."

# Expected MD5 with the default LIMIT=300 (the loader is checked with a fixed
# version text: IK_PLUS_REF.TOS)
check:
	@$(PY) -c "import hashlib,sys; \
exp={'$(B)/IK_PLUS/IKPLUS.IMG':'90c05ec22bd45bc9898ed30653b37300','$(B)/IK_PLUS_REF.TOS':'7ffc0b454eaa4279ae817ccdf21ab081','$(B)/IK_STE_CHECK.IMG':'368df6c7c8ae7cd4bc9c729f61e6f341'}; \
bad=[f for f,h in exp.items() if hashlib.md5(open(f,'rb').read()).hexdigest()!=h]; \
print('OK' if not bad else 'MISMATCH: '+' '.join(bad)); sys.exit(1 if bad else 0)"

clean:
	rm -rf $(B) work

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

PY     ?= python3
LIMIT  ?= 300
PRG    ?= IK+.PRG
VASM   ?= $(shell command -v vasmm68k_mot 2>/dev/null || echo .tools/vasm/vasmm68k_mot)
B      := build
VFLAGS := -quiet -m68000

TOOLS_OUT := $(B)/IK_PLUS.TOS $(B)/p3.bin $(B)/ste.bin $(B)/JOYTEST.TOS $(B)/JOYTSTEN.TOS

.PHONY: all game check vasm clean
all: $(TOOLS_OUT)

$(VASM):
	sh scripts/get-vasm.sh .tools

vasm: $(VASM)

$(B):
	mkdir -p $(B)

# --- our own programs (no game data involved) ------------------------------
# the loader includes the STE module and the table of its hooks
$(B)/IK_PLUS.TOS: src/loader.s $(B)/ste.bin $(B)/stehooks.i | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Ftos -o $@ $<

$(B)/stehooks.i: tools/patch_ste.py | $(B)
	$(PY) tools/patch_ste.py --asm $@

$(B)/p3.bin: src/p3.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Fbin -DLIMIT=$(LIMIT) -o $@ $<

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
	$(PY) tools/patch_p3.py $(B)/IK_BASE.IMG $(B)/p3.bin $(B)/IK_PLUS/IKPLUS.IMG
	cp $(B)/IK_PLUS.TOS $(B)/IK_PLUS/
	$(PY) tools/textfile.py dist/README.TXT $(B)/IK_PLUS/README.TXT
	$(PY) tools/textfile.py dist/LISEZMOI.TXT $(B)/IK_PLUS/LISEZMOI.TXT
	@# control only: the image as the loader patches it on an STE
	$(PY) tools/patch_ste.py $(B)/IK_PLUS/IKPLUS.IMG $(B)/IK_STE_CHECK.IMG
	@echo
	@echo "Copy build/IK_PLUS to your Atari and run IK_PLUS.TOS."

# Expected MD5 with the default LIMIT=300
check:
	@$(PY) -c "import hashlib,sys; \
exp={'$(B)/IK_PLUS/IKPLUS.IMG':'47c4470c565aed31afed2fdafc2fa5ae','$(B)/IK_PLUS.TOS':'467fd398b98d0594f39fc1a8764893ca','$(B)/IK_STE_CHECK.IMG':'1f8287f1eabad2373a98013a6f8e76af'}; \
bad=[f for f,h in exp.items() if hashlib.md5(open(f,'rb').read()).hexdigest()!=h]; \
print('OK' if not bad else 'MISMATCH: '+' '.join(bad)); sys.exit(1 if bad else 0)"

clean:
	rm -rf $(B) work

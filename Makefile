# IK+ Reforged - build
#
#   make                 builds everything that does not need the game:
#                        loaders, 3-player code, STE module, JOYTEST (French
#                        and English)
#   make game PRG=path/to/IK+.PRG
#                        also patches YOUR copy of the game and assembles the
#                        two ready-to-copy folders build/IK3J_PAR (any ST,
#                        parallel-port adapter, joystick 3 socket) and
#                        build/IK3J_STE (STE only: Jaguar pad on enhanced
#                        joystick port A, DMA sound, blitter)
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

TOOLS_OUT := $(B)/IK_PLUS.TOS $(B)/p3.bin $(B)/JOYTEST.TOS $(B)/JOYTSTEN.TOS \
             $(B)/p3_ste.bin $(B)/ste.bin $(B)/IK_STE.TOS

.PHONY: all game check vasm clean
all: $(TOOLS_OUT)

$(VASM):
	sh scripts/get-vasm.sh .tools

vasm: $(VASM)

$(B):
	mkdir -p $(B)

# --- our own programs (no game data involved) ------------------------------
$(B)/IK_PLUS.TOS: src/loader.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Ftos -o $@ $<

$(B)/p3.bin: src/p3.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Fbin -DLIMIT=$(LIMIT) -o $@ $<

$(B)/p3_ste.bin: src/p3.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Fbin -DLIMIT=$(LIMIT) -DSTEPAD -o $@ $<

$(B)/ste.bin: src/ste.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Fbin -o $@ $<

# the STE loader includes build/ste.bin
$(B)/IK_STE.TOS: src/loader.s $(B)/ste.bin | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Ftos -DSTE -o $@ $<

$(B)/JOYTEST.TOS: src/joytest.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Ftos -o $@ $<

$(B)/JOYTSTEN.TOS: src/joytest.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Ftos -DENGLISH -o $@ $<

# --- the game: built from the user's own IK+.PRG ---------------------------
$(B)/IK_BASE.IMG: $(PRG) tools/patch_game.py tools/ikimg.py | $(B)
	$(PY) tools/patch_game.py "$(PRG)" $@

game: all $(B)/IK_BASE.IMG
	mkdir -p $(B)/IK3J_PAR $(B)/IK3J_STE
	$(PY) tools/patch_p3.py $(B)/IK_BASE.IMG $(B)/p3.bin     $(B)/IK3J_PAR/IKPLUS.IMG
	$(PY) tools/patch_p3.py $(B)/IK_BASE.IMG $(B)/p3_ste.bin $(B)/IK_P3STE.IMG
	$(PY) tools/patch_ste.py $(B)/IK_P3STE.IMG $(B)/IK3J_STE/IKPLUS.IMG
	cp $(B)/IK_PLUS.TOS $(B)/IK3J_PAR/
	cp $(B)/IK_STE.TOS $(B)/IK3J_STE/IK_PLUS.TOS
	@echo
	@echo "Copy build/IK3J_PAR (any ST, parallel-port adapter) or build/IK3J_STE"
	@echo "(STE with 1 MB or more, Jaguar pad) to your Atari and run IK_PLUS.TOS."

# Expected MD5 with the default LIMIT=300
check:
	@$(PY) -c "import hashlib,sys; \
exp={'$(B)/IK3J_PAR/IKPLUS.IMG':'47c4470c565aed31afed2fdafc2fa5ae','$(B)/IK_PLUS.TOS':'2ee9920d4f637526efc272e407d280d2','$(B)/IK3J_STE/IKPLUS.IMG':'1f8287f1eabad2373a98013a6f8e76af','$(B)/IK_STE.TOS':'53ba614726a0e7c85fa0b59313a27917'}; \
bad=[f for f,h in exp.items() if hashlib.md5(open(f,'rb').read()).hexdigest()!=h]; \
print('OK' if not bad else 'MISMATCH: '+' '.join(bad)); sys.exit(1 if bad else 0)"

clean:
	rm -rf $(B) work

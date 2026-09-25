# IK+ Reforged - build
#
#   make                 builds everything that does not need the game:
#                        loader, 3-player code, JOYTEST (French and English)
#   make game ATOR=path/to/ATOR.EXE
#                        also patches YOUR copy of the game and assembles the
#                        two ready-to-copy folders build/IK3J_S3 and build/IK3J_S4
#   make check           verifies the patched game against the expected checksums
#   make vasm            builds the vasm assembler into .tools/ (done automatically)
#
# Options: LIMIT=300 (length of a 3-player match, in seconds of fighting)

PY     ?= python3
LIMIT  ?= 300
ATOR   ?= ATOR.EXE
VASM   ?= $(shell command -v vasmm68k_mot 2>/dev/null || echo .tools/vasm/vasmm68k_mot)
B      := build
VFLAGS := -quiet -m68000

TOOLS_OUT := $(B)/IK_PLUS.TOS $(B)/p3.bin $(B)/p3_s4.bin $(B)/JOYTEST.TOS $(B)/JOYTSTEN.TOS

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

$(B)/p3_s4.bin: src/p3.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Fbin -DLIMIT=$(LIMIT) -DPORT4 -o $@ $<

$(B)/JOYTEST.TOS: src/joytest.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Ftos -o $@ $<

$(B)/JOYTSTEN.TOS: src/joytest.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Ftos -DENGLISH -o $@ $<

# --- the game: patched from the user's own ATOR.EXE ------------------------
$(B)/ATOR_STE.EXE: $(ATOR) tools/patch_game.py | $(B)
	$(PY) tools/patch_game.py $(ATOR) $@

game: all $(B)/ATOR_STE.EXE
	mkdir -p $(B)/IK3J_S3 $(B)/IK3J_S4
	$(PY) tools/patch_p3.py $(B)/ATOR_STE.EXE $(B)/p3.bin    $(B)/IK3J_S3/ATOR.EXE
	$(PY) tools/patch_p3.py $(B)/ATOR_STE.EXE $(B)/p3_s4.bin $(B)/IK3J_S4/ATOR.EXE
	cp $(B)/IK_PLUS.TOS $(B)/IK3J_S3/
	cp $(B)/IK_PLUS.TOS $(B)/IK3J_S4/
	@echo
	@echo "Copy build/IK3J_S3 (joystick 3 socket) or build/IK3J_S4 (joystick 4 socket)"
	@echo "to your Atari and run IK_PLUS.TOS."

# Expected MD5 with the default LIMIT=300
check:
	@$(PY) -c "import hashlib,sys; \
exp={'$(B)/IK3J_S3/ATOR.EXE':'f5b9267d9eaec3f3e02d55d9b33a7e17','$(B)/IK3J_S4/ATOR.EXE':'5ebc2295d80d9c0e7e0d96bf61859cf4','$(B)/IK_PLUS.TOS':'0a89bb68ba0b62e122cc9d63670fe7fa'}; \
bad=[f for f,h in exp.items() if hashlib.md5(open(f,'rb').read()).hexdigest()!=h]; \
print('OK' if not bad else 'MISMATCH: '+' '.join(bad)); sys.exit(1 if bad else 0)"

clean:
	rm -rf $(B) work

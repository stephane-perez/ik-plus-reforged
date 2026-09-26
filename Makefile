# IK+ Reforged - build
#
#   make                 builds everything that does not need the game:
#                        loaders, 3-player code, STE module, JOYTEST (French
#                        and English)
#   make game ATOR=path/to/ATOR.EXE
#                        also patches YOUR copy of the game and assembles the
#                        three ready-to-copy folders build/IK3J_S3, build/IK3J_S4
#                        (any ST, parallel-port adapter) and build/IK3J_STE
#                        (STE only: enhanced joystick port, DMA sound, blitter)
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

TOOLS_OUT := $(B)/IK_PLUS.TOS $(B)/p3.bin $(B)/p3_s4.bin $(B)/JOYTEST.TOS $(B)/JOYTSTEN.TOS \
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

$(B)/p3_s4.bin: src/p3.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Fbin -DLIMIT=$(LIMIT) -DPORT4 -o $@ $<

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

# --- the game: patched from the user's own ATOR.EXE ------------------------
$(B)/ATOR_STE.EXE: $(ATOR) tools/patch_game.py | $(B)
	$(PY) tools/patch_game.py $(ATOR) $@

game: all $(B)/ATOR_STE.EXE
	mkdir -p $(B)/IK3J_S3 $(B)/IK3J_S4 $(B)/IK3J_STE
	$(PY) tools/patch_p3.py $(B)/ATOR_STE.EXE $(B)/p3.bin     $(B)/IK3J_S3/ATOR.EXE
	$(PY) tools/patch_p3.py $(B)/ATOR_STE.EXE $(B)/p3_s4.bin  $(B)/IK3J_S4/ATOR.EXE
	$(PY) tools/patch_p3.py $(B)/ATOR_STE.EXE $(B)/p3_ste.bin $(B)/ATOR_P3STE.EXE
	$(PY) tools/patch_ste.py $(B)/ATOR_P3STE.EXE $(B)/IK3J_STE/ATOR.EXE
	cp $(B)/IK_PLUS.TOS $(B)/IK3J_S3/
	cp $(B)/IK_PLUS.TOS $(B)/IK3J_S4/
	cp $(B)/IK_STE.TOS $(B)/IK3J_STE/IK_PLUS.TOS
	@echo
	@echo "Copy build/IK3J_S3 (joystick 3 socket), build/IK3J_S4 (joystick 4 socket)"
	@echo "or build/IK3J_STE (STE with 1 MB or more) to your Atari and run IK_PLUS.TOS."

# Expected MD5 with the default LIMIT=300
check:
	@$(PY) -c "import hashlib,sys; \
exp={'$(B)/IK3J_S3/ATOR.EXE':'cd6b83ab485dc33f0b6de4bbc8df2423','$(B)/IK3J_S4/ATOR.EXE':'c70c6e623faa00cce0509e4c527b757d','$(B)/IK_PLUS.TOS':'0a89bb68ba0b62e122cc9d63670fe7fa','$(B)/IK3J_STE/ATOR.EXE':'000bc16b2c0866b16e001c22b0c8048d','$(B)/IK_STE.TOS':'1a711eae25e9a54b95d59478dbc3e1b4'}; \
bad=[f for f,h in exp.items() if hashlib.md5(open(f,'rb').read()).hexdigest()!=h]; \
print('OK' if not bad else 'MISMATCH: '+' '.join(bad)); sys.exit(1 if bad else 0)"

clean:
	rm -rf $(B) work

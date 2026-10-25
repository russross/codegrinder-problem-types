.SUFFIXES:
.SUFFIXES: .o .s .out .xml .input .transcript

ALLSRC=$(wildcard *.s)
START=$(filter start.s, $(ALLSRC))
AOUTSRC=$(START) $(filter-out $(START), $(ALLSRC))
RISCLET_VERSION=v0.5.5

STEPPER_CMD=risclet run --strict $(AOUTSRC)
STEPPER_DIR=inputs
STEPPER_TIMEOUT=5
STEPPER_GRADE=false
export STEPPER_CMD STEPPER_DIR STEPPER_TIMEOUT STEPPER_GRADE

all:	step

grade:	export STEPPER_GRADE := true
grade:	risclet
	@rm -f test_detail.xml
	@sh lib/stepper -- $(STEPPER_CMD)

run:	risclet
	risclet run $(AOUTSRC)

step:	risclet
	@sh lib/stepper -- $(STEPPER_CMD)

trace:	risclet
	risclet trace $(AOUTSRC)

debug:	risclet
	risclet debug $(AOUTSRC)

clean:
	rm -f core *.o *.out *.xml

.PHONY: risclet
risclet:
	@command -v update-grind >/dev/null 2>&1 || exit 0; \
	installed_version=$$("$$HOME/.local/bin/risclet" --version 2>/dev/null | awk '{ \
		for (i = 1; i <= NF; i++) { \
			if ($$i ~ /^v?[0-9]+\.[0-9]+\.[0-9]+$$/) { \
				sub(/^v/, "", $$i); \
				print "v" $$i; \
				exit; \
			} \
		} \
	}'); \
	if [ "$$installed_version" != "$(RISCLET_VERSION)" ] \
			|| [ -e /usr/local/bin/risclet ] \
			|| [ -L /usr/local/bin/risclet ]; then \
		update-grind risclet "$(RISCLET_VERSION)"; \
	fi

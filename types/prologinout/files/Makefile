.SUFFIXES:
.SUFFIXES: .pl .out .xml .input .transcript

PROLOGSOURCE=$(wildcard *.pl)

STEPPER_CMD=swipl -qs $(PROLOGSOURCE)
STEPPER_DIR=inputs
STEPPER_TIMEOUT=10
STEPPER_GRADE=false
export STEPPER_CMD STEPPER_DIR STEPPER_TIMEOUT STEPPER_GRADE

all:	step

grade:	export STEPPER_GRADE := true
grade: check-stepper
	@rm -f test_detail.xml
	stepper -- $(STEPPER_CMD)

run:	
	$(STEPPER_CMD)

step: check-stepper
	stepper -- $(STEPPER_CMD)

.PHONY: check-stepper
check-stepper:
	@command -v stepper >/dev/null 2>&1 || { echo "stepper not found--run 'grind upgrade' to install it" >&2; exit 1; }

shell:
	swipl

setup:
	sudo apt install -y curl make swi-prolog

clean:
	rm -f test_detail.xml

.SUFFIXES:
.SUFFIXES: .py .xml

.PHONY: all grade step shell run debug stylecheck setup clean

PYTHONSOURCE := $(wildcard *.py)

# find the main source file
py_count := $(shell ls | grep '\.py$$' | wc -l | tr -d ' ')
main_py_count := $(shell ls | grep '^main\.py$$' | wc -l | tr -d ' ')
def_main_count := $(shell grep -l '^def main\b' $(PYTHONSOURCE) | wc -l | tr -d ' ')

ifeq ($(py_count), 1)
    PYTHONMAIN := $(shell ls *.py)
else ifeq ($(main_py_count), 1)
    PYTHONMAIN := main.py
else ifeq ($(def_main_count), 1)
    PYTHONMAIN := $(shell grep -l '^def main\b' $(PYTHONSOURCE))
else
    PYTHONMAIN := NO_MAIN_PYTHON_FILE
endif

STEPPER_CMD=python3 $(PYTHONMAIN)
STEPPER_DIR=inputs
STEPPER_TIMEOUT=5
STEPPER_POSTERRORLINES=15
STEPPER_GRADE=false
export STEPPER_CMD STEPPER_DIR STEPPER_TIMEOUT STEPPER_POSTERRORLINES STEPPER_GRADE

all:	step

grade:	export STEPPER_GRADE := true
grade:
	@rm -f test_detail.xml
	mypy --strict *.py
	python3 lib/stepper

step:
	mypy --strict *.py
	python3 lib/stepper

shell:
	python3

run:
	mypy --strict *.py
	python3 -i $(PYTHONMAIN)

debug:
	mypy --strict *.py
	pdb3 $(PYTHONMAIN)

stylecheck:
	mypy --strict *.py
	pep8 $(PYTHONSOURCE)

setup:
	sudo apt install -y diffutils icdiff make mypy python3 python3-pip python3-six
	sudo pip3 install unittest-xml-reporting

clean:
	rm -rf __pycache__ .mypy_cache test_detail.xml

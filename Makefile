-include config.mak

RM ?= rm
TIME ?= time
INSTALL ?= install
ELIXIR ?= elixir
MIX ?= mix
DIALYZER ?= dialyzer

TESTS = test-lex-pass \
	test-lex-fail \
	test-parse-pass \
	test-parse-fail

.PHONY: all docs escript ebin update clean distclean test dialyze install uninstall $(TESTS)

all: ebin/flect

config.mak:
	@$(ELIXIR) config.exs

test: $(TESTS)

override RUN_TEST = $(TIME) -p $(ELIXIR) --erl "-noinput +B -kernel error_logger silent" -pz ebin test.exs

test-lex-pass: ebin/flect.app
	@$(RUN_TEST) tests/lex-pass

test-lex-fail: ebin/flect.app
	@$(RUN_TEST) tests/lex-fail

test-parse-pass: ebin/flect.app
	@$(RUN_TEST) tests/parse-pass

test-parse-fail: ebin/flect.app
	@$(RUN_TEST) tests/parse-fail

docs: ebin/flect.app
	@$(MIX) docs

escript: ebin/flect

ebin/flect: ebin/flect.app
	@$(MIX) escriptize

ebin: ebin/flect.app

ebin/flect.app: $(wildcard lib/*.ex) $(wildcard lib/*/*.ex) $(wildcard lib/*/*/*.ex)
	@$(MIX) compile

clean:
	@$(MIX) clean --all
	$(RM) flect
	$(RM) erl_crash.dump

distclean: clean
	$(RM) config.mak

dialyze: ebin/flect.app
	@$(DIALYZER) --no_check_plt -r ebin \
		-Wunmatched_returns \
		-Werror_handling \
		-Wrace_conditions

install: ebin/flect
	$(INSTALL) -m755 -d $(FLECT_PREFIX)
	$(INSTALL) -m755 -d $(FLECT_BIN_DIR)
	$(INSTALL) -m755 -d $(FLECT_LIB_DIR)
	$(INSTALL) -m755 -d $(FLECT_ST_LIB_DIR)
	$(INSTALL) -m755 -d $(FLECT_SH_LIB_DIR)
	$(INSTALL) -m755 ebin/flect $(FLECT_BIN_DIR)

uninstall:
	$(RM) $(FLECT_BIN_DIR)/flect
	$(RM) -r $(FLECT_ST_LIB_DIR)/*
	$(RM) -r $(FLECT_SH_LIB_DIR)/*

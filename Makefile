-include config.mak

RM ?= rm
TIME ?= time
ELIXIR ?= elixir
MIX ?= mix
DIALYZER ?= dialyzer

TESTS = test-lex-pass \
	test-lex-fail \
	test-parse-pass \
	test-parse-fail

.PHONY: all escript ebin update clean distclean test dialyze $(TESTS)

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

escript: ebin/flect

ebin/flect: ebin/flect.app
	@$(MIX) escriptize

ebin: ebin/flect.app

ebin/flect.app: $(wildcard lib/*.ex) $(wildcard lib/*/*.ex) $(wildcard lib/*/*/*.ex)
	@$(MIX) compile

clean:
	@$(MIX) clean --all
	$(RM) -f flect
	$(RM) -f *.dump

distclean: clean
	$(RM) -f config.mak

dialyze: ebin/flect.app
	@$(DIALYZER) --no_check_plt -r ebin \
		-Wunmatched_returns \
		-Werror_handling \
		-Wrace_conditions

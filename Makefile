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

.PHONY: all escript ebin deps update clean distclean test dialyze $(TESTS)

all: ebin/flect

config.mak:
	@$(ELIXIR) config.exs

test: $(TESTS)

test-lex-pass: ebin/flect
	@$(TIME) -p $(ELIXIR) --erl "-noinput +B" test.exs tests/lex-pass

test-lex-fail: ebin/flect
	@$(TIME) -p $(ELIXIR) --erl "-noinput +B" test.exs tests/lex-fail

test-parse-pass: ebin/flect
	@$(TIME) -p $(ELIXIR) --erl "-noinput +B" test.exs tests/parse-pass

test-parse-fail: ebin/flect
	@$(TIME) -p $(ELIXIR) --erl "-noinput +B" test.exs tests/parse-fail

escript: ebin/flect

ebin/flect: ebin/flect.app
	@$(MIX) escriptize

ebin: ebin/flect.app

ebin/flect.app: deps/ansiex/ebin/ansiex.app $(wildcard lib/*.ex) $(wildcard lib/*/*.ex) $(wildcard lib/*/*/*.ex)
	@$(MIX) compile

deps/ansiex/ebin/ansiex.app: deps/ansiex
	@$(MIX) deps.compile

deps: deps/ansiex

deps/ansiex:
	@$(MIX) deps.get

update: deps/ansiex
	@$(MIX) deps.update

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

-include config.mak

RM ?= rm
TIME ?= time
ELIXIR ?= elixir
MIX ?= mix
DIALYZER ?= dialyzer

.PHONY: all escript ebin deps update clean distclean test dialyze

all: ebin/flect

config.mak:
	@$(ELIXIR) config.exs

test: ebin/flect
	@$(TIME) -p $(ELIXIR) --erl "-noinput +B" test.exs tests/lex-pass
	@$(TIME) -p $(ELIXIR) --erl "-noinput +B" test.exs tests/lex-fail
	@$(TIME) -p $(ELIXIR) --erl "-noinput +B" test.exs tests/parse-pass
	@$(TIME) -p $(ELIXIR) --erl "-noinput +B" test.exs tests/parse-fail

escript: ebin/flect

ebin/flect: ebin/flect.app
	@$(MIX) escriptize

ebin: ebin/flect.app

ebin/flect.app: deps/ansiex/ebin/ansiex.app $(wildcard lib/*.ex) $(wildcard lib/*/*.ex)
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

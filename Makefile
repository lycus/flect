-include config.mak

RM ?= rm
TIME ?= time
ELIXIR ?= elixir
MIX ?= mix
DIALYZER ?= dialyzer

.PHONY: all escript ebin deps update clean distclean test dialyze

all: escript

config.mak:
	@$(ELIXIR) config.exs

test: escript
	@$(TIME) -p $(ELIXIR) test.exs tests/lex-pass
	@$(TIME) -p $(ELIXIR) test.exs tests/lex-fail
	@$(TIME) -p $(ELIXIR) test.exs tests/parse-pass
	@$(TIME) -p $(ELIXIR) test.exs tests/parse-fail

escript: ebin
	@$(MIX) escriptize

ebin: deps
	@$(MIX) do deps.compile, compile

deps:
	@$(MIX) deps.get

update: deps
	@$(MIX) deps.update

clean:
	@$(MIX) clean --all
	$(RM) -f flect
	$(RM) -f *.dump

distclean: clean
	$(RM) -f config.mak

dialyze: ebin
	@$(DIALYZER) --no_check_plt -r ebin \
		-Wunmatched_returns \
		-Werror_handling \
		-Wrace_conditions

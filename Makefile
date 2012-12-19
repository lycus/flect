include config.mak

RM ?= rm
ELIXIR ?= elixir
MIX ?= mix
DIALYZER ?= dialyzer

.PHONY: all escript ebin deps update clean distclean test dialyze

all: escript

config.mak:
	@$(ELIXIR) config.exs

test: escript
	@$(ELIXIR) test.exs tests/lex-pass
	@$(ELIXIR) test.exs tests/lex-fail

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

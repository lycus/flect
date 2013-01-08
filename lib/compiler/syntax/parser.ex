defmodule Flect.Compiler.Syntax.Parser do
    @typep state() :: {[Flect.Compiler.Syntax.Token.t()], Flect.Compiler.Syntax.Location.t()}
    @typep return() :: {Flect.Compiler.Syntax.Node.t(), state()}
    @typep return_m() :: {[Flect.Compiler.Syntax.Node.t()], state()}

    @spec parse([Flect.Compiler.Syntax.Token.t()], String.t()) :: [Flect.Compiler.Syntax.Node.t()]
    def parse(tokens, file) do
        loc = if (t = Enum.first(tokens)) != nil, do: t.location(), else: Flect.Compiler.Syntax.Location.new(file: file)
        do_parse({tokens, loc})
    end

    @spec do_parse(state(), [Flect.Compiler.Syntax.Node.t()]) :: [Flect.Compiler.Syntax.Node.t()]
    defp do_parse(state, mods // []) do
        case expect_token(state, :mod, "module declaration", true) do
            {_, _, _} ->
                {mod, state} = parse_mod(state)
                do_parse(state, [mod | mods])
            :eof -> Enum.reverse(mods)
        end
    end

    @spec parse_simple_name(state()) :: return()
    defp parse_simple_name(state) do
        {_, tok, state} = expect_token(state, :identifier, "identifier")
        {new_node(:simple_name, tok.location(), [name: tok]), state}
    end

    @spec parse_qualified_name(state(), {[Flect.Compiler.Syntax.Node.t()], [Flect.Compiler.Syntax.Token.t()]}) :: return()
    defp parse_qualified_name(state, {names, seps} // {[], []}) do
        {name, state} = parse_simple_name(state)

        case next_token(state) do
            {:colon_colon, tok, state} ->
                parse_qualified_name(state, {[name | names], [tok | seps]})
            _ ->
                names = [name | names] |> Enum.reverse()
                seps = seps |> Enum.map(fn(x) -> {:separator, x} end) |> Enum.reverse()
                {new_node(:qualified_name, Enum.at!(names, 0).location(), seps, names), state}
        end
    end

    @spec parse_mod(state()) :: return()
    defp parse_mod(state) do
        {_, tok_mod, state} = expect_token(state, :mod, "module declaration")
        {name, state} = parse_qualified_name(state)
        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {decls, state} = parse_decls(state)
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        tokens = [mod_keyword: tok_mod,
                  opening_brace: tok_open,
                  closing_brace: tok_close]

        {new_node(:module_declaration, tok_mod.location(), tokens, decls, [name: name]), state}
    end

    @spec parse_decls(state(),  [Flect.Compiler.Syntax.Node.t()]) :: return_m()
    defp parse_decls(state, decls // []) do
        case next_token(state) do
            {v, token, state} when v in [:pub, :priv] ->
                decl = case expect_token(state, [:fn, :struct, :union, :trait, :impl, :glob, :const, :macro], "declaration") do
                    {:fn, _, _} -> parse_fn(state, token)
                    {:struct, _, _} -> parse_struct(state, token)
                    {:union, _, _} -> parse_union(state, token)
                    {:trait, _, _} -> parse_trait(state, token)
                    {:impl, _, _} -> parse_impl(state, token)
                    {:glob, _, _} -> parse_glob(state, token)
                    {:const, _, _} -> parse_const(state, token)
                    {:macro, _, _} -> parse_macro(state, token)
                end

                parse_decls(state, [decl | decls])
            _ -> {Enum.reverse(decls), state}
        end
    end

    @spec parse_fn(state(), Flect.Compiler.Syntax.Token.t()) :: return()
    defp parse_fn(state, visibility) do
        exit(:todo)
    end

    @spec parse_struct(state(), Flect.Compiler.Syntax.Token.t()) :: return()
    defp parse_struct(state, visibility) do
        exit(:todo)
    end

    @spec parse_union(state(), Flect.Compiler.Syntax.Token.t()) :: return()
    defp parse_union(state, visibility) do
        exit(:todo)
    end

    @spec parse_trait(state(), Flect.Compiler.Syntax.Token.t()) :: return()
    defp parse_trait(state, visibility) do
        exit(:todo)
    end

    @spec parse_impl(state(), Flect.Compiler.Syntax.Token.t()) :: return()
    defp parse_impl(state, visibility) do
        exit(:todo)
    end

    @spec parse_glob(state(), Flect.Compiler.Syntax.Token.t()) :: return()
    defp parse_glob(state, visibility) do
        exit(:todo)
    end

    @spec parse_const(state(), Flect.Compiler.Syntax.Token.t()) :: return()
    defp parse_const(state, visibility) do
        exit(:todo)
    end

    @spec parse_macro(state(), Flect.Compiler.Syntax.Token.t()) :: return()
    defp parse_macro(state, visibility) do
        exit(:todo)
    end

    @spec next_token(state(), boolean()) :: {atom(), Flect.Compiler.Syntax.Token.t(), state()} | :eof
    defp next_token({tokens, loc}, eof // false) do
        case tokens do
            [h | t] ->
                case h.type() do
                    # TODO: Attach comments to AST nodes.
                    a when a in [:line_comment, :block_comment] -> next_token({t, h.location()}, eof)
                    a -> {a, h, {t, h.location()}}
                end
            [] when eof -> :eof
            _ -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Unexpected end of token stream",
                                                           location: loc])
        end
    end

    @spec expect_token(state(), atom() | [atom(), ...], String.t(), boolean()) :: {atom(), Flect.Compiler.Syntax.Token.t(), state()} | :eof
    defp expect_token(state, type, str, eof // false) do
        case next_token(state, eof) do
            tup = {t, tok, {_, l}} ->
                ok = cond do
                    is_list(type) -> Enum.find_index(type, fn(x) -> x == t end) != nil
                    is_atom(type) -> t == type
                end

                if !ok do
                    raise(Flect.Compiler.Syntax.SyntaxError, [error: "Expected #{str}, but got '#{tok.value()}'",
                                                              location: l])
                end

                tup
            # We only get :eof if eof is true.
            :eof -> :eof
        end
    end

    @spec new_node(atom(), Flect.Compiler.Syntax.Location.t(), [{atom(), Flect.Compiler.Syntax.Token.t()}, ...],
                   [Flect.Compiler.Syntax.Node.t()], [{atom(), Flect.Compiler.Syntax.Node.t()}]) :: Flect.Compiler.Syntax.Node.t()
    defp new_node(type, loc, tokens, children // [], named_children // []) do
        Flect.Compiler.Syntax.Node.new(type: type,
                                       location: loc,
                                       tokens: tokens,
                                       named_children: named_children,
                                       children: children)
    end
end

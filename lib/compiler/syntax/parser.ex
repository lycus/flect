defmodule Flect.Compiler.Syntax.Parser do
    @moduledoc """
    Contains the parser for Flect source code documents.
    """

    @typep location() :: Flect.Compiler.Syntax.Location.t()
    @typep token() :: Flect.Compiler.Syntax.Token.t()
    @typep ast_node() :: Flect.Compiler.Syntax.Node.t()
    @typep state() :: {[token()], location()}
    @typep return_n() :: {ast_node(), state()}
    @typep return_m() :: {[ast_node()], state()}
    @typep return_nt() :: {ast_node(), [token()], state()}
    @typep return_mt() :: {[ast_node()], [token()], state()}

    @doc """
    Parses the given list of tokens into a list of
    `Flect.Compiler.Syntax.Node`s representing the module declarations
    (and everything inside those) of the source code document. Returns the
    resulting list or throws a `Flect.Compiler.Syntax.SyntaxError` is the
    source code is malformed.

    `tokens` must be a list of `Flect.Compiler.Syntax.Token`s. `file` must
    be a binary containing the file name (used to report syntax errors).
    """
    @spec parse([Flect.Compiler.Syntax.Token.t()], String.t()) :: [Flect.Compiler.Syntax.Node.t()]
    def parse(tokens, file) do
        loc = if t = Enum.first(tokens), do: t.location(), else: Flect.Compiler.Syntax.Location[file: file]
        do_parse({tokens, loc})
    end

    @spec do_parse(state(), [ast_node()]) :: [ast_node()]
    defp do_parse(state, mods // []) do
        case expect_token(state, [:pub, :priv], "module declaration", true) do
            {_, token, state} ->
                {mod, state} = parse_mod(state, token)
                do_parse(state, [mod | mods])
            :eof -> Enum.reverse(mods)
        end
    end

    @spec parse_simple_name(state()) :: return_n()
    defp parse_simple_name(state) do
        {_, tok, state} = expect_token(state, :identifier, "identifier")
        {new_node(:simple_name, tok.location(), [name: tok]), state}
    end

    @spec parse_qualified_name(state(), {[{atom(), ast_node()}], [token()]}) :: return_n()
    defp parse_qualified_name(state, {names, seps} // {[], []}) do
        {name, state} = parse_simple_name(state)

        case next_token(state) do
            {:colon_colon, tok, state} ->
                parse_qualified_name(state, {[{:name, name} | names], [tok | seps]})
            _ ->
                names = [{:name, name} | names] |> Enum.reverse()
                seps = seps |> Enum.map(fn(x) -> {:separator, x} end) |> Enum.reverse()
                {new_node(:qualified_name, elem(hd(names), 1).location(), seps, names), state}
        end
    end

    @spec parse_mod(state(), token()) :: return_n()
    defp parse_mod(state, visibility) do
        {_, tok_mod, state} = expect_token(state, :mod, "'mod' keyword")
        {name, state} = parse_qualified_name(state)
        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {decls, state} = parse_decls(state)
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        tokens = [visibility: visibility,
                  mod_keyword: tok_mod,
                  opening_brace: tok_open,
                  closing_brace: tok_close]

        {new_node(:module_declaration, tok_mod.location(), tokens, [{:name, name} | decls]), state}
    end

    @spec parse_decls(state(),  [{:declaration, ast_node()}]) :: return_m()
    defp parse_decls(state, decls // []) do
        case next_token(state) do
            {v, token, state} when v in [:pub, :priv] ->
                {decl, state} = case expect_token(state, [:fn, :struct, :union, :enum, :type, :trait,
                                                          :impl, :glob, :tls, :const, :macro], "declaration") do
                    {:fn, _, _} -> parse_fn_decl(state, token)
                    {:struct, _, _} -> parse_struct_decl(state, token)
                    {:union, _, _} -> parse_union_decl(state, token)
                    {:enum, _, _} -> parse_enum_decl(state, token)
                    {:type, _, _} -> parse_type_decl(state, token)
                    {:trait, _, _} -> parse_trait_decl(state, token)
                    {:impl, _, _} -> parse_impl_decl(state, token)
                    {:glob, _, _} -> parse_glob_decl(state, token)
                    {:tls, _, _} -> parse_tls_decl(state, token)
                    {:const, _, _} -> parse_const_decl(state, token)
                    {:macro, _, _} -> parse_macro_decl(state, token)
                end

                parse_decls(state, [{:declaration, decl} | decls])
            _ -> {Enum.reverse(decls), state}
        end
    end

    @spec parse_fn_decl(state(), token()) :: return_n()
    defp parse_fn_decl(state, visibility) do
        exit(:todo)
    end

    defp parse_struct_decl(state, visibility) do
        {_, tok_struct, state} = expect_token(state, :struct, "structure declaration")
        {name, state} = parse_simple_name(state)
        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {fields, state} = parse_fields(state)
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        tokens = [visibility_keyword: visibility,
                  struct_keyword: tok_struct,
                  opening_brace: tok_open,
                  closing_brace: tok_close]

        fields = lc field inlist fields, do: {:field, field}

        {new_node(:struct_declaration, tok_struct.location(), tokens, [{:name, name} | fields]), state}
    end

    @spec parse_fields(state(), [ast_node()]) :: return_m()
    defp parse_fields(state, fields // []) do
        case next_token(state) do
            {v, token, state} when v in [:pub, :priv] ->
                {field, state} = parse_field(state, token)
                parse_fields(state, [field | fields])
            _ -> {Enum.reverse(fields), state}
        end
    end

    @spec parse_field(state(), token()) :: return_n()
    defp parse_field(state, visibility) do
        {name, state} = parse_simple_name(state)
        {_, tok_colon, state} = expect_token(state, :colon, "colon")
        {type, state} = parse_type(state)
        {_, tok_semicolon, state} = expect_token(state, :semicolon, "semicolon")

        {new_node(:field_declaration, name.location(), [visibility_keyword: visibility,
                                                        colon: tok_colon,
                                                        semicolon: tok_semicolon],
                  [name: name, type: type]), state}
    end

    @spec parse_union_decl(state(), token()) :: return_n()
    defp parse_union_decl(state, visibility) do
        exit(:todo)
    end

    @spec parse_enum_decl(state(), token()) :: return_n()
    defp parse_enum_decl(state, visibility) do
        exit(:todo)
    end

    @spec parse_type_decl(state(), token()) :: return_n()
    defp parse_type_decl(state, visibility) do
        exit(:todo)
    end

    @spec parse_trait_decl(state(), token()) :: return_n()
    defp parse_trait_decl(state, visibility) do
        exit(:todo)
    end

    @spec parse_impl_decl(state(), token()) :: return_n()
    defp parse_impl_decl(state, visibility) do
        exit(:todo)
    end

    @spec parse_glob_decl(state(), token()) :: return_n()
    defp parse_glob_decl(state, visibility) do
        exit(:todo)
    end

    @spec parse_tls_decl(state(), token()) :: return_n()
    defp parse_tls_decl(state, visibility) do
        exit(:todo)
    end

    @spec parse_const_decl(state(), token()) :: return_n()
    defp parse_const_decl(state, visibility) do
        exit(:todo)
    end

    @spec parse_macro_decl(state(), token()) :: return_n()
    defp parse_macro_decl(state, visibility) do
        exit(:todo)
    end

    @spec parse_type(state()) :: return_n()
    defp parse_type(state) do
        case expect_token(state, [:identifier, :paren_open, :fn, :bracket_open, :at, :star, :ampersand], "type signature") do
            {:identifier, _, _} -> parse_nominal_type(state)
            {:paren_open, _, _} -> parse_tuple_type(state)
            {:fn, _, _} -> parse_function_type(state)
            {:bracket_open, _, _} -> parse_vector_type(state)
            {v, _, _} when v in [:at, :star, :ampersand] -> parse_general_pointer_types(state)
        end
    end

    @spec parse_nominal_type(state()) :: return_n()
    defp parse_nominal_type(state) do
        {name, state} = parse_qualified_name(state)

        {ty_args, state} = case next_token(state) do
            {:bracket_open, _, _} ->
                {ty_args, state} = parse_type_arguments(state)
                {[arguments: ty_args], state}
            _ -> {[], state}
        end

        {new_node(:nominal_type, name.location(), [], [name: name] ++ ty_args), state}
    end

    @spec parse_type_arguments(state()) :: return_n()
    defp parse_type_arguments(state) do
        {_, tok_open, state} = expect_token(state, :bracket_open, "opening bracket")
        {types, toks, state} = parse_type_list(state, [])
        {_, tok_close, state} = expect_token(state, :bracket_close, "closing bracket")

        types = lc type inlist types, do: {:argument, type}
        toks = lc tok inlist toks, do: {:comma, tok}

        {new_node(:type_arguments, tok_open.location(), 
                  [opening_bracket: tok_open] ++ toks ++ [closing_bracket: tok_close], types), state}
    end

    @spec parse_type_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_type_list(state, types, tokens // []) do
        {type, state} = parse_type(state)

        case next_token(state) do
            {:comma, tok, state} -> parse_type_list(state, [type | types], [tok | tokens])
            _ -> {[type | types], tokens, state}
        end
    end

    @spec parse_tuple_type(state()) :: return_n()
    defp parse_tuple_type(state) do
        {_, tok_open, state} = expect_token(state, :paren_open, "opening parenthesis")
        {type, state} = parse_type(state)
        {_, tok_comma, state} = expect_token(state, :comma, "comma")
        {types, toks, state} = parse_type_list(state, [type])
        {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")

        types = lc typ inlist types, do: {:element, typ}
        toks = lc tok inlist toks, do: {:comma, tok}

        {new_node(:tuple_type, tok_open.location(),
                  [opening_parenthesis: tok_open] ++ toks ++ [closing_parenthesis: tok_close], types), state}
    end

    @spec parse_function_type(state()) :: return_n()
    defp parse_function_type(state) do
        {_, _, state} = expect_token(state, :fn, "fn keyword")

        case expect_token(state, [:at, :paren_open, :ext], "function type") do
            {:at, _, _} -> parse_closure_pointer_type(state)
            {v, _, _} when v in [:ext, :paren_open] -> parse_function_pointer_type(state)
        end
    end

    @spec parse_function_pointer_type(state()) :: return_n()
    defp parse_function_pointer_type(state) do
        case expect_token(state, [:paren_open, :ext], "function pointer type") do
            {:ext, _, _} -> parse_external_function_pointer_type(state)
            # just adding a comment here so we remember to change
            {:paren_open, _, _} -> parse_function_type_parameters(state)
        end
    end

    @spec parse_external_function_pointer_type(state()) :: return_n()
    defp parse_external_function_pointer_type(state) do
        {_, _, state} = expect_token(state, :ext, "ext")
        {_, tok_abi, state} = expect_token(state, :string, "function ABI string")
        {list, state} = parse_function_type_parameters(state)

        {new_node(:ext, tok_abi.location(), [abi: tok_abi], [list: list]), state}
    end

    @spec parse_closure_pointer_type(state()) :: return_n()
    defp parse_closure_pointer_type(state) do
        {_, tok_fn, state} = expect_token(state, :fn, "fn keyword")
        {_, tok_closure, state} = expect_token(state, :at, "@")
        {type_param, state} = parse_function_type_parameters(state)
        {_, tok_arrow, state} = expect_token(state, :minus_angle_close, "return type arrow")
        {return_type, state} = parse_return_type(state)

        {new_node(:closure_pointer_type, tok_fn.location(),
                  [at: tok_closure] ++ [arrow: tok_arrow], [type: type_param, type: return_type]), state}
    end

    @spec parse_function_type_parameters(state()) :: return_n()
    defp parse_function_type_parameters(state) do
        {_, tok_open, state} = expect_token(state, :paren_open, "opening parenthesis")
        {type_params, toks, state} = parse_function_type_parameter_list(state, [])
        {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")

        types = lc type inlist type_params, do: {:function_type_parameter, type}
        toks = lc tok inlist toks, do: {:comma, tok}

        {new_node(:function_type_parameters, tok_open.location(), 
                  [paren_open: tok_open] ++ toks ++ [paren_close: tok_close], types), state}
    end

    @spec parse_function_type_parameter_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_function_type_parameter_list(state, types, tokens // []) do
        {type, state} = parse_function_type_parameter(state)

        case next_token(state) do
            {:comma, tok, state} -> parse_function_type_parameter_list(state, [type | types], [tok | tokens])
            _ -> {Enum.reverse([type | types]), tokens, state}
        end
    end

    @spec parse_function_type_parameter(state()) :: return_n()
    defp parse_function_type_parameter(state) do
        case next_token(state) do
            {v, token, state} when v in [:mut, :ref] ->
                {param_type, state} = parse_type(state)
                {new_node(:func_type_param, param_type.location(), [name: token], [type: param_type]), state}

            _ ->
                {param_type, state} = parse_type(state)
                {new_node(:func_type_param, param_type.location(), [], [type: param_type]), state}
        end
    end

    @spec parse_vector_type(state()) :: return_n()
    defp parse_vector_type(state) do
        {_, tok_open, state} = expect_token(state, :bracket_open, "opening bracket")
        {type, state} = parse_type(state)
        {_, tok_period_period, state} = expect_token(state, :period_period, "ellipsis")
        {_, tok_int, state} = expect_token(state, :integer, "integer")
        {_, tok_close, state} = expect_token(state, :bracket_close, "closing bracket")

        {new_node(:vector_type, tok_open.location(),
                  [opening_bracket: tok_open] ++ [ellipsis: tok_period_period] ++ [size: tok_int] ++
                  [closing_bracket: tok_close], [type: type]), state}
    end

    @spec parse_general_pointer_types(state()) :: return_n()
    defp parse_general_pointer_types(state) do
        {_, pointer_type, state} = expect_token(state, [:at, :star, :ampersand], "pointer type")
            {ty_arg, state} = case next_token(state) do
                {w, token, state} when w in [:mut, :imm] ->
                    {type, state} = parse_pointer_types(state)
                    {[arguments: type], state}
                _ ->
                    {type, state} = parse_pointer_types(state)
                    {[arguments: type], state}
            end

        {new_node(:pointer_types, pointer_type.location(), [name: pointer_type], ty_arg), state}
    end

    @spec parse_pointer_types(state()) :: return_n()
    defp parse_pointer_types(state) do
        case next_token(state) do
            {:bracket_open, _, _} -> parse_array_type(state)
            _ -> parse_pointer_type(state)
        end
    end

    @spec parse_array_type(state()) :: return_n()
    defp parse_array_type(state) do
        {_, tok_open, state} = expect_token(state, :bracket_open, "opening bracket")
        {type, state} = parse_type(state)
        {_, tok_close, state} = expect_token(state, :bracket_close, "closing bracket")

        {new_node(:array_type, tok_open.location(),
                  [opening_bracket: tok_open] ++ [closing_bracket: tok_close], [type: type]), state}
    end

    @spec parse_pointer_type(state()) :: return_n()
    defp parse_pointer_type(state) do
        {type, state} = parse_type(state)

        {new_node(:pointer_type, type.location(), [], [type: type]), state}
    end

    @spec parse_return_type(state()) :: return_n()
    defp parse_return_type(state) do
        case next_token(state) do
            {:exclamation, toks, _} ->
                {_, tok_exclam, state} = expect_token(state, :exclamation, "exclamation mark (bottom type)")
                {new_node(:bottom_type, tok_exclam.location(), [exclamation: tok_exclam], []), state}
            _ -> parse_type(state)
        end
    end

    @spec next_token(state(), boolean()) :: {atom(), token(), state()} | :eof
    defp next_token({tokens, loc}, eof // false) do
        case tokens do
            [h | t] ->
                case h.type() do
                    # TODO: Attach comments to AST nodes.
                    a when a in [:line_comment, :block_comment] -> next_token({t, h.location()}, eof)
                    a -> {a, h, {t, h.location()}}
                end
            [] when eof -> :eof
            _ -> raise_error(loc, "Unexpected end of token stream")
        end
    end

    @spec expect_token(state(), atom() | [atom(), ...], String.t(), boolean()) :: {atom(), token(), state()} | :eof
    defp expect_token(state, type, str, eof // false) do
        case next_token(state, eof) do
            tup = {t, tok, {_, l}} ->
                ok = cond do
                    is_list(type) -> Enum.member?(type, t)
                    is_atom(type) -> t == type
                end

                if !ok, do: raise_error(l, "Expected #{str}, but got '#{tok.value()}'")

                tup
            # We only get :eof if eof is true.
            :eof -> :eof
        end
    end

    @spec new_node(atom(), location(), [{atom(), token()}], [{atom(), ast_node()}]) :: ast_node()
    defp new_node(type, loc, tokens, children // []) do
        Flect.Compiler.Syntax.Node[type: type,
                                   location: loc,
                                   tokens: tokens,
                                   children: children]
    end

    @spec raise_error(location(), String.t()) :: no_return()
    defp raise_error(loc, msg) do
        raise(Flect.Compiler.Syntax.SyntaxError[error: msg, location: loc])
    end
end

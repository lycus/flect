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
                                                          :impl, :glob, :tls, :macro], "declaration") do
                    {:fn, _, _} -> parse_fn_decl(state, token)
                    {:struct, _, _} -> parse_struct_decl(state, token)
                    {:union, _, _} -> parse_union_decl(state, token)
                    {:enum, _, _} -> parse_enum_decl(state, token)
                    {:type, _, _} -> parse_type_decl(state, token)
                    {:trait, _, _} -> parse_trait_decl(state, token)
                    {:impl, _, _} -> parse_impl_decl(state, token)
                    {:glob, _, _} -> parse_glob_decl(state, token)
                    {:tls, _, _} -> parse_tls_decl(state, token)
                    {:macro, _, _} -> parse_macro_decl(state, token)
                    {:test, _, _} -> parse_test_decl(state, token)
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

        {ty_par, state} = case next_token(state) do
            {:bracket_open, _, _} ->
                {ty_par, state} = parse_type_parameters(state)
                {[type_parameters: ty_par], state}
            _ -> {[], state}
        end

        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {fields, state} = parse_fields(state)
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        tokens = [visibility_keyword: visibility,
                  struct_keyword: tok_struct,
                  opening_brace: tok_open,
                  closing_brace: tok_close]

        fields = lc field inlist fields, do: {:field, field}

        {new_node(:struct_declaration, tok_struct.location(), tokens, [{:name, name} | ty_par] ++ fields), state}
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

        tokens = [visibility_keyword: visibility,
                  colon: tok_colon,
                  semicolon: tok_semicolon]

        {new_node(:field_declaration, name.location(), tokens, [name: name, type: type]), state}
    end

    @spec parse_union_decl(state(), token()) :: return_n()
    defp parse_union_decl(state, visibility) do
        {_, tok_union, state} = expect_token(state, :union, "union declaration")
        {name, state} = parse_simple_name(state)

        {ty_par, state} = case next_token(state) do
            {:bracket_open, _, _} ->
                {ty_par, state} = parse_type_parameters(state)
                {[type_parameters: ty_par], state}
            _ -> {[], state}
        end

        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {cases, state} = parse_cases(state)
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        tokens = [visibility_keyword: visibility,
                  union_keyword: tok_union,
                  opening_brace: tok_open,
                  closing_brace: tok_close]

        cases = lc c inlist cases, do: {:case, c}

        {new_node(:union_declaration, tok_union.location(), tokens, [{:name, name} | ty_par] ++ cases), state}
    end

    @spec parse_cases(state(), [ast_node()]) :: return_m()
    defp parse_cases(state, cases // []) do
        case next_token(state) do
            {:identifier, _, _} ->
                {c, state} = parse_case(state)
                parse_cases(state, [c | cases])
            _ -> {Enum.reverse(cases), state}
        end
    end

    @spec parse_case(state()) :: return_n()
    defp parse_case(state) do
        {name, state} = parse_simple_name(state)
        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {fields, state} = parse_fields(state)
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        tokens = [opening_brace: tok_open,
                  closing_brace: tok_close]

        fields = lc field inlist fields, do: {:field, field}

        {new_node(:case_declaration, name.location(), tokens, [{:name, name} | fields]), state}
    end

    @spec parse_enum_decl(state(), token()) :: return_n()
    defp parse_enum_decl(state, visibility) do
        {_, tok_enum, state} = expect_token(state, :enum, "enumeration declaration")
        {name, state} = parse_simple_name(state)
        {_, tok_colon, state} = expect_token(state, :colon, "colon")
        {type, state} = parse_nominal_type(state, false)
        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {values, state} = parse_values(state)
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        tokens = [visibility_keyword: visibility,
                  enum_keyword: tok_enum,
                  colon: tok_colon,
                  opening_brace: tok_open,
                  closing_brace: tok_close]

        values = lc value inlist values, do: {:value, value}

        {new_node(:enum_declaration, tok_enum.location(), tokens, [name: name, backing_type: type] ++ values), state}
    end

    @spec parse_values(state(), [ast_node()]) :: return_m()
    defp parse_values(state, values // []) do
        case next_token(state) do
            {:identifier, _, _} ->
                {value, state} = parse_value(state)
                parse_fields(state, [value | values])
            _ -> {Enum.reverse(values), state}
        end
    end

    @spec parse_value(state()) :: return_n()
    defp parse_value(state) do
        {name, state} = parse_simple_name(state)
        {_, tok_equals, state} = expect_token(state, :assign, "equals sign")

        # TODO: Parse expression.

        {_, tok_semicolon, state} = expect_token(state, :semicolon, "semicolon")

        tokens = [equals: tok_equals,
                  semicolon: tok_semicolon]

        {new_node(:field_declaration, name.location(), tokens, [name: name]), state}
    end

    @spec parse_type_decl(state(), token()) :: return_n()
    defp parse_type_decl(state, visibility) do
        {_, tok_type, state} = expect_token(state, :type, "type declaration")
        {name, state} = parse_simple_name(state)

        {ty_par, state} = case next_token(state) do
            {:bracket_open, _, _} ->
                {ty_par, state} = parse_type_parameters(state)
                {[type_parameters: ty_par], state}
            _ -> {[], state}
        end

        {_, tok_eq, state} = expect_token(state, :assign, "equals sign")
        {type, state} = parse_type(state)
        {_, tok_semicolon, state} = expect_token(state, :semicolon, "semicolon")

        tokens = [type_keyword: tok_type,
                  equals: tok_eq,
                  semicolon: tok_semicolon]

        {new_node(:type_declaration, tok_type.location(), tokens, [name: name, type: type] ++ ty_par), state}
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
        {_, tok_glob, state} = expect_token(state, :glob, "global variable declaration")

        {ext, state} = case next_token(state) do
            {:ext, tok, state} ->
                {_, str, state} = expect_token(state, :string, "variable ABI string")
                {[ext_keyword: tok, abi: str], state}
            _ -> {[], state}
        end

        {mut, state} = case next_token(state) do
            {:mut, tok, state} -> {[mut_keyword: tok], state}
            _ -> {[], state}
        end

        {name, state} = parse_simple_name(state)
        {_, tok_colon, state} = expect_token(state, :colon, "colon")
        {type, state} = parse_type(state)
        {_, tok_equals, state} = expect_token(state, :assign, "equals sign")

        # TODO: Parse expression.

        {_, tok_semicolon, state} = expect_token(state, :semicolon, "semicolon")

        tokens = [glob_keyword: tok_glob] ++ ext ++ mut ++ [colon: tok_colon, equals: tok_equals]

        {new_node(:global_declaration, tok_glob.location(), tokens, [name: name, type: type]), state}
    end

    @spec parse_tls_decl(state(), token()) :: return_n()
    defp parse_tls_decl(state, visibility) do
        {_, tok_tls, state} = expect_token(state, :tls, "TLS variable declaration")

        {ext, state} = case next_token(state) do
            {:ext, tok, state} ->
                {_, str, state} = expect_token(state, :string, "variable ABI string")
                {[ext_keyword: tok, abi: str], state}
            _ -> {[], state}
        end

        {mut, state} = case next_token(state) do
            {:mut, tok, state} -> {[mut_keyword: tok], state}
            _ -> {[], state}
        end

        {name, state} = parse_simple_name(state)
        {_, tok_colon, state} = expect_token(state, :colon, "colon")
        {type, state} = parse_type(state)
        {_, tok_equals, state} = expect_token(state, :assign, "equals sign")

        # TODO: Parse expression.

        {_, tok_semicolon, state} = expect_token(state, :semicolon, "semicolon")

        tokens = [tls_keyword: tok_tls] ++ ext ++ mut ++ [colon: tok_colon, equals: tok_equals]

        {new_node(:tls_declaration, tok_tls.location(), tokens, [name: name, type: type]), state}
    end

    @spec parse_macro_decl(state(), token()) :: return_n()
    defp parse_macro_decl(state, visibility) do
        exit(:todo)
    end

    @spec parse_test_decl(state(), token()) :: return_n()
    defp parse_test_decl(state, visibility) do
        {_, tok_test, state} = expect_token(state, :test, "test declaration")
        {_, name_str, state} = expect_token(state, :string, "test name string")

        # TODO: Parse block.

        tokens = [test_keyword: tok_test,
                  test_name: name_str]

        {new_node(:test_declaration, tok_test.location(), tokens, []), state}
    end

    @spec parse_type_parameters(state()) :: return_n()
    defp parse_type_parameters(state) do
        {_, tok_open, state} = expect_token(state, :bracket_open, "opening bracket")
        {params, toks, state} = parse_type_parameter_list(state, [])
        {_, tok_close, state} = expect_token(state, :bracket_close, "closing bracket")

        params = lc param inlist params, do: {:parameter, param}
        toks = lc tok inlist toks, do: {:comma, tok}

        {new_node(:type_parameters, tok_open.location(),
                  [{:opening_bracket, tok_open} | toks] ++ [closing_bracket: tok_close], params), state}
    end

    @spec parse_type_parameter_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_type_parameter_list(state, params, tokens // []) do
        {param, state} = parse_type_parameter(state)

        case next_token(state) do
            {:comma, tok, state} -> parse_type_parameter_list(state, [param | params], [tok | tokens])
            _ -> {Enum.reverse([param | params]), Enum.reverse(tokens), state}
        end
    end

    @spec parse_type_parameter(state()) :: return_n()
    defp parse_type_parameter(state) do
        {name, state} = parse_simple_name(state)

        {bounds, state} = case next_token(state) do
            {:colon, _, _} ->
                {bounds, state} = parse_type_parameter_bounds(state)
                {[bounds: bounds], state}
            _ -> {[], state}
        end

        {new_node(:type_parameter, name.location(), [], [{:name, name} | bounds]), state}
    end

    @spec parse_type_parameter_bounds(state()) :: return_n()
    defp parse_type_parameter_bounds(state) do
        {_, tok_colon, state} = expect_token(state, :colon, "colon")
        {bounds, toks, state} = parse_type_parameter_bounds_list(state, [])

        bounds = lc bound inlist bounds, do: {:bound, bound}
        toks = lc tok inlist toks, do: {:ampersand, tok}

        {new_node(:type_parameter_bounds, tok_colon.location(), [colon: tok_colon] ++ toks, bounds), state}
    end

    @spec parse_type_parameter_bounds_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_type_parameter_bounds_list(state, bounds, tokens // []) do
        {bound, state} = parse_nominal_type(state)

        case next_token(state) do
            {:ampersand, tok, state} -> parse_type_parameter_bounds_list(state, [bound | bounds], [tok | tokens])
            _ -> {Enum.reverse([bound | bounds]), Enum.reverse(tokens), state}
        end
    end

    @spec parse_type(state()) :: return_n()
    defp parse_type(state) do
        case expect_token(state, [:identifier, :paren_open, :fn, :brace_open,
                                  :at, :star, :ampersand], "type signature") do
            {:identifier, _, _} -> parse_nominal_type(state)
            {:paren_open, _, _} -> parse_tuple_type(state)
            {:fn, _, _} -> parse_function_type(state)
            {:brace_open, _, _} -> parse_vector_type(state)
            _ -> parse_pointer_type(state)
        end
    end

    @spec parse_nominal_type(state(), boolean()) :: return_n()
    defp parse_nominal_type(state, generic // true) do
        {name, state} = parse_qualified_name(state)

        {ty_args, state} = case next_token(state) do
            {:bracket_open, _, _} when generic ->
                {ty_args, state} = parse_type_arguments(state)
                {[arguments: ty_args], state}
            _ -> {[], state}
        end

        {new_node(:nominal_type, name.location(), [], [{:name, name} | ty_args]), state}
    end

    @spec parse_type_arguments(state()) :: return_n()
    defp parse_type_arguments(state) do
        {_, tok_open, state} = expect_token(state, :bracket_open, "opening bracket")
        {types, toks, state} = parse_type_list(state, [])
        {_, tok_close, state} = expect_token(state, :bracket_close, "closing bracket")

        types = lc type inlist types, do: {:argument, type}
        toks = lc tok inlist toks, do: {:comma, tok}

        {new_node(:type_arguments, tok_open.location(),
                  [{:opening_bracket, tok_open} | toks] ++ [closing_bracket: tok_close], types), state}
    end

    @spec parse_type_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_type_list(state, types, tokens // []) do
        {type, state} = parse_type(state)

        case next_token(state) do
            {:comma, tok, state} -> parse_type_list(state, [type | types], [tok | tokens])
            _ -> {Enum.reverse([type | types]), Enum.reverse(tokens), state}
        end
    end

    @spec parse_tuple_type(state()) :: return_n()
    defp parse_tuple_type(state) do
        {_, tok_open, state} = expect_token(state, :paren_open, "opening parenthesis")
        {type, state} = parse_type(state)
        {_, comma, state} = expect_token(state, :comma, "comma")
        {types, toks, state} = parse_type_list(state, [])
        {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")

        types = lc typ inlist [type | types], do: {:element, typ}
        toks = lc tok inlist [comma | toks], do: {:comma, tok}

        {new_node(:tuple_type, tok_open.location(),
                  [{:opening_parenthesis, tok_open} | toks] ++ [closing_parenthesis: tok_close], types), state}
    end

    @spec parse_function_type(state()) :: return_n()
    defp parse_function_type(state) do
        {_, fn_tok, state} = expect_token(state, :fn, "'fn' keyword")

        case expect_token(state, [:at, :paren_open, :ext], "function type parameter list") do
            {:at, _, _} -> parse_closure_pointer_type(state, fn_tok)
            _ -> parse_function_pointer_type(state, fn_tok)
        end
    end

    @spec parse_function_pointer_type(state(), token()) :: return_n()
    defp parse_function_pointer_type(state, fn_kw) do
        {ext_abi, state} = case next_token(state) do
            {:ext, ext, state} ->
                case expect_token(state, :string, "function ABI string") do
                    {_, abi, state} -> {[ext_keyword: ext, abi: abi], state}
                end
            _ -> {[], state}
        end

        {params, state} = parse_function_type_parameters(state)
        {_, tok_arrow, state} = expect_token(state, :minus_angle_close, "return type arrow")
        {return_type, state} = parse_return_type(state)

        {new_node(:function_pointer_type, fn_kw.location(),
                  [fn_keyword: fn_kw] ++ ext_abi ++ [arrow: tok_arrow], [parameters: params, return_type: return_type]), state}
    end

    @spec parse_closure_pointer_type(state(), token()) :: return_n()
    defp parse_closure_pointer_type(state, fn_kw) do
        {_, tok_closure, state} = expect_token(state, :at, "'@' symbol")
        {params, state} = parse_function_type_parameters(state)
        {_, tok_arrow, state} = expect_token(state, :minus_angle_close, "return type arrow")
        {return_type, state} = parse_return_type(state)

        {new_node(:closure_pointer_type, fn_kw.location(),
                  [fn_keyword: fn_kw, at: tok_closure, arrow: tok_arrow], [parameters: params, return_type: return_type]), state}
    end

    @spec parse_function_type_parameters(state()) :: return_n()
    defp parse_function_type_parameters(state) do
        {_, tok_open, state} = expect_token(state, :paren_open, "opening parenthesis")
        {type_params, toks, state} = parse_function_type_parameter_list(state, [])
        {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")

        types = lc type inlist type_params, do: {:parameter, type}
        toks = lc tok inlist toks, do: {:comma, tok}

        {new_node(:function_type_parameters, tok_open.location(),
                  [{:opening_parenthesis, tok_open} | toks] ++ [closing_parenthesis: tok_close], types), state}
    end

    @spec parse_function_type_parameter_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_function_type_parameter_list(state, params, tokens // []) do
        case next_token(state) do
            {:paren_close, _, _} -> {Enum.reverse(params), Enum.reverse(tokens), state}
            {:comma, tok, state} when params != [] ->
                {param, state} = parse_function_type_parameter(state)
                parse_function_type_parameter_list(state, [param | params], [tok | tokens])
            _ when params == [] ->
                {param, state} = parse_function_type_parameter(state)
                parse_function_type_parameter_list(state, [param | params], tokens)
        end
    end

    @spec parse_function_type_parameter(state()) :: return_n()
    defp parse_function_type_parameter(state) do
        {mut, state} = case next_token(state) do
            {:mut, mut, state} -> {[mut_keyword: mut], state}
            _ -> {[], state}
        end

        {ref, state} = case next_token(state) do
            {:ref, ref, state} -> {[ref_keyword: ref], state}
            _ -> {[], state}
        end

        {type, state} = parse_type(state)

        {new_node(:function_type_parameter, type.location(), mut ++ ref, [type: type]), state}
    end

    @spec parse_return_type(state()) :: return_n()
    defp parse_return_type(state) do
        case next_token(state) do
            {:exclamation, tok_exclam, state} -> {new_node(:bottom_type, tok_exclam.location(), [exclamation: tok_exclam], []), state}
            _ -> parse_type(state)
        end
    end

    @spec parse_vector_type(state()) :: return_n()
    defp parse_vector_type(state) do
        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {type, state} = parse_type(state)
        {_, tok_period_period, state} = expect_token(state, :period_period, "type/size-separating ellipsis")
        {_, tok_int, state} = expect_token(state, :integer, "vector size integer")
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        {new_node(:vector_type, tok_open.location(),
                  [opening_brace: tok_open, ellipsis: tok_period_period, size: tok_int, closing_brace: tok_close], [element: type]), state}
    end

    @spec parse_pointer_type(state()) :: return_n()
    defp parse_pointer_type(state) do
        {p_type, tok, state} = case expect_token(state, [:at, :star, :ampersand], "'@', '*', or '&'") do
            {:at, tok, state} -> {:managed_pointer_type, [at: tok], state}
            {:star, tok, state} -> {:unsafe_pointer_type, [star: tok], state}
            {:ampersand, tok, state} -> {:general_pointer_type, [ampersand: tok], state}
        end

        {mut_imm, state} = case next_token(state) do
            {:mut, mut, state} -> {[mut_keyword: mut], state}
            {:imm, imm, state} -> {[imm_keyword: imm], state}
            _ -> {[], state}
        end

        loc = elem(Enum.fetch!(tok, 0), 1).location()

        case next_token(state) do
            {:bracket_open, _, _} ->
                a_type = case p_type do
                    :managed_pointer_type -> :managed_array_type
                    :unsafe_pointer_type -> :unsafe_array_type
                    :general_pointer_type -> :general_array_type
                end

                {_, tok_open, state} = expect_token(state, :bracket_open, "opening bracket")
                {type, state} = parse_type(state)
                {_, tok_close, state} = expect_token(state, :bracket_close, "closing bracket")

                {new_node(a_type, loc, tok ++ mut_imm ++ [opening_bracket: tok_open, closing_bracket: tok_close], [element: type]), state}
            _ ->
                {type, state} = parse_type(state)

                {new_node(p_type, loc, tok ++ mut_imm, [pointee: type]), state}
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

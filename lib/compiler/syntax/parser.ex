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
    resulting list or throws a `Flect.Compiler.Syntax.SyntaxError` if the
    source code is malformed.

    `tokens` must be a list of `Flect.Compiler.Syntax.Token`s. `file` must
    be a binary containing the file name (used to report syntax errors).
    """
    @spec parse_modules([Flect.Compiler.Syntax.Token.t()], String.t()) :: [Flect.Compiler.Syntax.Node.t()]
    def parse_modules(tokens, file) do
        loc = if t = Enum.first(tokens), do: t.location(), else: Flect.Compiler.Syntax.Location[file: file]
        do_parse_modules({tokens, loc})
    end

    @spec do_parse_modules(state(), [ast_node()]) :: [ast_node()]
    defp do_parse_modules(state, mods // []) do
        case expect_token(state, [:pub, :priv], "module declaration", true) do
            :eof -> Enum.reverse(mods)
            {_, token, state} ->
                {mod, state} = parse_mod(state, token)
                do_parse_modules(state, [mod | mods])
        end
    end

    @doc """
    Parses the given list of tokens into a list of
    `Flect.Compiler.Syntax.Node`s representing each semicolon-terminated
    expression in the input. Returns the resulting list or throws a
    `Flect.Compiler.Syntax.SyntaxError` if the source code is malformed.

    `tokens` must be a list of `Flect.Compiler.Syntax.Token`s. `file` must
    be a binary containing the file name (used to report syntax errors).
    """
    @spec parse_expressions([Flect.Compiler.Syntax.Token.t()], String.t()) :: [Flect.Compiler.Syntax.Node.t()]
    def parse_expressions(tokens, file) do
        loc = if t = Enum.first(tokens), do: t.location(), else: Flect.Compiler.Syntax.Location[file: file]
        do_parse_expressions({tokens, loc})
    end

    @spec do_parse_expressions(state(), [ast_node()]) :: [ast_node()]
    defp do_parse_expressions(state, exprs // []) do
        case next_token(state, true) do
            :eof -> Enum.reverse(exprs)
            {:semicolon, _, state} -> do_parse_expressions(state, exprs)
            _ ->
                {expr, state} = parse_expr(state)
                {_, _, state} = expect_token(state, :semicolon, "expression-terminating semicolon")
                do_parse_expressions(state, [expr | exprs])
        end
    end

    @spec parse_simple_name(state()) :: return_n()
    defp parse_simple_name(state) do
        {_, tok, state} = expect_token(state, :identifier, "identifier")
        {new_node(:simple_name, tok.location(), [name: tok]), state}
    end

    @spec parse_qualified_name(state(), boolean()) :: return_n()
    defp parse_qualified_name(state, global // true) do
        {tcol, loc, state} = case next_token(state) do
            {:colon_colon, tok, state} when global -> {[separator: tok], tok.location(), state}
            _ -> {[], nil, state}
        end

        {names, toks, state} = parse_qualified_name_list(state, [])

        if !loc, do: loc = hd(names).location()

        names = lc name inlist names, do: {:name, name}
        toks = lc tok inlist toks, do: {:separator, tok}

        {new_node(:qualified_name, loc, tcol ++ toks, names), state}
    end

    @spec parse_qualified_name_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_qualified_name_list(state, names, tokens // []) do
        {name, state} = parse_simple_name(state)

        case next_token(state) do
            {:colon_colon, tok, state} -> parse_qualified_name_list(state, [name | names], [tok | tokens])
            _ -> {Enum.reverse([name | names]), Enum.reverse(tokens), state}
        end
    end

    @spec parse_mod(state(), token()) :: return_n()
    defp parse_mod(state, visibility) do
        {_, tok_mod, state} = expect_token(state, :mod, "'mod' keyword")
        {name, state} = parse_qualified_name(state, false)
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
            {v, _, _} when v in [:use, :test] ->
                {decl, state} = case v do
                    :use -> parse_use_decl(state)
                    :test -> parse_test_decl(state)
                end

                parse_decls(state, [{:declaration, decl} | decls])
            {v, token, state} when v in [:pub, :priv] ->
                {decl, state} = case expect_token(state, [:fn, :struct, :union, :enum, :trait,
                                                          :impl, :glob, :tls, :macro, :at], "declaration") do
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
                    {:at, _, _} -> parse_attribute(state, token)
                end

                parse_decls(state, [{:declaration, decl} | decls])
            _ -> {Enum.reverse(decls), state}
        end
    end

    @spec parse_use_decl(state()) :: return_n()
    defp parse_use_decl(state) do
        {_, tok_use, state} = expect_token(state, :use, "use declaration")

        {ext, state} = case next_token(state) do
            {:ext, tok, state} -> {[ext_keyword: tok], state}
            _ -> {[], state}
        end

        {name, state} = parse_qualified_name(state, false)
        {_, tok_semi, state} = expect_token(state, :semicolon, "semicolon")

        {new_node(:use_declaration, tok_use.location(),
                  [{:use_keyword, tok_use} | ext] ++ [semicolon: tok_semi], [name: name]), state}
    end

    @spec parse_fn_decl(state(), token() | nil, boolean()) :: return_n()
    defp parse_fn_decl(state, visibility, body // true) do
        {_, tok_fn, state} = expect_token(state, :fn, "function declaration")

        {ext, state} = case next_token(state) do
            {:ext, tok, state} ->
                {_, str, state} = expect_token(state, :string, "function ABI string")
                {[ext_keyword: tok, abi: str], state}
            _ -> {[], state}
        end

        {name, state} = parse_simple_name(state)

        {ty_par, state} = case next_token(state) do
            {:bracket_open, _, _} ->
                {ty_par, state} = parse_type_parameters(state)
                {[type_parameters: ty_par], state}
            _ -> {[], state}
        end

        {params, state} = parse_function_parameters(state)
        {_, tok_arrow, state} = expect_token(state, :minus_angle_close, "return type arrow")
        {ret_type, state} = parse_return_type(state)

        {tail_tok, tail_node, state} = if body do
            {block, state} = parse_block(state)
            {[], [body: block], state}
        else
            {_, tok_semicolon, state} = expect_token(state, :semicolon, "semicolon")
            {[semicolon: tok_semicolon], [], state}
        end

        vis = if visibility, do: [visibility_keyword: visibility], else: []
        tokens = vis ++ [fn_keyword: tok_fn] ++ ext ++ [arrow: tok_arrow] ++ tail_tok

        {new_node(:function_declaration, tok_fn.location(), tokens,
                  [{:name, name} | ty_par] ++ [parameters: params, return_type: ret_type] ++ tail_node), state}
    end

    @spec parse_function_parameters(state()) :: return_n()
    defp parse_function_parameters(state) do
        {_, tok_open, state} = expect_token(state, :paren_open, "opening parenthesis")
        {params, toks, state} = parse_function_parameter_list(state, [])
        {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")

        params = lc param inlist params, do: {:parameter, param}
        toks = lc tok inlist toks, do: {:comma, tok}

        {new_node(:function_parameters, tok_open.location(),
                  [{:opening_parenthesis, tok_open} | toks] ++ [closing_parenthesis: tok_close], params), state}
    end

    @spec parse_function_parameter_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_function_parameter_list(state, params, tokens // []) do
        case next_token(state) do
            {:paren_close, _, _} -> {Enum.reverse(params), Enum.reverse(tokens), state}
            _ ->
                if params == [] do
                    {param, state} = parse_function_parameter(state)
                    parse_function_parameter_list(state, [param | params], tokens)
                else
                    {_, tok, state} = expect_token(state, :comma, "comma")
                    {param, state} = parse_function_parameter(state)
                    parse_function_parameter_list(state, [param | params], [tok | tokens])
                end
        end
    end

    @spec parse_function_parameter(state()) :: return_n()
    defp parse_function_parameter(state) do
        {mut, state} = case next_token(state) do
            {:mut, mut, state} -> {[mut_keyword: mut], state}
            _ -> {[], state}
        end

        {ref, state} = case next_token(state) do
            {:ref, ref, state} -> {[ref_keyword: ref], state}
            _ -> {[], state}
        end

        {name, state} = parse_simple_name(state)
        {_, tok_colon, state} = expect_token(state, :colon, "colon")
        {type, state} = parse_type(state)

        {new_node(:function_parameter, type.location(), mut ++ ref ++ [colon: tok_colon], [name: name, type: type]), state}
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
        {expr, state} = parse_expr(state)
        {_, tok_semicolon, state} = expect_token(state, :semicolon, "semicolon")

        tokens = [equals: tok_equals,
                  semicolon: tok_semicolon]

        {new_node(:field_declaration, name.location(), tokens, [name: name, value: expr]), state}
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

        tokens = [visibility_keyword: visibility,
                  type_keyword: tok_type,
                  equals: tok_eq,
                  semicolon: tok_semicolon]

        {new_node(:type_declaration, tok_type.location(), tokens, [name: name, type: type] ++ ty_par), state}
    end

    @spec parse_trait_decl(state(), token()) :: return_n()
    defp parse_trait_decl(state, visibility) do
        {_, tok_trait, state} = expect_token(state, :trait, "trait declaration")
        {name, state} = parse_simple_name(state)

        {ty_par, state} = case next_token(state) do
            {:bracket_open, _, _} ->
                {ty_par, state} = parse_type_parameters(state)
                {[type_parameters: ty_par], state}
            _ -> {[], state}
        end

        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {fns, state} = parse_trait_functions(state)
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        tokens = [visibility_keyword: visibility,
                  trait_keyword: tok_trait,
                  opening_brace: tok_open,
                  closing_brace: tok_close]

        fns = lc fun inlist fns, do: {:function, fun}

        {new_node(:trait_declaration, tok_trait.location(), tokens, [{:name, name} | ty_par ++ fns]), state}
    end

    @spec parse_trait_functions(state(), [ast_node()]) :: return_m()
    defp parse_trait_functions(state, fns // []) do
        case next_token(state) do
            {:fn, _, _} ->
                {fun, state} = parse_fn_decl(state, nil, false)
                parse_trait_functions(state, [fun | fns])
            _ -> {Enum.reverse(fns), state}
        end
    end

    @spec parse_impl_decl(state(), token()) :: return_n()
    defp parse_impl_decl(state, visibility) do
        {_, tok_impl, state} = expect_token(state, :impl, "implementation declaration")

        {ty_par, state} = case next_token(state) do
            {:bracket_open, _, _} ->
                {ty_par, state} = parse_type_parameters(state)
                {[type_parameters: ty_par], state}
            _ -> {[], state}
        end

        {trait, state} = parse_nominal_type(state)
        {_, tok_for, state} = expect_token(state, :for, "'for' keyword")
        {type, state} = parse_type(state)
        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {fns, state} = parse_impl_functions(state)
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        tokens = [visibility_keyword: visibility,
                  impl_keyword: tok_impl,
                  for_keyword: tok_for,
                  opening_brace: tok_open,
                  closing_brace: tok_close]

        fns = lc fun inlist fns, do: {:function, fun}

        {new_node(:impl_declaration, tok_impl.location(), tokens, ty_par ++ [trait: trait, type: type] ++ fns), state}
    end

    @spec parse_impl_functions(state(), [ast_node()]) :: return_m()
    defp parse_impl_functions(state, fns // []) do
        case next_token(state) do
            {:fn, _, _} ->
                {fun, state} = parse_fn_decl(state, nil)
                parse_impl_functions(state, [fun | fns])
            _ -> {Enum.reverse(fns), state}
        end
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

        {expr, tok_eq, state} = case next_token(state) do
            {:assign, tok, state} ->
                {expr, state} = parse_expr(state)
                {[initializer: expr], [equals: tok], state}
            _ -> {[], [], state}
        end

        {_, tok_semicolon, state} = expect_token(state, :semicolon, "semicolon")

        tokens = [visibility_keyword: visibility, glob_keyword: tok_glob] ++ ext ++ mut
        tokens = tokens ++ [colon: tok_colon] ++ tok_eq ++ [semicolon: tok_semicolon]

        {new_node(:global_declaration, tok_glob.location(), tokens, [{:name, name}, {:type, type} | expr]), state}
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

        {expr, tok_eq, state} = case next_token(state) do
            {:assign, tok, state} ->
                {expr, state} = parse_expr(state)
                {[initializer: expr], [equals: tok], state}
            _ -> {[], [], state}
        end

        {_, tok_semicolon, state} = expect_token(state, :semicolon, "semicolon")

        tokens = [visibility_keyword: visibility, tls_keyword: tok_tls] ++ ext ++ mut
        tokens = tokens ++ [colon: tok_colon] ++ tok_eq ++ [semicolon: tok_semicolon]

        {new_node(:tls_declaration, tok_tls.location(), tokens, [{:name, name}, {:type, type} | expr]), state}
    end

    @spec parse_macro_decl(state(), token()) :: return_n()
    defp parse_macro_decl(state, visibility) do
        {_, tok_macro, state} = expect_token(state, :macro, "macro declaration")
        {name, state} = parse_simple_name(state)
        {params, state} = parse_macro_parameters(state)
        {block, state} = parse_block(state)

        tokens = [visibility_keyword: visibility,
                  macro_keyword: tok_macro]

        {new_node(:macro_declaration, tok_macro.location(), tokens, [name: name, parameters: params, body: block]), state}
    end

    @spec parse_macro_parameters(state()) :: return_n()
    defp parse_macro_parameters(state) do
        {_, tok_open, state} = expect_token(state, :paren_open, "opening parenthesis")
        {params, toks, state} = parse_macro_parameter_list(state, [])
        {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")

        params = lc param inlist params, do: {:parameter, param}
        toks = lc tok inlist toks, do: {:comma, tok}

        {new_node(:macro_parameters, tok_open.location(),
                  [{:opening_parenthesis, tok_open} | toks] ++ [closing_parenthesis: tok_close], params), state}
    end

    @spec parse_macro_parameter_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_macro_parameter_list(state, params, tokens // []) do
        case next_token(state) do
            {:paren_close, _, _} -> {Enum.reverse(params), Enum.reverse(tokens), state}
            _ ->
                if params == [] do
                    {param, state} = parse_simple_name(state)
                    parse_macro_parameter_list(state, [param | params], tokens)
                else
                    {_, tok, state} = expect_token(state, :comma, "comma")
                    {param, state} = parse_simple_name(state)
                    parse_macro_parameter_list(state, [param | params], [tok | tokens])
                end
        end
    end

    @spec parse_test_decl(state()) :: return_n()
    defp parse_test_decl(state) do
        {_, tok_test, state} = expect_token(state, :test, "test declaration")
        {_, name_str, state} = expect_token(state, :string, "test name string")
        {block, state} = parse_block(state)

        tokens = [test_keyword: tok_test,
                  test_name: name_str]

        {new_node(:test_declaration, tok_test.location(), tokens, [body: block]), state}
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
        case expect_token(state, [:identifier, :paren_open, :fn, :bracket_open,
                                  :at, :star, :ampersand], "type signature") do
            {:identifier, _, _} -> parse_nominal_type(state)
            {:paren_open, _, _} -> parse_tuple_type(state)
            {:fn, _, _} -> parse_function_type(state)
            {:bracket_open, _, _} -> parse_vector_type(state)
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
            _ ->
                if params == [] do
                    {param, state} = parse_function_type_parameter(state)
                    parse_function_type_parameter_list(state, [param | params], tokens)
                else
                    {_, tok, state} = expect_token(state, :comma, "comma")
                    {param, state} = parse_function_type_parameter(state)
                    parse_function_type_parameter_list(state, [param | params], [tok | tokens])
                end
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

    @spec parse_vector_type(state(), boolean()) :: return_n()
    defp parse_vector_type(state, array // false) do
        {_, tok_open, state} = expect_token(state, :bracket_open, "opening bracket")
        {type, state} = parse_type(state)

        {a_type, etok, state} = case next_token(state) do
            {:period_period, etok, state} ->
                {_, tok_int, state} = expect_token(state, :integer, "vector size integer")
                {:vector_type, [ellipsis: etok, size: tok_int], state}
            {_, tok, _} ->
                if !array do
                    val = if String.printable?(tok.value()), do: tok.value(), else: "<non-printable token>"
                    raise_error(tok.location(), "Expected type/size-separating ellipsis, but found: #{val}")
                end

                {:array_type, [], state}
        end

        {_, tok_close, state} = expect_token(state, :bracket_close, "closing bracket")

        tokens = [{:opening_bracket, tok_open} | etok] ++ [closing_bracket: tok_close]

        {new_node(a_type, tok_open.location(), tokens, [element: type]), state}
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

        {type, state} = case next_token(state) do
            # Kick of a hack, but it works.
            {:bracket_open, _, _} -> parse_vector_type(state, true)
            _ -> parse_type(state)
        end

        loc = elem(hd(tok), 1).location()

        {new_node(p_type, loc, tok ++ mut_imm, [pointee: type]), state}
    end

    @spec parse_expr(state()) :: return_n()
    defp parse_expr(state) do
        parse_assign_expr(state)
    end

    @spec parse_assign_expr(state) :: return_n()
    defp parse_assign_expr(state) do
        tup = {expr1, state} = parse_cast_expr(state)

        case next_token(state) do
            {:assign, tok, state} ->
                {expr2, state} = parse_assign_expr(state)
                {new_node(:assign_expr, tok.location(), [operator: tok], [lhs: expr1, rhs: expr2]), state}
            _ -> tup
        end
    end

    @spec parse_cast_expr(state()) :: return_n()
    defp parse_cast_expr(state) do
        tup = {expr, state} = parse_logical_or_expr(state)

        case next_token(state) do
            {:as, tok, state} ->
                {type, state} = parse_type(state)
                {new_node(:cast_expr, tok.location(), [as_keyword: tok], [lhs: expr, rhs: type]), state}
            _ -> tup
        end
    end

    @spec parse_logical_or_expr(state) :: return_n()
    defp parse_logical_or_expr(state) do
        tup = {expr1, state} = parse_logical_and_expr(state)

        case next_token(state) do
            {:pipe_pipe, tok, state} ->
                {expr2, state} = parse_logical_and_expr(state)
                {new_node(:logical_or_expr, tok.location(), [operator: tok], [lhs: expr1, rhs: expr2]), state}
            _ -> tup
        end
    end

    @spec parse_logical_and_expr(state()) :: return_n()
    defp parse_logical_and_expr(state) do
        tup = {expr1, state} = parse_bitwise_or_expr(state)

        case next_token(state) do
            {:ampersand_ampersand, tok, state} ->
                {expr2, state} = parse_bitwise_or_expr(state)
                {new_node(:logical_and_expr, tok.location(), [operator: tok], [lhs: expr1, rhs: expr2]), state}
            _ -> tup
        end
    end

    @spec parse_bitwise_or_expr(state()) :: return_n()
    defp parse_bitwise_or_expr(state) do
        tup = {expr1, state} = parse_bitwise_xor_expr(state)

        case next_token(state) do
            {:pipe, tok, state} ->
                {expr2, state} = parse_bitwise_xor_expr(state)
                {new_node(:bitwise_or_expr, tok.location(), [operator: tok], [lhs: expr1, rhs: expr2]), state}
            _ -> tup
        end
    end

    @spec parse_bitwise_xor_expr(state()) :: return_n()
    defp parse_bitwise_xor_expr(state) do
        tup = {expr1, state} = parse_bitwise_and_expr(state)

        case next_token(state) do
            {:caret, tok, state} ->
                {expr2, state} = parse_bitwise_and_expr(state)
                {new_node(:bitwise_xor_expr, tok.location(), [operator: tok], [lhs: expr1, rhs: expr2]), state}
            _ -> tup
        end
    end

    @spec parse_bitwise_and_expr(state()) :: return_n()
    defp parse_bitwise_and_expr(state) do
        tup = {expr1, state} = parse_relational_expr(state)

        case next_token(state) do
            {:ampersand, tok, state} ->
                {expr2, state} = parse_relational_expr(state)
                {new_node(:bitwise_and_expr, tok.location(), [operator: tok], [lhs: expr1, rhs: expr2]), state}
            _ -> tup
        end
    end

    @spec parse_relational_expr(state()) :: return_n()
    defp parse_relational_expr(state) do
        tup = {expr1, state} = parse_pipeline_expr(state)

        case next_token(state) do
            {type, tok, state} when type in [:assign_assign,
                                             :assign_assign_assign,
                                             :exclamation_assign,
                                             :exclamation_assign_assign,
                                             :angle_open,
                                             :angle_open_assign,
                                             :angle_close,
                                             :angle_close_assign] ->
                {expr2, state} = parse_shift_expr(state)

                ast_type = case type do
                    :assign_assign -> :relational_equal_expr
                    :assign_assign_assign -> :relational_identical_expr
                    :exclamation_assign -> :relational_not_equal_expr
                    :exclamation_assign_assign -> :relational_not_identical_expr
                    :angle_open -> :relational_greater_expr
                    :angle_open_assign -> :relational_greater_equal_expr
                    :angle_close -> :relational_lower_expr
                    :angle_close_assign -> :relational_lower_equal_expr
                end

                {new_node(ast_type, tok.location(), [operator: tok], [lhs: expr1, rhs: expr2]), state}
            _ -> tup
        end
    end

    @spec parse_pipeline_expr(state()) :: return_n()
    defp parse_pipeline_expr(state) do
        tup = {expr1, state} = parse_shift_expr(state)

        case next_token(state) do
            {type, tok, state} when type in [:angle_open_pipe, :pipe_angle_close] ->
                {expr2, state} = parse_shift_expr(state)

                ast_type = case type do
                    :angle_open_pipe -> :left_pipeline_expr
                    :pipe_angle_close -> :right_pipeline_expr
                end

                {new_node(ast_type, tok.location(), [operator: tok], [lhs: expr1, rhs: expr2]), state}
            _ -> tup
        end
    end

    @spec parse_shift_expr(state()) :: return_n()
    defp parse_shift_expr(state) do
        tup = {expr1, state} = parse_additive_expr(state)

        case next_token(state) do
            {type, tok, state} when type in [:angle_open_angle_open, :angle_close_angle_close] ->
                {expr2, state} = parse_additive_expr(state)

                ast_type = case type do
                    :angle_open_angle_open -> :left_shift_expr
                    :angle_close_angle_close -> :right_shift_expr
                end

                {new_node(ast_type, tok.location(), [operator: tok], [lhs: expr1, rhs: expr2]), state}
            _ -> tup
        end
    end

    @spec parse_additive_expr(state()) :: return_n()
    defp parse_additive_expr(state) do
        tup = {expr1, state} = parse_multiplicative_expr(state)

        case next_token(state) do
            {type, tok, state} when type in [:plus, :minus] ->
                {expr2, state} = parse_multiplicative_expr(state)

                ast_type = case type do
                    :plus -> :add_expr
                    :minus -> :subtract_expr
                end

                {new_node(ast_type, tok.location(), [operator: tok], [lhs: expr1, rhs: expr2]), state}
            _ -> tup
        end
    end

    @spec parse_multiplicative_expr(state()) :: return_n()
    defp parse_multiplicative_expr(state) do
        tup = {expr1, state} = parse_unary_expr(state)

        case next_token(state) do
            {type, tok, state} when type in [:star, :slash, :percent] ->
                {expr2, state} = parse_unary_expr(state)

                ast_type = case type do
                    :star -> :multiply_expr
                    :slash -> :divide_expr
                    :percent -> :remainder_expr
                end

                {new_node(ast_type, tok.location(), [operator: tok], [lhs: expr1, rhs: expr2]), state}
            _ -> tup
        end
    end

    @spec parse_unary_expr(state()) :: return_n()
    defp parse_unary_expr(state) do
        case next_token(state) do
            {type, tok, state} when type in [:star,
                                             :plus,
                                             :minus,
                                             :exclamation,
                                             :tilde] ->
                {expr, state} = parse_unary_expr(state)

                ast_type = case type do
                    :star -> :dereference_expr
                    :plus -> :plus_expr
                    :minus -> :negate_expr
                    :exclamation -> :logical_not_expr
                    :tilde -> :complement_expr
                end

                {new_node(ast_type, tok.location(), [operator: tok], [operand: expr]), state}
            {:at, tok, state} ->
                {mut_imm, state} = case next_token(state) do
                    {:mut, mut, state} -> {[mut_keyword: mut], state}
                    {:imm, imm, state} -> {[imm_keyword: imm], state}
                    _ -> {[], state}
                end

                {expr, state} = case next_token(state) do
                    # Kick of a hack, but it works.
                    {:bracket_open, _, _} -> parse_vector_expr(state, true)
                    _ -> parse_unary_expr(state)
                end

                {new_node(:box_expr, tok.location(), [operator: tok] ++ mut_imm, [operand: expr]), state}
            {:ampersand, tok, state} ->
                {imm, state} = case next_token(state) do
                    {:imm, tok, state} -> {[imm_keyword: tok], state}
                    _ -> {[], state}
                end

                {expr, state} = parse_unary_expr(state)

                {new_node(:address_expr, tok.location(), [operator: tok] ++ imm, [operand: expr]), state}
            {:ampersand_ampersand, tok, state} ->
                {ident, state} = parse_simple_name(state)
                {new_node(:label_address_expr, tok.location(), [operator: tok], [operand: ident]), state}
            {:paren_open, _, _} ->
                {expr, state} = parse_parenthesized_expr(state)
                parse_post_expr(state, expr)
            _ ->
                {expr, state} = parse_primary_expr(state)
                parse_post_expr(state, expr)
        end
    end

    @spec parse_parenthesized_expr(state()) :: return_n()
    defp parse_parenthesized_expr(state) do
        {_, tok_open, state} = expect_token(state, :paren_open, "opening parenthesis")

        case next_token(state) do
            # It's a unit literal, i.e. ().
            {:paren_close, tok, state} -> {new_node(:unit_expr, tok_open.location(),
                                                    [opening_parenthesis: tok_open,
                                                     closing_parenthesis: tok], []), state}
            _ ->
                {expr, state} = parse_expr(state)

                case next_token(state) do
                    # It's a tuple, i.e. (e1, ...).
                    {:comma, tok, state} -> parse_tuple_expr(state, expr, tok_open, tok)
                    # It's a simple parenthesized expression, i.e. (e).
                    _ ->
                        {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")
                        {new_node(:parenthesized_expr, tok_open.location(),
                                  [opening_parenthesis: tok_open, closing_parenthesis: tok_close], [expression: expr]), state}
                end
        end
    end

    @spec parse_tuple_expr(state(), ast_node(), token(), token()) :: return_n()
    defp parse_tuple_expr(state, first, paren, comma) do
        {exprs, toks, state} = parse_tuple_expr_list(state, [])
        {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")

        exprs = lc expr inlist [first | exprs], do: {:element, expr}
        toks = lc tok inlist [comma | toks], do: {:comma, tok}

        {new_node(:tuple_expr, paren.location(),
                  [{:opening_parenthesis, paren} | toks] ++ [closing_parenthesis: tok_close], exprs), state}
    end

    @spec parse_tuple_expr_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_tuple_expr_list(state, exprs, tokens // []) do
        {expr, state} = parse_expr(state)

        case next_token(state) do
            {:comma, tok, state} -> parse_tuple_expr_list(state, [expr | exprs], [tok | tokens])
            _ -> {Enum.reverse([expr | exprs]), Enum.reverse(tokens), state}
        end
    end

    @spec parse_post_expr(state(), ast_node()) :: return_n()
    defp parse_post_expr(state, expr) do
        case next_token(state) do
            {:period, tok, state} ->
                {name, state} = parse_simple_name(state)

                parse_post_expr(state, new_node(:field_expr, tok.location(), [operator: tok], [lhs: expr, rhs: name]))
            {:arrow, tok, state} ->
                {name, state} = parse_simple_name(state)

                parse_post_expr(state, new_node(:method_expr, tok.location(), [operator: tok], [lhs: expr, rhs: name]))
            {:exclamation, tok_excl, state} ->
                {_, tok_open, state} = expect_token(state, :paren_open, "opening_parenthesis")
                {args, toks, state} = parse_call_argument_list(state, [])
                {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")

                args = lc arg inlist args, do: {:argument, arg}
                toks = lc tok inlist toks, do: {:comma, tok}

                tokens = [{:exclamation, tok_excl}, {:opening_parenthesis, tok_open} | toks] ++ [closing_parenthesis: tok_close]

                parse_post_expr(state, new_node(:macro_call_expr, tok_open.location(), tokens, args))
            {:paren_open, tok_open, state} ->
                {args, toks, state} = parse_call_argument_list(state, [])
                {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")

                args = lc arg inlist args, do: {:argument, arg}
                toks = lc tok inlist toks, do: {:comma, tok}

                tokens = [{:opening_parenthesis, tok_open} | toks] ++ [closing_parenthesis: tok_close]

                parse_post_expr(state, new_node(:call_expr, tok_open.location(), tokens, args))
            _ -> {expr, state}
        end
    end

    @spec parse_call_argument_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_call_argument_list(state, args, tokens // []) do
        case next_token(state) do
            {:paren_close, _, _} -> {Enum.reverse(args), Enum.reverse(tokens), state}
            _ ->
                if args == [] do
                    {arg, state} = parse_call_argument(state)
                    parse_call_argument_list(state, [arg | args], tokens)
                else
                    {_, tok, state} = expect_token(state, :comma, "comma")
                    {arg, state} = parse_call_argument(state)
                    parse_call_argument_list(state, [arg | args], [tok | tokens])
                end
        end
    end

    @spec parse_call_argument(state()) :: return_n()
    defp parse_call_argument(state) do
        {mut_ref, state} = case next_token(state) do
            {:mut, mut, state} ->
                {_, ref, state} = expect_token(state, :ref, "'ref' keyword")
                {[mut_keyword: mut, ref_keyword: ref], state}
            _ -> {[], state}
        end

        {expr, state} = parse_expr(state)

        {new_node(:call_argument, expr.location(), mut_ref, [expression: expr]), state}
    end

    @spec parse_primary_expr(state()) :: return_n()
    defp parse_primary_expr(state) do
        case next_token(state) do
            {:if, _, _} -> parse_if_expr(state)
            {:cond, _, _} -> parse_cond_expr(state)
            {:match, _, _} -> parse_match_expr(state)
            {:loop, _, _} -> parse_loop_expr(state)
            {:while, _, _} -> parse_while_expr(state)
            {:for, _, _} -> parse_for_expr(state)
            {:break, _, _} -> parse_break_expr(state)
            {:goto, _, _} -> parse_goto_expr(state)
            {:return, _, _} -> parse_return_expr(state)
            {:asm, _, _} -> parse_asm_expr(state)
            {:new, _, _} -> parse_new_expr(state)
            {:assert, _, _} -> parse_assert_expr(state)
            {:meta, _, _} -> parse_meta_expr(state)
            {:macro, _, _} -> parse_macro_expr(state)
            {:quote, _, _} -> parse_quote_expr(state)
            {:unquote, _, _} -> parse_unquote_expr(state)
            {t, _, _} when t in [:safe, :unsafe] -> parse_safety_expr(state)
            {:brace_open, _, _} -> parse_block(state)
            {t, tok, state} when t in [:string, :character,
                                       :true, :false,
                                       :null,
                                       :float, :integer,
                                       :f32, :f64,
                                       :i8, :u8,
                                       :i16, :u16,
                                       :i32, :u32,
                                       :i64, :u64,
                                       :i, :u] ->
                ast_type = cond do
                    t == :string -> :string_expr
                    t == :character -> :character_expr
                    t in [:true, :false] -> :boolean_expr
                    t == :null -> :null_expr
                    t in [:float,
                          :f32, :f64] -> :float_expr
                    t in [:integer,
                          :i8, :u8,
                          :i16, :u16,
                          :i32, :u32,
                          :i64, :u64,
                          :i, :u] -> :integer_expr
                end

                {new_node(ast_type, tok.location(), [literal: tok], []), state}
            {:bracket_open, _, _} -> parse_vector_expr(state)
            {:identifier, _, istate} ->
                case next_token(istate) do
                    # If the identifier is followed by a colon, it's a labelled block.
                    {:colon, _, _} -> parse_labelled_block(state)
                    # Otherwise, it's just a regular identifier (possibly qualified).
                    _ -> parse_identifier_expr(state)
                end
            # An identifier accessing the global scope.
            {:colon_colon, _, _} -> parse_identifier_expr(state)
            {_, tok, _} ->
                val = if String.printable?(tok.value()), do: tok.value(), else: "<non-printable token>"
                raise_error(tok.location(), "Expected primary expression, but found: #{val}")
        end
    end

    @spec parse_if_expr(state()) :: return_n()
    defp parse_if_expr(state) do
        {_, tok_if, state} = expect_token(state, :if, "'if' keyword")
        {cond_expr, state} = parse_expr(state)
        {then_block, state} = parse_block(state)

        {else_block, else_tok, state} = case next_token(state) do
            {:else, tok, state} ->
                {block, state} = case next_token(state) do
                    {:if, _, _} -> parse_if_expr(state)
                    _ -> parse_block(state)
                end

                {[false_block: block], [else_keyword: tok], state}
            _ -> {[], [], state}
        end

        {new_node(:if_expr, tok_if.location(), [{:if_keyword, tok_if} | else_tok],
                  [{:condition, cond_expr}, {:true_block, then_block} | else_block]), state}
    end

    @spec parse_cond_expr(state()) :: return_n()
    defp parse_cond_expr(state) do
        {_, tok_cond, state} = expect_token(state, :cond, "'cond' keyword")
        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {branches, state} = parse_cond_branch_list(state)
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        branches = lc branch inlist branches, do: {:branch, branch}

        tokens = [cond_keyword: tok_cond,
                  opening_brace: tok_open,
                  closing_brace: tok_close]

        {new_node(:cond_expr, tok_cond.location(), tokens, branches), state}
    end

    @spec parse_cond_branch_list(state(), [ast_node()]) :: return_m()
    defp parse_cond_branch_list(state, branches // []) do
        {branch, state} = parse_cond_branch(state)

        case next_token(state) do
            {:brace_close, _, _} -> {Enum.reverse([branch | branches]), state}
            _ -> parse_cond_branch_list(state, [branch | branches])
        end
    end

    @spec parse_cond_branch(state()) :: return_n()
    defp parse_cond_branch(state) do
        {expr, state} = parse_expr(state)
        {block, state} = parse_block(state)

        {new_node(:cond_expr_branch, expr.location(), [], [condition: expr, body: block]), state}
    end

    @spec parse_match_expr(state()) :: return_n()
    defp parse_match_expr(state) do
        {_, tok_match, state} = expect_token(state, :match, "'match' keyword")
        {expr, state} = parse_expr(state)
        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {branches, state} = parse_match_branch_list(state)
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        tokens = [match_keyword: tok_match,
                  opening_brace: tok_open,
                  closing_brace: tok_close]

        branches = lc branch inlist branches, do: {:branch, branch}

        {new_node(:match_expr, tok_match.location(), tokens, [operand: expr] ++ branches), state}
    end

    @spec parse_match_branch_list(state(), [ast_node()]) :: return_m()
    defp parse_match_branch_list(state, branches // []) do
        {branch, state} = parse_match_branch(state)

        case next_token(state) do
            {:brace_close, _, _} -> {Enum.reverse([branch | branches]), state}
            _ -> parse_match_branch_list(state, [branch | branches])
        end
    end

    @spec parse_match_branch(state()) :: return_n()
    defp parse_match_branch(state) do
        {patterns, toks, state} = parse_match_branch_pattern_list(state, [])
        {block, state} = parse_block(state)

        patterns = lc pattern inlist patterns, do: {:pattern, pattern}
        toks = lc tok inlist toks, do: {:pipe, tok}

        {new_node(:match_expr_branch, elem(hd(patterns), 1).location(), toks, patterns ++ [body: block]), state}
    end

    @spec parse_match_branch_pattern_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_match_branch_pattern_list(state, patterns, tokens // []) do
        {pattern, state} = parse_match_branch_pattern(state)

        case next_token(state) do
            {:pipe, tok, state} -> parse_match_branch_pattern_list(state, [pattern | patterns], [tok | tokens])
            _ -> {Enum.reverse([pattern | patterns]), Enum.reverse(tokens), state}
        end
    end

    @spec parse_match_branch_pattern(state()) :: return_n()
    defp parse_match_branch_pattern(state) do
        # TODO: Parse pattern.

        {guard_tok, guard_node, state} = case next_token(state) do
            {:if, tok, state} ->
                {expr, state} = parse_expr(state)
                {[if_keyword: tok], [guard: expr], state}
            _ -> {[], [], state}
        end

        {new_node(:match_expr_pattern, Flect.Compiler.Syntax.Location[], guard_tok, guard_node), state}
    end

    @spec parse_loop_expr(state()) :: return_n()
    defp parse_loop_expr(state) do
        {_, tok_loop, state} = expect_token(state, :loop, "'loop' keyword")

        {body, state} = case next_token(state) do
            {:brace_open, _, _} ->
                {block, state} = parse_block(state)
                {[body: block], state}
            _ -> {[], state}
        end

        {new_node(:loop_expr, tok_loop.location(), [loop_keyword: tok_loop], body), state}
    end

    @spec parse_while_expr(state()) :: return_n()
    defp parse_while_expr(state) do
        {_, tok_while, state} = expect_token(state, :while, "'while' keyword")
        {cond_expr, state} = parse_expr(state)
        {block, state} = parse_block(state)

        {new_node(:while_expr, tok_while.location(), [while_keyword: tok_while], [condition: cond_expr, body: block]), state}
    end

    @spec parse_for_expr(state()) :: return_n()
    defp parse_for_expr(state) do
        {_, tok_for, state} = expect_token(state, :for, "'for' keyword")

        # TODO: Parse pattern.

        {_, tok_in, state} = expect_token(state, :in, "'in' keyword")
        {expr, state} = parse_expr(state)
        {body, state} = parse_block(state)

        {new_node(:for_expr, tok_for.location(), [for_keyword: tok_for, in_keyword: tok_in], [expression: expr, body: body]), state}
    end

    @spec parse_break_expr(state()) :: return_n()
    defp parse_break_expr(state) do
        {_, tok_break, state} = expect_token(state, :break, "'break' keyword")

        {new_node(:break_expr, tok_break.location(), [break_keyword: tok_break], []), state}
    end

    @spec parse_goto_expr(state()) :: return_n()
    defp parse_goto_expr(state) do
        {_, tok_goto, state} = expect_token(state, :goto, "'goto' keyword")

        {target, star, state} = case next_token(state) do
            {:star, tok_star, state} ->
                {expr, state} = parse_expr(state)
                {expr, [star: tok_star], state}
            _ ->
                {name, state} = parse_simple_name(state)
                {name, [], state}
        end

        {new_node(:goto_expr, tok_goto.location(), [{:goto_keyword, tok_goto} | star], [target: target]), state}
    end

    @spec parse_return_expr(state()) :: return_n()
    defp parse_return_expr(state) do
        {_, tok_return, state} = expect_token(state, :return, "'return' keyword")
        {expr, state} = parse_expr(state)

        {new_node(:return_expr, tok_return.location(), [return_keyword: tok_return], [expression: expr]), state}
    end

    @spec parse_asm_expr(state()) :: return_n()
    defp parse_asm_expr(state) do
        {_, tok_asm, state} = expect_token(state, :asm, "'asm' keyword")

        {tok_qual, state} = case next_token(state) do
            {:bracket_open, tok_open, state} ->
                {_, tok_qual, state} = expect_token(state, :string, "qualifier string")
                {_, tok_close, state} = expect_token(state, :bracket_close, "closing bracket")

                {[opening_bracket: tok_open, qualifier: tok_qual, closing_bracket: tok_close], state}
            _ -> {[], state}
        end

        {_, tok_code, state} = expect_token(state, :string, "assembly code string")

        {operands, state} = case next_token(state) do
            {:colon, _, _} ->
                # First one is the outputs.
                {oper1, state} = parse_asm_operand(state)

                {oper2, state} = case next_token(state) do
                    {:colon, _, _} ->
                        # Second one is the inputs.
                        {oper2, state} = parse_asm_operand(state)

                        {oper3, state} = case next_token(state) do
                            {:colon, _, _} ->
                                # Third one is the clobbers.
                                {oper3, state} = parse_asm_clobber(state)
                                {[third_operand: oper3], state}
                            _ -> {[], state}
                        end

                        {[second_operand: oper2] ++ oper3, state}
                    _ -> {[], state}
                end

                {[first_operand: oper1] ++ oper2, state}
            _ -> {[], state}
        end

        {new_node(:asm_expr, tok_asm.location(), [{:asm_keyword, tok_asm} | tok_qual] ++ [code: tok_code], operands), state}
    end

    @spec parse_asm_operand(state()) :: return_n()
    defp parse_asm_operand(state) do
        {_, tok_col, state} = expect_token(state, :colon, "colon")
        {entries, toks, state} = parse_asm_operand_entry_list(state, [])

        entries = lc entry inlist entries, do: {:entry, entry}
        toks = lc tok inlist toks, do: {:comma, tok}

        {new_node(:asm_expr_operand, tok_col.location(), [{:colon, tok_col} | toks], entries), state}
    end

    @spec parse_asm_operand_entry_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_asm_operand_entry_list(state, entries, tokens // []) do
        {entry, state} = parse_asm_operand_entry(state)

        case next_token(state) do
            {:comma, tok, state} -> parse_asm_operand_entry_list(state, [entry | entries], [tok | tokens])
            _ -> {Enum.reverse([entry | entries]), Enum.reverse(tokens), state}
        end
    end

    @spec parse_asm_operand_entry(state()) :: return_n()
    defp parse_asm_operand_entry(state) do
        {_, tok_open, state} = expect_token(state, :paren_open, "opening_parenthesis")
        {_, tok_ident, state} = expect_token(state, :identifier, "symbolic name")
        {_, tok_comma1, state} = expect_token(state, :comma, "comma")
        {_, tok_str, state} = expect_token(state, :string, "constraint string")
        {_, tok_comma2, state} = expect_token(state, :comma, "comma")
        {expr, state} = parse_expr(state)
        {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")

        tokens = [opening_parenthesis: tok_open,
                  symbolic_name: tok_ident,
                  comma: tok_comma1,
                  constraint: tok_str,
                  comma: tok_comma2,
                  closing_parenthesis: tok_close]

        {new_node(:asm_expr_operand_entry, tok_str.location(), tokens, [expression: expr]), state}
    end

    @spec parse_asm_clobber(state()) :: return_n()
    defp parse_asm_clobber(state) do
        {_, tok_col, state} = expect_token(state, :colon, "colon")
        {entries, toks, state} = parse_asm_clobber_entry_list(state, [])

        entries = lc entry inlist entries, do: {:entry, entry}
        toks = lc tok inlist toks, do: {:comma, tok}

        {new_node(:asm_expr_clobber, tok_col.location(), [{:colon, tok_col} | toks], entries), state}
    end

    @spec parse_asm_clobber_entry_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_asm_clobber_entry_list(state, entries, tokens // []) do
        {entry, state} = parse_asm_clobber_entry(state)

        case next_token(state) do
            {:comma, tok, state} -> parse_asm_clobber_entry_list(state, [entry | entries], [tok | tokens])
            _ -> {Enum.reverse([entry | entries]), Enum.reverse(tokens), state}
        end
    end

    @spec parse_asm_clobber_entry(state()) :: return_n()
    defp parse_asm_clobber_entry(state) do
        {_, tok_str, state} = expect_token(state, :string, "clobber string")

        {new_node(:asm_expr_clobber_entry, tok_str.location(), [clobber: tok_str], []), state}
    end

    @spec parse_new_expr(state()) :: return_n()
    defp parse_new_expr(state) do
        {_, tok_new, state} = expect_token(state, :new, "'new' keyword")
        {type, state} = parse_nominal_type(state)
        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {pairs, toks, state} = parse_field_value_pair_list(state, [])
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        pairs = lc pair inlist pairs, do: {:pair, pair}
        toks = lc tok inlist toks, do: {:comma, tok}

        tokens = [new_keyword: tok_new,
                  opening_brace: tok_open,
                  closing_brace: tok_close] ++ toks

        {new_node(:new_expr, tok_new.location(), tokens, [type: type] ++ pairs), state}
    end

    @spec parse_field_value_pair_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_field_value_pair_list(state, pairs, tokens // []) do
        case next_token(state) do
            {:brace_close, _, _} -> {Enum.reverse(pairs), Enum.reverse(tokens), state}
            _ ->
                if pairs == [] do
                    {pair, state} = parse_field_value_pair(state)
                    parse_field_value_pair_list(state, [pair | pairs], tokens)
                else
                    {_, tok, state} = expect_token(state, :comma, "comma")
                    {pair, state} = parse_field_value_pair(state)
                    parse_field_value_pair_list(state, [pair | pairs], [tok | tokens])
                end
        end
    end

    @spec parse_field_value_pair(state()) :: return_n()
    defp parse_field_value_pair(state) do
        {name, state} = parse_simple_name(state)
        {_, tok_eq, state} = expect_token(state, :assign, "equals sign")
        {expr, state} = parse_expr(state)

        {new_node(:field_value_pair, name.location(), [equals: tok_eq], [name: name, value: expr]), state}
    end

    @spec parse_assert_expr(state()) :: return_n()
    defp parse_assert_expr(state) do
        {_, tok_assert, state} = expect_token(state, :assert, "'assert' keyword")
        {expr, state} = parse_expr(state)

        {msg, state} = case next_token(state) do
            {:comma, tok, state} ->
                {_, itok, state} = expect_token(state, :string, "message string")
                {[comma: tok, message: itok], state}
            _ -> {[], state}
        end

        {new_node(:assert_expr, tok_assert.location(), [assert_keyword: tok_assert] ++ msg, [condition: expr]), state}
    end

    @spec parse_meta_expr(state()) :: return_n()
    defp parse_meta_expr(state) do
        {_, tok_meta, state} = expect_token(state, :meta, "'meta' keyword")
        {t, tok_type, state} = expect_token(state, [:type, :fn, :trait, :glob, :tls, :macro],
                                            "'type', 'fn', 'trait', 'glob', 'tls', or 'macro' keyword")

        {operand, state} = case t do
            :type -> parse_type(state)
            :fn -> parse_qualified_name(state)
            :trait -> parse_qualified_name(state)
            :glob -> parse_qualified_name(state)
            :tls -> parse_qualified_name(state)
            :macro -> parse_qualified_name(state)
        end

        {new_node(:meta_expr, tok_meta.location(), [meta_keyword: tok_meta, query_keyword: tok_type], [operand: operand]), state}
    end

    @spec parse_macro_expr(state()) :: return_n()
    defp parse_macro_expr(state) do
        {_, tok_macro, state} = expect_token(state, :macro, "'macro' keyword")
        {_, tok_query, state} = expect_token(state, :string, "macro query string")

        {new_node(:macro_expr, tok_macro.location(), [macro_keyword: tok_macro, query: tok_query], []), state}
    end

    @spec parse_quote_expr(state()) :: return_n()
    defp parse_quote_expr(state) do
        {_, tok_quote, state} = expect_token(state, :quote, "'quote' keyword")
        {expr, state} = parse_expr(state)

        {new_node(:quote_expr, tok_quote.location(), [quote_keyword: tok_quote], [expression: expr]), state}
    end

    @spec parse_unquote_expr(state()) :: return_n()
    defp parse_unquote_expr(state) do
        {_, tok_unquote, state} = expect_token(state, :unquote, "'unquote' keyword")
        {expr, state} = parse_expr(state)

        {new_node(:unquote_expr, tok_unquote.location(), [unquote_keyword: tok_unquote], [expression: expr]), state}
    end

    @spec parse_safety_expr(state()) :: return_n()
    defp parse_safety_expr(state) do
        {t, tok_safety, state} = expect_token(state, [:safe, :unsafe], "'safe' or 'unsafe' keyword")
        {block, state} = parse_block(state)

        {type, tok} = case t do
            :safe -> {:safe_expr, [safe_keyword: tok_safety]}
            :unsafe -> {:unsafe_expr, [unsafe_keyword: tok_safety]}
        end

        {new_node(type, tok_safety.location(), tok, [body: block]), state}
    end

    @spec parse_block(state()) :: return_n()
    defp parse_block(state) do
        {_, tok_open, state} = expect_token(state, :brace_open, "opening brace")
        {exprs, toks, state} = parse_stmt_expr_list(state, [])
        {_, tok_close, state} = expect_token(state, :brace_close, "closing brace")

        exprs = lc expr inlist exprs, do: {:expression, expr}
        toks = lc tok inlist toks, do: {:semicolon, tok}

        {new_node(:block_expr, tok_open.location(),
                  [{:opening_brace, tok_open} | toks] ++ [closing_brace: tok_close], exprs), state}
    end

    @spec parse_stmt_expr_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_stmt_expr_list(state, exprs, tokens // []) do
        case next_token(state) do
            {:brace_close, _, _} -> {Enum.reverse(exprs), Enum.reverse(tokens), state}
            _ ->
                {expr, state} = parse_stmt_expr(state)
                {_, tok, state} = expect_token(state, :semicolon, "semicolon")
                parse_stmt_expr_list(state, [expr | exprs], [tok | tokens])
        end
    end

    @spec parse_stmt_expr(state()) :: return_n()
    defp parse_stmt_expr(state) do
        case next_token(state) do
            {:let, _, _} -> parse_let_expr(state)
            _ -> parse_expr(state)
        end
    end

    @spec parse_let_expr(state()) :: return_n()
    defp parse_let_expr(state) do
        {_, tok_let, state} = expect_token(state, :let, "'let' keyword")

        {mut, state} = case next_token(state) do
            {:mut, tok, state} -> {[mut_keyword: tok], state}
            _ -> {[], state}
        end

        # TODO: Parse pattern.

        {type, ty_tok, state} = case next_token(state) do
            {:colon, tok, state} ->
                {type, state} = parse_type(state)
                {[type: type], [colon: tok], state}
            _ -> {[], [], state}
        end

        {_, eq, state} = expect_token(state, :assign, "equals sign")
        {expr, state} = parse_expr(state)

        {new_node(:let_expr, tok_let.location(), [{:let_keyword, tok_let} | mut] ++ ty_tok ++ [equals: eq],
                  type ++ [expression: expr]), state}
    end

    @spec parse_vector_expr(state(), boolean()) :: return_n()
    defp parse_vector_expr(state, array // false) do
        {_, tok_open, state} = expect_token(state, :bracket_open, "opening bracket")
        {exprs, toks, state} = parse_vector_expr_list(state, [])

        {type, etok, state} = case next_token(state) do
            {:period_period, etok, state} ->
                {_, tok_int, state} = expect_token(state, :integer, "vector size integer")
                {:vector_expr, [ellipsis: etok, size: tok_int], state}
            {_, tok, _} ->
                if !array do
                    val = if String.printable?(tok.value()), do: tok.value(), else: "<non-printable token>"
                    raise_error(tok.location(), "Expected elements/size-separating ellipsis, but found: #{val}")
                end

                {:array_expr, [], state}
        end

        {_, tok_close, state} = expect_token(state, :bracket_close, "closing bracket")

        exprs = lc expr inlist exprs, do: {:expression, expr}
        toks = lc tok inlist toks, do: {:comma, tok}

        tokens = [{:opening_bracket, tok_open} | toks] ++ etok ++ [closing_bracket: tok_close]

        {new_node(type, tok_open.location(), tokens, exprs), state}
    end

    @spec parse_vector_expr_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_vector_expr_list(state, exprs, tokens // []) do
        case next_token(state) do
            {t, _, _} when t in [:period_period, :bracket_close] -> {Enum.reverse(exprs), Enum.reverse(tokens), state}
            _ ->
                if exprs == [] do
                    {expr, state} = parse_expr(state)
                    parse_vector_expr_list(state, [expr | exprs], tokens)
                else
                    {_, tok, state} = expect_token(state, :comma, "comma")
                    {expr, state} = parse_expr(state)
                    parse_vector_expr_list(state, [expr | exprs], [tok | tokens])
                end
        end
    end

    @spec parse_labelled_block(state()) :: return_n()
    defp parse_labelled_block(state) do
        {label, state} = parse_simple_name(state)
        {_, tok_col, state} = expect_token(state, :colon, "colon")
        {block, state} = parse_block(state)

        {new_node(:labelled_block_expr, label.location(), [colon: tok_col], [label: label, block: block]), state}
    end

    @spec parse_identifier_expr(state()) :: return_n()
    defp parse_identifier_expr(state) do
        {name, state} = parse_qualified_name(state)

        {ty_args, state} = case next_token(state) do
            {:bracket_open, _, _} ->
                {ty_args, state} = parse_type_arguments(state)
                {[arguments: ty_args], state}
            _ -> {[], state}
        end

        {new_node(:identifier_expr, name.location(), [], [{:name, name} | ty_args]), state}
    end

    @spec parse_attribute(state(), token()) :: return_n()
    defp parse_attribute(state, visibility) do
        {_, tok_at, state} = expect_token(state, :at, "at")
        {_, tok_open, state} = expect_token(state, :bracket_open, "opening bracket")
        {name, state} = parse_attribute_name(state)

        {attr_args, state} = case next_token(state) do
            {:paren_open, _, _} ->
                {attr_args, state} = parse_attribute_arguments(state)
                {[arguments: attr_args], state}
            _ -> {[], state}
        end
        {_, tok_close, state} = expect_token(state, :bracket_close, "closing bracket")

        {new_node(:attribute, name.location(), [at_symbol: tok_at] ++ [opening_bracket: tok_open] ++
                    [closing_bracket: tok_close], [name: name] ++ attr_args), state}
    end

    @spec parse_attribute_name(state()) :: return_n()
    defp parse_attribute_name(state) do
        case next_token(state) do
            {v, tok, state} when v == :identifier ->
                {new_node(:attribute_name, tok.location(), [name: tok]), state}

            {_, tok, state} ->
                if Flect.Compiler.Syntax.Lexer.keyword?(atom_to_binary(tok.type())) do
                    {new_node(:attribute_name, tok.location(), [name: tok]), state}

                else
                    raise_error(tok.location(), "Expected keyword or identifier")
                end
        end
    end

    @spec parse_attribute_arguments(state()) :: return_n()
    defp parse_attribute_arguments(state) do
        {_, tok_open, state} = expect_token(state, :paren_open, "opening parenthesis")
        {attrs, toks, state} = parse_attribute_argument_list(state, [])
        {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")

        attrs = Enum.reverse(attrs)
        attrs = lc attr inlist attrs, do: {:attribute_argument, attr}
        toks = lc tok inlist toks, do: {:comma, tok}

        {new_node(:attribute_arguments, tok_open.location(),
                  [opening_parenthesis: tok_open] ++ toks ++ [closing_parenthesis: tok_close], attrs), state}
    end

    @spec parse_attribute_argument_list(state(), [ast_node()], [token()]) :: return_mt()
    defp parse_attribute_argument_list(state, attrs, tokens // []) do
        {attr, state} = parse_attribute_argument(state)

        case next_token(state) do
            {:comma, tok, state} -> parse_attribute_argument_list(state, [attr | attrs], [tok | tokens])
            _ -> {[attr | attrs], tokens, state}
        end
    end

    @spec parse_attribute_argument(state()) :: return_n()
    defp parse_attribute_argument(state) do
        {name, state} = parse_attribute_name(state)

        {attr, state} = case next_token(state) do
            {:assign, _, _} ->
                {attr_val, state} = parse_attribute_value(state)
                {[attribute_value: attr_val], state}
            _ ->
                {[], state}
        end

        {new_node(:attribute_argument, name.location(), [], [name: name] ++ attr), state}
    end

    @spec parse_attribute_value(state()) :: return_n()
    defp parse_attribute_value(state) do
        {_, tok_assign, state} = expect_token(state, :assign, "assign")

        {attr_val, state} = case next_token(state) do
            {v, token, state} when v == :paren_open ->
                {attr_args, state} = parse_attribute_arguments(state)
                {[attribute_argument: attr_args], state}
            _ ->
                {attr_lit, state} = parse_attribute_literal(state)
                {[attribute_argument: attr_lit], state}
        end

        {new_node(:attribute_value, tok_assign.location(), [assign: tok_assign], attr_val), state}
    end

    @spec parse_attribute_literal(state()) :: return_n()
    defp parse_attribute_literal(state) do
        case next_token(state) do
            {v, tok, state} when v in [:u8, :u16, :u32, :u64, :i8, :i16, :i32, :i64] ->
                {new_node(:attribute_typed_int_literal, tok.location(), [name: tok]), state}

            {w, tok, state} when w in [:f32, :f64] ->
                {new_node(:attribute_typed_float_literal, tok.location(), [name: tok]), state}

            {x, tok, state} when x == :character ->
                {new_node(:attribute_char_literal, tok.location(), [name: tok]), state}

            {y, tok, state} when y == :string ->
                {new_node(:attribute_string_literal, tok.location(), [name: tok]), state}

            {_, tok, state} ->
                raise_error(tok.location(), "Expected typed int literal, typed float literal, character or string")
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

                if !ok do
                    val = if String.printable?(tok.value()), do: tok.value(), else: "<non-printable token>"
                    raise_error(l, "Expected #{str}, but found: #{val}")
                end

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

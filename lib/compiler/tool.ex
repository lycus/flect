defmodule Flect.Compiler.Tool do
    @moduledoc """
    The compiler tool used by the command line interface.
    """

    @spec get_closest_pid(String.t()) :: pid()
    defp get_closest_pid(group) do
        case :pg2.get_closest_pid(group) do
            {:error, {:no_such_group, _}} ->
                Flect.Logger.error("The server group #{group} does not exist")
                throw 2
            {:error, {:no_process, _}} ->
                Flect.Logger.error("No server found in group #{group}")
                throw 2
            pid -> pid
        end
    end

    @doc """
    Runs the compiler tool. Returns `:ok` or throws a non-zero exit code
    value on failure.
    """
    @spec run(Flect.Config.t()) :: :ok
    def run(cfg) do
        dist = case cfg.options()[:dist] do
            nil -> nil
            group -> to_binary(group)
        end

        name = case cfg.options()[:name] do
            nil -> :nonode
            _ when dist == nil ->
                Flect.Logger.error("Cannot specify a node name for non-distributed builds (--name flag)")
                throw 2
            name ->
                try do
                    binary_to_atom(name)
                rescue
                    _ ->
                        Flect.Logger.error("Invalid node name given (--name flag)")
                        throw 2
                end
        end

        style = case cfg.options()[:names] do
            "long" -> :longnames
            n when n in ["short", nil] -> :shortnames
            _ ->
                Flect.Logger.error("Unknown node name style given (--names flag)")
                throw 2
        end

        cookie = case cfg.options()[:cookie] do
            nil -> :nocookie
            _ when dist == nil ->
                Flect.Logger.error("Cannot specify a cookie for non-distributed builds (--cookie flag)")
                throw 2
            cookie ->
                try do
                    binary_to_atom(cookie)
                rescue
                    _ ->
                        Flect.Logger.error("Invalid cookie given (--cookie flag)")
                        throw 2
                end
        end

        _ = case cfg.options()[:mode] do
            m when m in ["stlib", "shlib", "exe"] -> binary_to_atom(m)
            nil -> :exe
            _ ->
                Flect.Logger.error("Unknown compilation mode given (--mode flag)")
                throw 2
        end

        stage = case cfg.options()[:stage] do
            s when s in ["read", "lex", "pp", "parse", "sema", "gen", "cc"] -> binary_to_atom(s)
            nil -> :cc
            _ ->
                Flect.Logger.error("Unknown compilation stage given (--stage flag)")
                throw 2
        end

        time = case cfg.options()[:time] do
            s when s in [true, false] -> s
            nil -> false
            _ ->
                Flect.Logger.error("Invalid (non-Boolean) argument given (--time flag)")
                throw 2
        end

        dump = case cfg.options()[:dump] do
            d when d in ["tokens", "pp-tokens", "ast", "sema-ast", "ir", "c99"] -> binary_to_atom(d)
            nil -> nil
            _ ->
                Flect.Logger.error("Unknown dump parameter given (--dump flag)")
                throw 2
        end

        defs = lc {:define, define} inlist cfg.options() do
            if !is_binary(define) do
                Flect.Logger.error("No definition name given (--define flag)")
                throw 2
            end

            case String.next_codepoint(define) do
                {cp, rest} ->
                    if !Flect.Compiler.Syntax.Lexer.identifier_start_char?(cp) do
                        Flect.Logger.error("Invalid definition name given (--define flag)")
                        throw 2
                    end

                    Enum.each(String.codepoints(rest), fn(cp) ->
                        if !Flect.Compiler.Syntax.Lexer.identifier_char?(cp) do
                            Flect.Logger.error("Invalid definition name given (--define flag)")
                            throw 2
                        end
                    end)
                :no_codepoint ->
                    Flect.Logger.error("Empty definition name given (--define flag)")
                    throw 2
            end

            define
        end

        if cfg.arguments() == [] do
            Flect.Logger.error("No source file names given")
            throw 2
        end

        Enum.each(cfg.arguments(), fn(file) ->
            if Path.extname(file) != ".fl" do
                Flect.Logger.error("File #{file} does not have extension .fl")
                throw 2
            end
        end)

        num_files = length(cfg.arguments())

        if dist do
            case :net_kernel.start([name, style]) do
                {:ok, _} -> :ok
                {:error, reason} ->
                    Flect.Logger.error("Could not start :net_kernel process: #{inspect(reason)}")
                    throw 2
            end

            case :pg2.start() do
                {:ok, _} -> :ok
                {:error, reason} ->
                    Flect.Logger.error("Could not start :pg2 process: #{inspect(reason)}")
                    throw 2
            end

            :erlang.set_cookie(node(), cookie)
            :net_adm.world()
        end

        try do
            session = if time, do: Flect.Timer.create_session("Flect Compilation Process"), else: nil

            if time, do: session = Flect.Timer.start_pass(session, :read)

            read_files = lc file inlist cfg.arguments() do
                case File.read(file) do
                    {:ok, text} -> {file, text}
                    {:error, reason} ->
                        Flect.Logger.error("Cannot read file #{file}: #{reason}")
                        throw 2
                end
            end

            if time, do: session = Flect.Timer.end_pass(session, :read)

            if stage == :read, do: throw {:stop, session}

            if time, do: session = Flect.Timer.start_pass(session, :lex)

            if !dist do
                tokenized_files = lc {file, text} inlist read_files do
                    {file, Flect.Compiler.Syntax.Lexer.lex(text, file)}
                end
            else
                refs = lc {file, text} inlist read_files do
                    # It doesn't matter which server we run lexing on since it is
                    # completely target-independent.
                    pid = get_closest_pid(group)
                    ref = :erlang.monitor(:process, pid)
                    pid <- {:flect, self(), {:lex, file, text}}

                    ref
                end

                tokenized_files = Enum.map(1 .. num_files, fn(_) ->
                    receive do
                        {:flect, {:lex, :ok, file, tokens}} -> {file, tokens}
                        {:flect, {:lex, :error, _, ex}} -> raise(ex, [], System.stacktrace())
                        {:DOWN, _, :process, pid, reason} ->
                            Flect.Logger.error("Connection lost to compiler server #{inspect(pid)}: #{inspect(reason)}")
                            throw 2
                    end
                end)

                Enum.each(refs, fn(ref) -> :erlang.demonitor(ref, [:flush]) end)
            end

            if time, do: session = Flect.Timer.end_pass(session, :lex)

            if dump == :tokens do
                Enum.each(tokenized_files, fn({_, tokens}) ->
                    Enum.each(tokens, fn(token) ->
                        Flect.Logger.info(inspect(token))
                    end)
                end)
            end

            if stage == :lex, do: throw {:stop, session}

            if time, do: session = Flect.Timer.start_pass(session, :pp)

            if !dist do
                preprocessed_files = lc {file, tokens} inlist tokenized_files do
                    {file, Flect.Compiler.Syntax.Preprocessor.preprocess(tokens, Flect.Compiler.Syntax.Preprocessor.target_defines() ++ defs, file)}
                end
            else
                refs = lc {file, tokens} inlist tokenized_files do
                    # We can run preprocessing on any server as long as we pass
                    # along the correct target defines.
                    pid = get_closest_pid(group)
                    ref = :erlang.monitor(:process, pid)
                    pid <- {:flect, self(), {:pp, file, tokens, Flect.Compiler.Syntax.Preprocessor.target_defines() ++ defs}}

                    ref
                end

                preprocessed_files = Enum.map(1 .. num_files, fn(_) ->
                    receive do
                        {:flect, {:pp, :ok, file, tokens}} -> {file, tokens}
                        {:flect, {:pp, :error, _, ex}} -> raise(ex, [], System.stacktrace())
                        {:DOWN, _, :process, pid, reason} ->
                            Flect.Logger.error("Connection lost to compiler server #{inspect(pid)}: #{inspect(reason)}")
                            throw 2
                    end
                end)

                Enum.each(refs, fn(ref) -> :erlang.demonitor(ref, [:flush]) end)
            end

            if time, do: session = Flect.Timer.end_pass(session, :pp)

            if dump == :"pp-tokens" do
                Enum.each(preprocessed_files, fn({_, tokens}) ->
                    Enum.each(tokens, fn(token) ->
                        Flect.Logger.info(inspect(token))
                    end)
                end)
            end

            if stage == :pp, do: throw {:stop, session}

            if time, do: session = Flect.Timer.start_pass(session, :parse)

            if !dist do
                parsed_files = lc {file, tokens} inlist preprocessed_files do
                    {file, Flect.Compiler.Syntax.Parser.parse(tokens, file)}
                end
            else
                refs = lc {file, tokens} inlist preprocessed_files do
                    # It doesn't matter which server we run parsing on since it is
                    # completely target-independent.
                    pid = get_closest_pid(group)
                    ref = :erlang.monitor(:process, pid)
                    pid <- {:flect, self(), {:parse, file, tokens}}

                    ref
                end

                parsed_files = Enum.map(1 .. num_files, fn(_) ->
                    receive do
                        {:flect, {:parse, :ok, file, nodes}} -> {file, nodes}
                        {:flect, {:parse, :error, _, ex}} -> raise(ex, [], System.stacktrace())
                        {:DOWN, _, :process, pid, reason} ->
                            Flect.Logger.error("Connection lost to compiler server #{inspect(pid)}: #{inspect(reason)}")
                            throw 2
                    end
                end)

                Enum.each(refs, fn(ref) -> :erlang.demonitor(ref, [:flush]) end)
            end

            if time, do: session = Flect.Timer.end_pass(session, :parse)

            if dump == :ast do
                Enum.each(parsed_files, fn({_, ast}) ->
                    Enum.each(ast, fn(node) ->
                        Flect.Logger.info(node.format())
                    end)
                end)
            end

            if stage == :parse, do: throw {:stop, session}

            throw {:stop, session}
        catch
            {:stop, session} ->
                if time do
                    session = Flect.Timer.finish_session(session)
                    output = Flect.Timer.format_session(session)
                    Flect.Logger.info(output)
                end

                :ok
        rescue
            ex in [Flect.Compiler.Syntax.SyntaxError] ->
                Flect.Logger.error(ex.error(), ex.location())
                throw 1
        end
    end
end

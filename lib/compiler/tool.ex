defmodule Flect.Compiler.Tool do
    @spec run(Flect.Config.t()) :: :ok
    def run(cfg) do
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

        Enum.each(cfg.arguments(), fn(file) ->
            if Path.extname(file) != ".fl" do
                Flect.Logger.error("File #{file} does not have extension .fl")
                throw 2
            end
        end)

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

            if stage == :read do
                throw {:stop, session}
            end

            if time, do: session = Flect.Timer.start_pass(session, :lex)

            tokenized_files = lc {file, text} inlist read_files do
                {file, Flect.Compiler.Syntax.Lexer.lex(text, file)}
            end

            if time, do: session = Flect.Timer.end_pass(session, :lex)

            if dump == :tokens do
                Enum.each(tokenized_files, fn({_, tokens}) ->
                    Enum.each(tokens, fn(token) ->
                        Flect.Logger.info(inspect(token))
                    end)
                end)
            end

            if stage == :lex do
                throw {:stop, session}
            end

            if time, do: session = Flect.Timer.start_pass(session, :parse)

            parsed_files = lc {file, tokens} inlist tokenized_files do
                {file, Flect.Compiler.Syntax.Parser.parse(tokens, file)}
            end

            if time, do: session = Flect.Timer.end_pass(session, :parse)

            if dump == :ast do
                Enum.each(parsed_files, fn({_, ast}) ->
                    Enum.each(ast, fn(node) ->
                        Flect.Logger.info(node.format())
                    end)
                end)
            end

            if stage == :parse do
                throw {:stop, session}
            end

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
            ex ->
                Flect.Logger.error(ex.message())
                throw 1
        end
    end
end

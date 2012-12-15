defmodule Flect.Compiler.Tool do
    @spec run(Flect.Config.t()) :: :ok
    def run(cfg) do
        mode = case cfg.options()[:mode] do
            m when m in ["obj", "stlib", "shlib", "exe"] -> binary_to_atom(m)
            nil -> :obj
            _ ->
                Flect.Logger.error("Unknown compilation mode given (--mode flag)")
                throw 2
        end

        stage = case cfg.options()[:stage] do
            s when s in ["lex", "parse", "sema", "gen"] -> binary_to_atom(s)
            nil -> :gen
            _ ->
                Flect.Logger.error("Unknown compilation stage given (--stage flag)")
                throw 2
        end

        if mode != :obj && stage != :gen do
            Flect.Logger.error("Compilation stage #{stage} is irrelevant for compilation mode #{mode}")
            throw 2
        end

        ext = cond do
            mode == :obj -> ".fl"
            mode in [:stlib, :shlib, :exe] -> Flect.Target.get_obj_ext()
        end

        Enum.each(cfg.arguments(), fn(file) ->
            if File.extname(file) != ext do
                Flect.Logger.error("File #{file} does not have extension #{ext}")
                throw 2
            end
        end)

        case mode do
            :obj ->
                tokenized_files = lc file inlist cfg.arguments() do
                    case File.read(file) do
                        {:ok, text} -> {file, Flect.Compiler.Syntax.Lexer.lex(text, file)}
                        {:error, reason} ->
                            Flect.Logger.error("Cannot read file #{file}: #{reason}")
                            throw 2
                    end
                end

                :ok
            :stlib -> exit(:todo)
            :shlib -> exit(:todo)
            :exe -> exit(:todo)
        end

        :ok
    end
end

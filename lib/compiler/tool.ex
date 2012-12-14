defmodule Flect.Compiler.Tool do
    @spec run(Flect.Config.t()) :: :ok
    def run(cfg) do
        mode = case cfg.options()[:mode] do
            m when m in [:obj, :stlib, :shlib, :exe] -> m
            nil ->
                Flect.Logger.error("No compilation mode given (--mode flag)")
                throw 2
            _ ->
                Flect.Logger.error("Unknown compilation mode given (--mode flag)")
                throw 2
        end

        ext = cond do
            mode == :obj -> ".fl"
            mode in [:stlib, :shlib, :exe] -> if Flect.Target.get_cc_type() == "msvc", do: ".obj", else: ".o"
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
            :stlib -> :todo
            :shlib -> :todo
            :exe -> :todo
        end
    end
end

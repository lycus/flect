defmodule Flect.Logger do
    @spec colorize(String.t(), String.t()) :: String.t()
    defp colorize(str, color) do
        if ANSI.terminal?() do
            ANSI.bright() <> color <> str <> ":" <> ANSI.reset() <> " "
        else
            str <> ": "
        end
    end

    @spec info(String.t()) :: :ok
    def info(str) do
        IO.puts(str)
    end

    @spec note(String.t()) :: :ok
    def note(str) do
        IO.puts(colorize("Note", ANSI.white()) <> "#{str}")
    end

    @spec warn(String.t()) :: :ok
    def warn(str) do
        IO.puts(colorize("Warning", ANSI.yellow()) <> "#{str}")
    end

    @spec error(String.t()) :: :ok
    def error(str) do
        IO.puts(colorize("Error", ANSI.red()) <> "#{str}")
    end
end

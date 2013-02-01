defmodule Flect.Logger do
    @spec colorize(String.t(), String.t()) :: String.t()
    defp colorize(str, color) do
        emit = IO.ANSI.terminal?() && :application.get_env(:flect, :flect_event_pid) == :undefined
        IO.ANSI.escape_fragment("%{#{color}, bright}#{str}:%{reset} ", emit)
    end

    @spec output(String.t()) :: :ok
    defp output(str) do
        case :application.get_env(:flect, :flect_event_pid) do
            {:ok, pid} -> pid <- {:flect_stdout, str <> "\n"}
            :undefined -> IO.puts(str)
        end
    end

    @spec info(String.t()) :: :ok
    def info(str) do
        output(str)
    end

    @spec note(String.t()) :: :ok
    def note(str) do
        output(colorize("Note", "green") <> "#{str}")
    end

    @spec warn(String.t()) :: :ok
    def warn(str) do
        output(colorize("Warning", "yellow") <> "#{str}")
    end

    @spec error(String.t()) :: :ok
    def error(str) do
        output(colorize("Error", "red") <> "#{str}")
    end
end

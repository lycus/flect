defmodule Flect.Logger do
    @moduledoc """
    Provides logging facilities for the various Flect tools.

    If the `:flect_event_pid` application configuration key is set for the
    `:flect` application, log messages will be sent as `{:flect_stdout, msg}`
    (where `msg` is a binary) to that PID instead of being printed to standard
    output.

    Note also that if `:flect_event_pid` is set, the current terminal is
    not ANSI-compatible, or the `FLECT_COLORS` environment variable is set to
    `0`, colored output will be disabled.
    """

    @spec colorize(String.t(), String.t()) :: String.t()
    defp colorize(str, color) do
        emit = IO.ANSI.terminal?() && :application.get_env(:flect, :flect_event_pid) == :undefined && System.get_env("FLECT_COLORS") != "0"
        IO.ANSI.escape_fragment("%{#{color}, bright}#{str}:%{reset} ", emit)
    end

    @spec output(String.t()) :: :ok
    defp output(str) do
        case :application.get_env(:flect, :flect_event_pid) do
            {:ok, pid} -> pid <- {:flect_stdout, str <> "\n"}
            :undefined -> IO.puts(str)
        end
    end

    @doc """
    Prints an informational message. Returns `:ok`.

    `str` must be a binary containing the message.
    """
    @spec info(String.t()) :: :ok
    def info(str) do
        output(str)
    end

    @doc """
    Prints a notification message. Colorized as green. Returns `:ok`.

    `str` must be a binary containing the message.
    """
    @spec note(String.t()) :: :ok
    def note(str) do
        output(colorize("Note", "green") <> str)
    end

    @doc """
    Prints a warning message. Colorized as yellow. Returns `:ok`.

    `str` must be a binary containing the message.
    """
    @spec warn(String.t()) :: :ok
    def warn(str) do
        output(colorize("Warning", "yellow") <> str)
    end

    @doc """
    Prints an error message. Colorized as red. Returns `:ok`.

    `str` must be a binary containing the message.
    """
    @spec error(String.t()) :: :ok
    def error(str) do
        output(colorize("Error", "red") <> str)
    end

    @doc """
    Prints a log message. Colorized as cyan. Returns `:ok`.

    `str` must be a binary containing the message.
    """
    @spec log(String.t()) :: :ok
    def log(str) do
        output(colorize("Log", "cyan") <> str)
    end

    @doc """
    Prints a debug message if the `FLECT_DEBUG` environment variable is set
    to `1`. Colorized as magenta. Returns `:ok`.

    `str` must be a binary containing the message.
    """
    @spec debug(String.t()) :: :ok
    def debug(str) do
        if System.get_env("FLECT_DEBUG") == "1" do
            output(colorize("Debug", "magenta") <> str)
        end
    end
end

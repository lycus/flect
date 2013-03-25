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

    If the `FLECT_DIAGS` environment variable is not set to `0`, the various
    functions in this module will output caret diagnostics when a source
    location is provided.
    """

    @spec colorize(String.t(), String.t()) :: String.t()
    defp colorize(str, color, sep // ":") do
        emit = IO.ANSI.terminal?() && :application.get_env(:flect, :flect_event_pid) == :undefined && System.get_env("FLECT_COLORS") != "0"
        IO.ANSI.escape_fragment("%{#{color}, bright}#{str}#{sep}%{reset} ", emit)
    end

    @spec output(String.t()) :: :ok
    defp output(str) do
        case :application.get_env(:flect, :flect_event_pid) do
            {:ok, pid} -> pid <- {:flect_stdout, str <> "\n"}
            :undefined -> IO.puts(str)
        end

        :ok
    end

    @spec output_diag(Flect.Compiler.Syntax.Location.t()) :: :ok
    defp output_diag(loc) do
        if loc && System.get_env("FLECT_DIAGS") != "0" && (diag = diagnostic(loc)) do
            output(diag)
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
    Prints a warning message. Colorized as yellow and white. Returns `:ok`.

    `str` must be a binary containing the message. `loc` should be either `nil`
    or a `Flect.Compiler.Syntax.Location` if printing annotated source code
    is desirable.
    """
    @spec warn(String.t(), Flect.Compiler.Syntax.Location.t() | nil, [Flect.Compiler.Syntax.Location.t()]) :: :ok
    def warn(str, loc // nil, locs // []) do
        output(colorize("Warning", "yellow") <> colorize(str, "white", ""))
        output_diag(loc)
    end

    @doc """
    Prints an error message. Colorized as red and white. Returns `:ok`.

    `str` must be a binary containing the message. `loc` should be either `nil`
    or a `Flect.Compiler.Syntax.Location` if printing annotated source code
    is desirable.
    """
    @spec error(String.t(), Flect.Compiler.Syntax.Location.t() | nil, [Flect.Compiler.Syntax.Location.t()]) :: :ok
    def error(str, loc // nil, locs // []) do
        output(colorize("Error", "red") <> colorize(str, "white", ""))
        output_diag(loc)
    end

    @doc """
    Prints a log message. Colorized as cyan and white. Returns `:ok`.

    `str` must be a binary containing the message. `loc` should be either `nil`
    or a `Flect.Compiler.Syntax.Location` if printing annotated source code
    is desirable.
    """
    @spec log(String.t()) :: :ok
    def log(str) do
        output(colorize("Log", "cyan") <> colorize(str, "white", ""))
    end

    @doc """
    Prints a debug message if the `FLECT_DEBUG` environment variable is set
    to `1`. Colorized as magenta and white. Returns `:ok`.

    `str` must be a binary containing the message.
    """
    @spec debug(String.t()) :: :ok
    def debug(str) do
        if System.get_env("FLECT_DEBUG") == "1" do
            output(colorize("Debug", "magenta") <> colorize(str, "white", ""))
        end
    end

    @spec diagnostic(Flect.Compiler.Syntax.Location.t()) :: String.t() | nil
    defp diagnostic(loc) do
        loc_line = loc.line() - 1

        classify = fn(i) ->
            cond do
                i == loc_line -> true
                i > loc_line - 3 && i < loc_line -> :prev
                i < loc_line + 3 && i > loc_line -> :next
                true -> nil
            end
        end

        # We assume that the source file (still) exists.
        lines = File.read!(loc.file()) |>
                String.split("\n") |>
                Enum.map(fn(x, i) -> {x, classify.(i)} end) |>
                Enum.filter(fn({_, t}) -> t != nil end)

        # If any of the lines contain non-printable characters, bail and don't print anything.
        if Enum.any?(lines, fn({x, _}) -> !String.printable?(x) end) do
            nil
        else
            prev = lines |> Enum.filter(fn({_, t}) -> t == :prev end) |> Enum.map(fn({x, _}) -> x end)
            line = lines |> Enum.filter(fn({_, t}) -> t == true end) |> Enum.first() |> elem(0)
            next = lines |> Enum.filter(fn({_, t}) -> t == :next end) |> Enum.map(fn({x, _}) -> x end)

            # If the leading and/or following lines are just white space, don't output them.
            if Enum.all?(prev, fn(x) -> String.strip(x) == "" end), do: prev = []
            if Enum.all?(next, fn(x) -> String.strip(x) == "" end), do: next = []

            marker = generate_marker(line, loc.column() - 1, 0, "")

            result = prev ++ [line] ++ [marker] ++ next
            length = length(result)

            Enum.map(result, fn(x, i) -> if i == length - 1, do: x, else: x <> "\n" end) |> Enum.join()
        end
    end

    @spec generate_marker(String.t(), non_neg_integer(), non_neg_integer(), String.t()) :: String.t()
    defp generate_marker(line, col, ccol, acc) do
        case String.next_codepoint(line) do
            {cp, rest} ->
                if ccol == col do
                    c = colorize("^", "green", "")
                else
                    c = if cp == "\t", do: "\t", else: " "
                end

                generate_marker(rest, col, ccol + 1, acc <> c)
            :no_codepoint ->
                if acc != "" do
                    acc
                else
                    colorize("^", "green", "")
                end
        end
    end
end

defmodule Flect.String do
    @moduledoc """
    Contains various string processing utilities.
    """

    @doc """
    Strips the leading and trailing quotes from a string. Returns the
    resulting string.

    `str` must be a string which is assumed to contain at least two single or
    double quotes.
    """
    @spec strip_quotes(String.t()) :: String.t()
    def strip_quotes(str) do
        if sub = String.slice(str, 1, String.length(str) - 2), do: sub, else: ""
    end

    @doc """
    Expands escape sequences in a string. Returns the resulting string.

    `str` must be a string. It is allowed to be empty or contain no escape
    sequences. `type` must be `:string` if `str` was lexed as a string or
    `:character` if `str` was lexed as a character.
    """
    @spec expand_escapes(String.t(), :string | :character) :: String.t()
    def expand_escapes(str, type) do
        captures = Regex.scan(%r/\\u[0-9a-fA-F]{8}/, str)

        str = Enum.reduce(captures, str, fn(cap, str) ->
            cp = <<binary_to_integer(String.slice(cap, 2, 10), 16) :: utf8>>
            String.replace(str, cap, cp, [global: false])
        end)

        str = str |>
              String.replace("\\0", "\0") |>
              String.replace("\\a", "\a") |>
              String.replace("\\b", "\b") |>
              String.replace("\\f", "\f") |>
              String.replace("\\n", "\n") |>
              String.replace("\\r", "\r") |>
              String.replace("\\t", "\t") |>
              String.replace("\\v", "\v") |>
              String.replace("\\\\", "\\")

        case type do
            :string -> String.replace(str, "\\\"", "\"")
            :character -> String.replace(str, "\\'", "'")
        end
    end
end

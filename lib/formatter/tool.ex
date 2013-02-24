defmodule Flect.Formatter.Tool do
    @moduledoc """
    The formatter tool used by the command line interface.
    """

    @doc """
    Runs the formatter tool. Returns `:ok` or throws a non-zero exit code
    value on failure.
    """
    @spec run(Flect.Config.t()) :: :ok
    def run(_cfg) do
        :ok
    end
end

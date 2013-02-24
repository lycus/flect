defmodule Flect.Analyzer.Tool do
    @moduledoc """
    The analyzer tool used by the command line interface.
    """

    @doc """
    Runs the analyzer tool. Returns `:ok` or throws a non-zero exit code
    value on failure.
    """
    @spec run(Flect.Config.t()) :: :ok
    def run(_cfg) do
        :ok
    end
end

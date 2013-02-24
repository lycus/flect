defmodule Flect.Packager.Tool do
    @moduledoc """
    The packager tool used by the command line interface.
    """

    @doc """
    Runs the packager tool. Returns `:ok` or throws a non-zero exit code
    value on failure.
    """
    @spec run(Flect.Config.t()) :: :ok
    def run(_cfg) do
        :ok
    end
end

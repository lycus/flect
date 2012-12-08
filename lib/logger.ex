defmodule Flect.Logger do
    @spec info(String.t()) :: :ok
    def info(str) do
        IO.puts(str)
    end

    @spec note(String.t()) :: :ok
    def note(str) do
        IO.puts("Note: #{str}")
    end

    @spec warning(String.t()) :: :ok
    def warning(str) do
        IO.puts("Warning: #{str}")
    end

    @spec error(String.t()) :: :ok
    def error(str) do
        IO.puts("Error: #{str}")
    end
end

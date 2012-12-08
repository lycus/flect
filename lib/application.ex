defmodule Flect.Application do
    use Application.Behaviour

    @spec start() :: :ok
    def start() do
        :ok = Application.Behaviour.start(:flect)
    end

    @spec main([char_list()]) :: no_return()
    def main(args) do
        args = lc arg inlist args, do: list_to_binary(arg)

        {opts, _} = OptionParser.parse(args, [flags: [:help,
                                                      :version],
                                              aliases: [h: :help,
                                                        v: :version]])

        if opts[:version] do
            IO.puts("Flect Programming Language - 0.1")
            IO.puts("Copyright (C) 2012 The Lycus Foundation")
            IO.puts("Available under the terms of the MIT License")
            IO.puts("")
        end

        if opts[:help] do
            IO.puts("General:")
            IO.puts("")
            IO.puts("    -v|--version: Show program version.")
            IO.puts("    -h|--help: Show command line help.")
            IO.puts("")
        end

        if opts[:help] || opts[:version] do
            System.halt(2)
        end

        start()
        System.halt(0)
    end

    @spec start(:normal, []) :: {:ok, pid(), nil}
    def start(_, []) do
        {:ok, pid} = Flect.Supervisor.start_link()
        {:ok, pid, nil}
    end

    @spec stop(nil) :: :ok
    def stop(nil) do
        :ok
    end
end

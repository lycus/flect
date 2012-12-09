defmodule Flect.Application do
    use Application.Behaviour

    @spec start() :: :ok
    def start() do
        :ok = Application.Behaviour.start(:flect)
    end

    @spec main([char_list()]) :: no_return()
    def main(args) do
        args = lc arg inlist args, do: list_to_binary(arg)

        {opts, rest} = OptionParser.parse(args, [flags: [:help,
                                                         :version],
                                                 aliases: [h: :help,
                                                           v: :version]])

        have_tool = !Enum.empty?(rest)

        if opts[:version] do
            Flect.Logger.info("Flect Programming Language - 0.1")
            Flect.Logger.info("Copyright (C) 2012 The Lycus Foundation")
            Flect.Logger.info("Available under the terms of the MIT License")
            Flect.Logger.info("")
        end

        if (!have_tool && !opts[:version]) || opts[:help] do
            Flect.Logger.info("Usage: flect [-v] [-h] <tool> <args>")
            Flect.Logger.info("")
        end

        if opts[:help] do
            :ok
        end

        if !have_tool || opts[:help] || opts[:version] do
            System.halt(2)
        end

        :application.set_env(:flect, :flect_tool, binary_to_atom(Enum.at!(rest, 0)))
        :application.set_env(:flect, :flect_options, opts)
        :application.set_env(:flect, :flect_arguments, Enum.drop(rest, 1))

        start()
        System.halt(0)
    end

    @spec start(:normal, []) :: {:ok, pid(), nil}
    def start(_, []) do
        {:ok, tool} = :application.get_env(:flect_tool)
        {:ok, opts} = :application.get_env(:flect_options)
        {:ok, args} = :application.get_env(:flect_arguments)

        cfg = Flect.Config.new(tool: tool,
                               options: opts,
                               arguments: args)

        {:ok, pid} = Flect.Supervisor.start_link(cfg)
        {:ok, pid, nil}
    end

    @spec stop(nil) :: :ok
    def stop(nil) do
        :ok
    end
end

defmodule Flect.Application do
    use Application.Behaviour

    @spec start() :: :ok
    def start() do
        :ok = Application.Behaviour.start(:flect)
    end

    @spec main([char_list()]) :: no_return()
    def main(args) do
        args = lc arg inlist args, do: list_to_binary(arg)

        {opts, rest} = OptionParser.parse(args, [switches: [:help,
                                                            :version,
                                                            :redir],
                                                 aliases: [h: :help,
                                                           v: :version,
                                                           r: :redir]])

        have_tool = !Enum.empty?(rest)

        if opts[:version] do
            Flect.Logger.info("Flect Programming Language - 0.1")
            Flect.Logger.info("Copyright (C) 2012 The Lycus Foundation")
            Flect.Logger.info("Available under the terms of the MIT License")
            Flect.Logger.info("")
        end

        if (!have_tool && !opts[:version]) || opts[:help] do
            Flect.Logger.info("Usage: flect [-v] [-h] [-r] <tool> <args>")
            Flect.Logger.info("")
        end

        if opts[:help] do
            Flect.Logger.info("Tools:")
            Flect.Logger.info("")

            tools = [{"a",
                      "Statically analyze a set of Flect source files.",
                      []},
                     {"c",
                      "Compile a set of Flect source files.",
                      []},
                     {"d",
                      "Generate documentation for a set of Flect source files.",
                      []},
                     {"f",
                      "Run the source code formatter on a set of Flect source files.",
                      []}]

            Enum.each(tools, fn({name, desc, opts}) ->
                Flect.Logger.info("    #{name}: #{desc}")

                Enum.each(opts, fn({opt, desc}) ->
                    Flect.Logger.info("        #{opt}: #{desc}")
                end)

                Flect.Logger.info("")
            end)
        end

        if opts[:version] do
            Flect.Logger.info("Configuration:")
            Flect.Logger.info("")
            Flect.Logger.info("    FLECT_PREFIX     = #{Flect.Target.get_prefix()}")
            Flect.Logger.info("    FLECT_BIN_DIR    = #{Flect.Target.get_bin_dir()}")
            Flect.Logger.info("    FLECT_LIB_DIR    = #{Flect.Target.get_lib_dir()}")
            Flect.Logger.info("    FLECT_ST_LIB_DIR = #{Flect.Target.get_st_lib_dir()}")
            Flect.Logger.info("    FLECT_SH_LIB_DIR = #{Flect.Target.get_sh_lib_dir()}")
            Flect.Logger.info("")
            Flect.Logger.info("    FLECT_CC         = #{Flect.Target.get_cc()}")
            Flect.Logger.info("    FLECT_CC_TYPE    = #{Flect.Target.get_cc_type()}")
            Flect.Logger.info("    FLECT_LD         = #{Flect.Target.get_ld()}")
            Flect.Logger.info("    FLECT_LD_TYPE    = #{Flect.Target.get_ld_type()}")
            Flect.Logger.info("    FLECT_OS         = #{Flect.Target.get_os()}")
            Flect.Logger.info("    FLECT_ARCH       = #{Flect.Target.get_arch()}")
            Flect.Logger.info("    FLECT_ABI        = #{Flect.Target.get_abi()}")
            Flect.Logger.info("")
        end

        if !have_tool || opts[:help] || opts[:version] do
            System.halt(2)
        end

        :application.set_env(:flect, :flect_tool, binary_to_atom(Enum.at!(rest, 0)))
        :application.set_env(:flect, :flect_options, opts)
        :application.set_env(:flect, :flect_arguments, Enum.drop(rest, 1))
        :application.set_env(:flect, :flect_colors, !opts[:redir])
        :application.set_env(:flect, :flect_exit_code, 0)

        start()

        {:ok, code} = :application.get_env(:flect, :flect_exit_code)
        System.halt(code)
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

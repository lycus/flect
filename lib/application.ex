defmodule Flect.Application do
    use Application.Behaviour

    @spec main([char_list()]) :: no_return()
    def main(args) do
        args = lc arg inlist args, do: list_to_binary(arg)

        {opts, rest} = OptionParser.parse(args, [switches: [help: :boolean,
                                                            version: :boolean,
                                                            redir: :boolean],
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

        tools = [{"a",
                  "Statically analyze a set of Flect source files.",
                  []},
                 {"c",
                  "Compile a set of Flect source files.",
                  [mode: "Select compilation mode. (stlib, shlib, exe) [exe]",
                   stage: "Stage to stop compilation after. (read, lex, parse, sema, gen, cc) [cc]",
                   dump: "Dump a compiler state to stdout. (tokens, ast, ir, c99) []",
                   time: "Time compilation passes and show a summary. (true, false) [false]"]},
                 {"d",
                  "Generate documentation for a set of Flect source files.",
                  []},
                 {"f",
                  "Run the source code formatter on a set of Flect source files.",
                  []},
                 {"p",
                  "Execute a package manager command.",
                  []}]

        if opts[:help] do
            Flect.Logger.info("Tools:")
            Flect.Logger.info("")

            Enum.each(tools, fn({name, desc, opts}) ->
                Flect.Logger.info("    #{name}: #{desc}")
                Flect.Logger.info("")

                Enum.each(opts, fn({opt, desc}) ->
                    Flect.Logger.info("        --#{opt} <#{opt}>: #{desc}")
                end)

                if !Enum.empty?(opts) do
                    Flect.Logger.info("")
                end
            end)
        end

        if opts[:version] do
            Flect.Logger.info("Configuration:")
            Flect.Logger.info("")
            Flect.Logger.info("    FLECT_ARCH       = #{Flect.Target.get_arch()}")
            Flect.Logger.info("    FLECT_OS         = #{Flect.Target.get_os()}")
            Flect.Logger.info("    FLECT_ABI        = #{Flect.Target.get_abi()}")
            Flect.Logger.info("    FLECT_CROSS      = #{Flect.Target.get_cross()}")
            Flect.Logger.info("")
            Flect.Logger.info("    FLECT_CC         = #{Flect.Target.get_cc()}")
            Flect.Logger.info("    FLECT_CC_TYPE    = #{Flect.Target.get_cc_type()}")
            Flect.Logger.info("    FLECT_CC_ARGS    = #{Flect.Target.get_cc_args()}")
            Flect.Logger.info("    FLECT_LD         = #{Flect.Target.get_ld()}")
            Flect.Logger.info("    FLECT_LD_TYPE    = #{Flect.Target.get_ld_type()}")
            Flect.Logger.info("    FLECT_LD_ARGS    = #{Flect.Target.get_ld_args()}")
            Flect.Logger.info("")
            Flect.Logger.info("    FLECT_PREFIX     = #{Flect.Target.get_prefix()}")
            Flect.Logger.info("    FLECT_BIN_DIR    = #{Flect.Target.get_bin_dir()}")
            Flect.Logger.info("    FLECT_LIB_DIR    = #{Flect.Target.get_lib_dir()}")
            Flect.Logger.info("    FLECT_ST_LIB_DIR = #{Flect.Target.get_st_lib_dir()}")
            Flect.Logger.info("    FLECT_SH_LIB_DIR = #{Flect.Target.get_sh_lib_dir()}")
            Flect.Logger.info("")
        end

        if !have_tool || opts[:help] || opts[:version] do
            System.halt(2)
        end

        :application.set_env(:flect, :flect_colors, !opts[:redir])

        start()

        tool = Enum.at!(rest, 0)

        if Enum.find(tools, fn(x) -> elem(x, 0) == tool end) == nil do
            Flect.Logger.error("Unknown tool: #{tool}")
            System.halt(2)
        end

        cfg = Flect.Config[tool: binary_to_atom(tool),
                           options: opts,
                           arguments: Enum.drop(rest, 1)]

        proc = Process.whereis(:flect_worker)
        code = Flect.Worker.work(proc, cfg)

        System.halt(code)
    end

    @spec start() :: :ok
    def start() do
        :ok = Application.Behaviour.start(:flect)
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

defmodule Flect.Application do
    @moduledoc """
    This is the main entry point of the Flect application.
    """

    use Application.Behaviour

    @doc """
    Runs Flect from the command line. Returns via `System.halt/1`.

    `args` must be a list of Erlang-style strings containing the command
    line arguments.
    """
    @spec main([char_list()]) :: no_return()
    def main(args) do
        args = lc arg inlist args, do: list_to_binary(arg)

        {opts, rest} = parse(args)

        have_tool = !Enum.empty?(rest)

        if opts[:version] do
            Flect.Logger.info("Flect Programming Language - 0.1")
            Flect.Logger.info("Copyright (C) 2012 The Lycus Foundation")
            Flect.Logger.info("Available under the terms of the MIT License")
            Flect.Logger.info("")
        end

        if (!have_tool && !opts[:version]) || opts[:help] do
            Flect.Logger.info("Usage: flect [-v] [-h] [-p] <tool> <args>")
            Flect.Logger.info("")
        end

        tools = [{"a",
                  "Statically analyze a set of Flect source files.",
                  []},
                 {"c",
                  "Compile a set of Flect source files.",
                  [mode: "Select compilation mode. (stlib, shlib, exe) [exe]",
                   stage: "Stage to stop compilation after. (read, lex, pp, parse, sema, gen, cc) [cc]",
                   dump: "Dump a compiler state to stdout. (tokens, pp-tokens, ast, sema-ast, ir, c99) []",
                   time: "Time compilation passes and show a summary. (true, false) [false]",
                   define: "Define a preprocessor identifier. []",
                   dist: "Select server group name for distributed compilation. []",
                   name: "Select node name. [nonode]",
                   names: "Select node name style. (short, long) [short]",
                   cookie: "Select the node cookie. [nocookie]"]},
                 {"d",
                  "Generate documentation for a set of Flect source files.",
                  []},
                 {"f",
                  "Run the source code formatter on a set of Flect source files.",
                  []},
                 {"i",
                  "Run the Flect interactive read-evaluate-print loop.",
                  []},
                 {"p",
                  "Execute a package manager command.",
                  []},
                 {"s",
                  "Start a Flect compiler server.",
                  [names: "Select node name style. (short, long) [short]",
                   group: "Select server group name. [flect_compilers]",
                   cookie: "Select the node cookie. [nocookie]"]}]

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
            Flect.Logger.info("    FLECT_FPABI      = #{Flect.Target.get_fpabi()}")
            Flect.Logger.info("    FLECT_ENDIAN     = #{Flect.Target.get_endian()}")
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

        if opts[:preload] do
            mods = [Access,
                    Application.Behaviour,
                    Behaviour,
                    Binary.Chars,
                    Binary.Inspect,
                    Code,
                    Dict,
                    Enum,
                    Exception,
                    File,
                    GenServer.Behaviour,
                    HashDict,
                    IO,
                    IO.ANSI,
                    Kernel,
                    Kernel.CLI,
                    Kernel.ErrorHandler,
                    Kernel.ParallelCompiler,
                    Kernel.ParallelRequire,
                    Kernel.RecordRewriter,
                    Kernel.SpecialForms,
                    Kernel.Typespec,
                    Keyword,
                    List,
                    List.Chars,
                    Macro,
                    Macro.Env,
                    Module,
                    Node,
                    OptionParser,
                    Path,
                    Port,
                    Process,
                    Protocol,
                    Range,
                    Record,
                    Record.Extractor,
                    Regex,
                    String,
                    String.Unicode,
                    Supervisor.Behaviour,
                    System,
                    Tuple,
                    URI,
                    URI.FTP,
                    URI.HTTP,
                    URI.HTTPS,
                    URI.LDAP,
                    URI.Parser,
                    URI.SFTP,
                    URI.TFTP,

                    Flect.Application,
                    Flect.Config,
                    Flect.Logger,
                    Flect.Supervisor,
                    Flect.Target,
                    Flect.Timer,
                    Flect.String,
                    Flect.Worker,
                    Flect.Analyzer.Tool,
                    Flect.Compiler.Tool,
                    Flect.Compiler.Syntax.Lexer,
                    Flect.Compiler.Syntax.Location,
                    Flect.Compiler.Syntax.Node,
                    Flect.Compiler.Syntax.Parser,
                    Flect.Compiler.Syntax.Preprocessor,
                    Flect.Compiler.Syntax.PreprocessorError,
                    Flect.Compiler.Syntax.SyntaxError,
                    Flect.Compiler.Syntax.Token,
                    Flect.Documentor.Tool,
                    Flect.Formatter.Tool,
                    Flect.Interactive.Tool,
                    Flect.Packager.Tool,
                    Flect.Server.Tool]

            Enum.each(mods, fn(mod) -> {:module, _} = Code.ensure_loaded(mod) end)
        end

        start()

        tool = hd(rest)

        if !Enum.find(tools, fn(x) -> elem(x, 0) == tool end) do
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

    @doc """
    Parses the given command line arguments into an `{options, rest}` pair
    and returns it.

    `args` must be a list of binaries containing the command line arguments.
    """
    @spec parse([String.t()]) :: {Keyword.t(), [String.t()]}
    def parse(args) do
        OptionParser.parse(args, [switches: [help: :boolean,
                                             version: :boolean,
                                             preload: :boolean,
                                             define: :keep],
                                  aliases: [h: :help,
                                            v: :version,
                                            p: :preload]])
    end

    @doc """
    Starts the Flect application. Returns `:ok` on success.
    """
    @spec start() :: :ok
    def start() do
        :ok = Application.Behaviour.start(:flect)
    end

    @doc """
    Stops the Flect application. Returns `:ok` on success.
    """
    @spec stop() :: :ok
    def stop() do
        :ok = :application.stop(:flect)
    end

    @doc false
    @spec start(:normal | {:takeover, node()} | {:failover, node()}, []) :: {:ok, pid(), nil}
    def start(_, []) do
        {:ok, pid} = Flect.Supervisor.start_link()
        {:ok, pid, nil}
    end

    @doc false
    @spec stop(nil) :: :ok
    def stop(nil) do
        :ok
    end
end

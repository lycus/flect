defmodule Flect.Server.Tool do
    @moduledoc """
    The server tool used by the command line interface.
    """

    @spec server_loop() :: :ok
    defp server_loop() do
        receive do
            {:flect, from, {:exit}} ->
                Flect.Logger.log("Shutting down the server")
                from <- {:flect, {:exit, :ok}}
                :ok
            {:flect, from, msg} ->
                Flect.Logger.debug("Received #{inspect(elem(msg, 0))} request from #{inspect(from)} at #{inspect(node(from))}")

                _ = case msg do
                    {:info} ->
                        from <- {:flect, {:info, {Flect.Target.get_cc_type(),
                                                  Flect.Target.get_ld_type(),
                                                  Flect.Target.get_os(),
                                                  Flect.Target.get_arch(),
                                                  Flect.Target.get_abi(),
                                                  Flect.Target.get_endian(),
                                                  Flect.Target.get_cross()}}}
                    {:lex, file, text} ->
                        try do
                            tokens = Flect.Compiler.Syntax.Lexer.lex(text, file)
                            Flect.Logger.debug("Lexing successful; sending result")
                            from <- {:flect, {:lex, :ok, file, tokens}}
                        rescue
                            ex in [Flect.Compiler.Syntax.SyntaxError] ->
                                Flect.Logger.debug("Lexing failed; sending exception")
                                from <- {:flect, {:lex, :error, file, ex}}
                        end
                    {:pp, file, tokens, defs} ->
                        try do
                            tokens = Flect.Compiler.Syntax.Preprocessor.preprocess(tokens, defs, file)
                            Flect.Logger.debug("Preprocessing successful; sending result")
                            from <- {:flect, {:pp, :ok, file, tokens}}
                        rescue
                            ex in [Flect.Compiler.Syntax.SyntaxError, Flect.Compiler.Syntax.PreprocessorError] ->
                                Flect.Logger.debug("Preprocessing failed; sending exception")
                                from <- {:flect, {:pp, :error, file, ex}}
                        end
                    {:parse, file, tokens} ->
                        try do
                            nodes = Flect.Compiler.Syntax.Parser.parse(tokens, file)
                            Flect.Logger.debug("Parsing successful; sending result")
                            from <- {:flect, {:parse, :ok, file, nodes}}
                        rescue
                            ex in [Flect.Compiler.Syntax.SyntaxError] ->
                                Flect.Logger.debug("Parsing failed; sending exception")
                                from <- {:flect, {:parse, :error, file, ex}}
                        end
                end

                server_loop()
            msg ->
                Flect.Logger.debug("Received unsupported message: #{inspect(msg)}")
        end
    end

    @doc """
    Runs the server tool. Returns `:ok` or throws a non-zero exit code
    value on failure.
    """
    @spec run(Flect.Config.t()) :: :ok
    def run(cfg) do
        name = case cfg.arguments() do
            [name] ->
                try do
                    binary_to_atom(name)
                rescue
                    _ ->
                        Flect.Logger.error("Invalid node name given (not a valid Erlang atom)")
                        throw 2
                end
            [] ->
                Flect.Logger.error("No node name command line argument given")
                throw 2
            _ ->
                Flect.Logger.error("Too many command line arguments given")
                throw 2
        end

        style = case cfg.options()[:names] do
            "long" -> :longnames
            n when n in ["short", nil] -> :shortnames
            _ ->
                Flect.Logger.error("Unknown node name style given (--names flag)")
                throw 2
        end

        group = case cfg.options()[:group] do
            nil -> "flect_compilers"
            group -> to_binary(group)
        end

        cookie = case cfg.options()[:cookie] do
            nil -> :nocookie
            cookie ->
                try do
                    binary_to_atom(cookie)
                rescue
                    _ ->
                        Flect.Logger.error("Invalid cookie given (--cookie flag)")
                        throw 2
                end
        end

        case :net_kernel.start([name, style]) do
            {:ok, pid} ->
                Flect.Logger.debug("Started :net_kernel as #{inspect(pid)}")
            {:error, reason} ->
                Flect.Logger.error("Could not start :net_kernel process: #{inspect(reason)}")
                throw 2
        end

        case :pg2.start() do
            {:ok, pid} ->
                Flect.Logger.debug("Started :pg2 as #{inspect(pid)}")
            {:error, reason} ->
                Flect.Logger.error("Could not start :pg2 process: #{inspect(reason)}")
                throw 2
        end

        :erlang.set_cookie(node(), cookie)
        _ = :net_adm.world()

        server = spawn(function(server_loop/0))
        Flect.Logger.log("Flect compiler server running as #{inspect(node())} in group #{group} with cookie #{inspect(cookie)}")

        :pg2.create(group)
        Flect.Logger.debug("Created :pg2 group #{group}")

        :ok = :pg2.join(group, server)
        Flect.Logger.debug("Joined :pg2 group #{group}")

        receive do
            {:flect, {:exit, :ok}} -> :ok
        end
    end
end

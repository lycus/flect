defmodule Flect.Worker do
    use GenServer.Behaviour

    @spec start_link(Flect.Config.t()) :: {:ok, pid()}
    def start_link(cfg) do
        {:ok, _} = :gen_server.start_link(__MODULE__, cfg, [])
    end

    @spec init(Flect.Config.t()) :: {:ok, nil}
    def init(cfg) do
        case cfg.tool() do
            :analyze -> Flect.Analyzer.Tool.run(cfg)
            :bind -> Flect.Binder.Tool.run(cfg)
            :compile -> Flect.Compiler.Tool.run(cfg)
            :document -> Flect.Documentor.Tool.run(cfg)
            :format -> Flect.Formatter.Tool.run(cfg)
            tool -> Flect.Logger.error("Unknown tool: #{inspect(tool)}")
        end

        {:ok, nil}
    end
end

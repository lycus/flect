defmodule Flect.Worker do
    use GenServer.Behaviour

    @spec start_link(Flect.Config.t()) :: {:ok, pid()}
    def start_link(cfg) do
        {:ok, _} = :gen_server.start_link(__MODULE__, cfg, [])
    end

    @spec init(Flect.Config.t()) :: {:ok, nil}
    def init(cfg) do
        try do
            case cfg.tool() do
                :a -> Flect.Analyzer.Tool.run(cfg)
                :c -> Flect.Compiler.Tool.run(cfg)
                :d -> Flect.Documentor.Tool.run(cfg)
                :f -> Flect.Formatter.Tool.run(cfg)
                tool -> Flect.Logger.error("Unknown tool: #{tool}")
            end
        catch
            code -> :application.set_env(:flect, :flect_exit_code, code)
        end

        {:ok, nil}
    end
end

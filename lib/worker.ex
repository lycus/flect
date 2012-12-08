defmodule Flect.Worker do
    use GenServer.Behaviour

    @type state() :: Flect.Config.t()

    @spec start_link(Flect.Config.t()) :: {:ok, pid()}
    def start_link(cfg) do
        {:ok, _} = :gen_server.start_link(__MODULE__, cfg, [])
    end

    @spec init(Flect.Config.t()) :: {:ok, state()}
    def init(cfg) do
        {:ok, cfg}
    end
end

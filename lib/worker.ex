defmodule Flect.Worker do
    use GenServer.Behaviour

    @type state() :: Flect.Config.t()

    @spec init(state()) :: {:ok, state()}
    def init(cfg) do
        {:ok, cfg}
    end
end

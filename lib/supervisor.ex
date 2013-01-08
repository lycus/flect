defmodule Flect.Supervisor do
    use Supervisor.Behaviour

    @spec start_link() :: {:ok, pid()}
    def start_link() do
        {:ok, _} = :supervisor.start_link(__MODULE__, nil)
    end

    @spec init(nil) :: {:ok, {{:one_for_one, non_neg_integer(), pos_integer()}, [:supervisor.child_spec()]}}
    def init(nil) do
        supervise([worker(Flect.Worker, [], [restart: :temporary,
                                             shutdown: :infinity])], [strategy: :one_for_one])
    end
end

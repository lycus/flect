defmodule Flect.Worker do
    use GenServer.Behaviour

    @spec start_link() :: {:ok, pid()}
    def start_link() do
        tup = {:ok, pid} = :gen_server.start_link(__MODULE__, nil, [])
        Process.register(pid, :flect_worker)
        tup
    end

    @spec work(pid(), Flect.Config.t()) :: non_neg_integer()
    def work(pid, cfg, timeout // :infinity) do
        code = :gen_server.call(pid, {:work, cfg}, timeout)

        _ = case :application.get_env(:flect, :flect_event_pid) do
            {:ok, pid} -> pid <- {:flect_shutdown, code}
            :undefined -> :ok
        end

        code
    end

    @spec handle_call({:work, Flect.Config.t()}, {pid(), term()}, nil) :: {:reply, non_neg_integer(), nil}
    def handle_call({:work, cfg}, _, nil) do
        code = try do
            case cfg.tool() do
                :a -> Flect.Analyzer.Tool.run(cfg)
                :c -> Flect.Compiler.Tool.run(cfg)
                :d -> Flect.Documentor.Tool.run(cfg)
                :f -> Flect.Formatter.Tool.run(cfg)
                :p -> Flect.Packager.Tool.run(cfg)
            end

            0
        catch
            code -> code
        end

        {:reply, code, nil}
    end
end

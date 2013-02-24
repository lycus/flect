defmodule Flect.Worker do
    @moduledoc """
    Encapsulates a worker process that invokes a Flect tool and collects
    its exit code. Can be supervised by an OTP supervisor.
    """

    use GenServer.Behaviour

    @doc """
    Starts a worker process linked to the parent process. Returns `{:ok, pid}`
    on success.
    """
    @spec start_link() :: {:ok, pid()}
    def start_link() do
        tup = {:ok, pid} = :gen_server.start_link(__MODULE__, nil, [])
        Process.register(pid, :flect_worker)
        tup
    end

    @doc """
    Instructs the given worker process to execute a Flect tool as specified
    by the given configuration. Returns the exit code of the tool.

    `pid` must be the PID of a `Flect.Worker` process. `cfg` must be a valid
    `Flect.Config` instance. `timeout` must be `:infinity` or a millisecond
    value specifying how much time to wait for the tool to complete.
    """
    @spec work(pid(), Flect.Config.t()) :: non_neg_integer()
    def work(pid, cfg, timeout // :infinity) do
        code = :gen_server.call(pid, {:work, cfg}, timeout)

        _ = case :application.get_env(:flect, :flect_event_pid) do
            {:ok, pid} -> pid <- {:flect_shutdown, code}
            :undefined -> :ok
        end

        code
    end

    @doc false
    @spec handle_call({:work, Flect.Config.t()}, {pid(), term()}, nil) :: {:reply, non_neg_integer(), nil}
    def handle_call({:work, cfg}, _, nil) do
        code = try do
            case cfg.tool() do
                :a -> Flect.Analyzer.Tool.run(cfg)
                :c -> Flect.Compiler.Tool.run(cfg)
                :d -> Flect.Documentor.Tool.run(cfg)
                :f -> Flect.Formatter.Tool.run(cfg)
                :i -> Flect.Interactive.Tool.run(cfg)
                :p -> Flect.Packager.Tool.run(cfg)
            end

            0
        catch
            code -> code
        end

        {:reply, code, nil}
    end
end

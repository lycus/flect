defmodule Flect.Timer do
    @opaque session() :: {String.t(), non_neg_integer(), [{atom(), :erlang.timestamp() | non_neg_integer()}]}
    @opaque finished_session() :: {String.t(), [{atom(), {non_neg_integer(), non_neg_integer()}}]}

    @spec create_session(String.t()) :: session()
    def create_session(title) do
        {title, 0, []}
    end

    @spec start_pass(session(), atom()) :: session()
    def start_pass({title, time, passes}, name) do
        {title, time, Keyword.put(passes, name, :erlang.now())}
    end

    @spec end_pass(session(), atom()) :: session()
    def end_pass({title, time, passes}, name) do
        diff = :timer.now_diff(:erlang.now(), passes[name])
        {title, time + diff, Keyword.put(passes, name, diff)}
    end

    @spec finish_session(session()) :: finished_session()
    def finish_session({title, time, passes}) do
        {title, Keyword.put((lc {n, t} inlist passes, do: {n, {t, t / time * 100}}), :total, {time, 100.0})}
    end

    @spec format_session(finished_session()) :: String.t()
    def format_session({title, passes}) do
        sep = "    ===------------------------------------------------------------==="
        head = "                         #{title}                                     "
        head2 = "        Time                   Percent Name"
        sep2 = "        ---------------------- ------- -----------"

        passes = lc {name, {time, perc}} inlist passes do
            msecs = div(time, 1000)
            secs = div(msecs, 1000)

            ftime = "#{secs}s #{msecs}ms #{time}us"

            list_to_binary(:io_lib.format("        ~-22s ~-7.1f ~w", [ftime, perc, name]))
        end

        "\n" <> sep <> "\n" <> head <> "\n" <> sep <> "\n\n" <> head2 <> "\n" <> sep2 <> "\n" <> Enum.join(Enum.reverse(passes), "\n") <> "\n"
    end
end

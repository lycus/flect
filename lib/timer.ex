defmodule Flect.Timer do
    @moduledoc """
    Provides convenience functions for timing various passes in the compiler.
    """

    @opaque session() :: {String.t(), non_neg_integer(), [{atom(), :erlang.timestamp() | non_neg_integer()}]}
    @opaque finished_session() :: {String.t(), [{atom(), {non_neg_integer(), non_neg_integer()}}]}

    @doc """
    Creates a timing session. Returns an opaque session object.

    `title` must be a binary containing the title of this timing session.
    """
    @spec create_session(String.t()) :: session()
    def create_session(title) do
        {title, 0, []}
    end

    @doc """
    Starts a pass in the given session. Returns the updated session.

    `session` must be a session object. `name` must be a binary containing the
    name of this timing pass.
    """
    @spec start_pass(session(), atom()) :: session()
    def start_pass(session, name) do
        {title, time, passes} = session
        {title, time, Keyword.put(passes, name, :erlang.now())}
    end

    @doc """
    Ends the current timing pass in the given session. Returns the updated
    session.

    `session` must be a session object with an in-progress pass. `name` must be
    the name given to the `start_pass/2` function previously.
    """
    @spec end_pass(session(), atom()) :: session()
    def end_pass(session, name) do
        {title, time, passes} = session
        diff = :timer.now_diff(:erlang.now(), passes[name])
        {title, time + diff, Keyword.put(passes, name, diff)}
    end

    @doc """
    Ends a given timing session. Returns the finished session object.

    `session` must be a session object with no in-progress passes.
    """
    @spec finish_session(session()) :: finished_session()
    def finish_session(session) do
        {title, time, passes} = session
        {title, Keyword.put((lc {n, t} inlist passes, do: {n, {t, t / time * 100}}), :total, {time, 100.0})}
    end

    @doc """
    Formats a finished session in a user-presentable way. Returns the resulting
    binary containing the formatted session.

    `session` must be a finished session object.
    """
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

            :unicode.characters_to_binary(:io_lib.format("        ~-22s ~-7.1f ~w", [ftime, perc, name]))
        end

        "\n" <> sep <> "\n" <> head <> "\n" <> sep <> "\n\n" <> head2 <> "\n" <> sep2 <> "\n" <> Enum.join(Enum.reverse(passes), "\n") <> "\n"
    end
end

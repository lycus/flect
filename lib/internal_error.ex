defexception Flect.InternalError, cause: nil do
    @moduledoc """
    The exception thrown by `Flect.Application.main/1` if some kind of
    internal error occurred in the compiler.

    `cause` is an arbitrary exception that caused the internal error.
    """

    record_type(cause: tuple())

    @doc """
    Formats the exception in a user-presentable way.

    `self` is the exception record.
    """
    @spec message(t()) :: String.t()
    def message(self) do
        "An internal compiler error (ICE) occurred\n" <>
        "\n    Looks like something blew up in the compiler. Sorry about that!" <>
        "\n    Please open an issue here: https://github.com/lycus/flect/issues\n" <>
        "\n    Including the following information will help us fix the bug faster:\n" <>
        "\n    * The output of `erl +V`, `elixir -v`, and `flect -v`" <>
        "\n    * Information about the host machine and operating system" <>
        "\n    * A reduced and isolated test case or a link to your source repository" <>
        "\n    * The stack trace printed below" <>
        "\n\n** (#{self.cause().__record__(:name)}) #{self.cause.message()}"
    end
end

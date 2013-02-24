defexception Flect.Compiler.Syntax.SyntaxError, error: "",
                                                location: nil do
    @moduledoc """
    The exception thrown by the various syntax analysis interfaces
    when the source code is malformed.

    `error` is a binary containing the full error description. `location`
    is `Flect.Compiler.Syntax.Location` indicating where the error
    occurred.
    """

    record_type(error: String.t(),
                location: Flect.Compiler.Syntax.Location.t())

    @doc """
    Formats the exception in a user-presentable way.

    `self` is the exception record.
    """
    @spec message(Flect.Compiler.Syntax.SyntaxError.t()) :: String.t()
    def message(self) do
        "#{self.location().file()}(#{self.location().line()},#{self.location().column()}): #{self.error()}"
    end
end

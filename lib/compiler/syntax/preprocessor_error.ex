defexception Flect.Compiler.Syntax.PreprocessorError, error: "",
                                                      location: nil,
                                                      notes: [] do
    @moduledoc """
    The exception thrown by the preprocessor if a semantic error occurs.

    `error` is a binary containing the full error description. `location`
    is a `Flect.Compiler.Syntax.Location` indicating where the error
    occurred. `notes` is a list of additional messages and locations that
    help in diagnosing the problem.
    """

    record_type(error: String.t(),
                location: Flect.Compiler.Syntax.Location.t(),
                notes: [{String.t(), Flect.Compiler.Syntax.Location.t()}])

    @doc """
    Formats the exception in a user-presentable way.

    `self` is the exception record.
    """
    @spec message(t()) :: String.t()
    def message(self) do
        "#{self.location().stringize()}: #{self.error()}"
    end
end

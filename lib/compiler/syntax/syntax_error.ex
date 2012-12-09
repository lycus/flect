defexception Flect.Compiler.Syntax.SyntaxError, error: "",
                                                file: "",
                                                location: nil do
    record_type(error: String.t(),
                file: String.t(),
                location: Flect.Compiler.Syntax.Location.t())

    @spec message(Flect.Compiler.Syntax.SyntaxError.t()) :: String.t()
    def message(ex) do
        "#{ex.file()}(#{ex.location().line()},#{ex.location().column()}): #{ex.error()}"
    end
end

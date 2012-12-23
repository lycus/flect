defexception Flect.Compiler.Syntax.SyntaxError, error: "",
                                                location: nil do
    record_type(error: String.t(),
                location: Flect.Compiler.Syntax.Location.t())

    @spec message(Flect.Compiler.Syntax.SyntaxError.t()) :: String.t()
    def message(self) do
        "#{self.location().file()}(#{self.location().line()},#{self.location().column()}): #{self.error()}"
    end
end

defrecord Flect.Compiler.Syntax.Token, type: nil,
                                       value: "",
                                       location: nil do
    record_type(type: atom(),
                value: String.t(),
                location: Flect.Compiler.Syntax.Location.t())
end

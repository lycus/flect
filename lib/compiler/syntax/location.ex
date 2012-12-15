defrecord Flect.Compiler.Syntax.Location, file: "",
                                          line: 1,
                                          column: 1 do
    record_type(file: String.t(),
                line: pos_integer(),
                column: pos_integer())
end

defrecord Flect.Compiler.Syntax.Location, file: "",
                                          line: 1,
                                          column: 0 do
    record_type(file: String.t(),
                line: pos_integer(),
                column: non_neg_integer())
end

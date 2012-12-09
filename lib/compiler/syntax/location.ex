defrecord Flect.Compiler.Syntax.Location, line: 1,
                                          column: 0 do
    record_type(line: pos_integer(),
                column: non_neg_integer())
end

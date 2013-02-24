defrecord Flect.Compiler.Syntax.Location, file: "",
                                          line: 1,
                                          column: 0 do
    @moduledoc """
    Represents a location in a Flect source code document.

    `file` is be a binary containing the file name of the document.
    `line` is a positive integer (starting at 1) indicating the line
    in the document. `column` is a non-negative integer (starting at
    0) indicating the column on the line.
    """

    record_type(file: String.t(),
                line: pos_integer(),
                column: non_neg_integer())
end

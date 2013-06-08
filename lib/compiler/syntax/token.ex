defrecord Flect.Compiler.Syntax.Token, type: nil,
                                       value: "",
                                       location: nil do
    @moduledoc """
    Represents a token from a Flect source code document.

    `type` is an atom describing the kind of token. `value` is a binary
    containing the raw string value of the token. `location` is a
    `Flect.Compiler.Syntax.Location` indicating where in the source code
    the token originates.

    `type` can be one of:

    * `:line_comment`
    * `:block_comment`
    * `:plus`
    * `:minus`
    * `:minus_angle_close`
    * `:star`
    * `:slash`
    * `:percent`
    * `:ampersand`
    * `:ampersand_ampersand`
    * `:pipe`
    * `:pipe_pipe`
    * `:pipe_angle_close`
    * `:caret`
    * `:tilde`
    * `:exclamation`
    * `:exclamation_assign`
    * `:exclamation_assign_assign`
    * `:paren_open`
    * `:paren_close`
    * `:brace_open`
    * `:brace_close`
    * `:bracket_open`
    * `:bracket_close`
    * `:comma`
    * `:period`
    * `:period_period`
    * `:at`
    * `:colon`
    * `:colon_colon`
    * `:semicolon`
    * `:assign`
    * `:assign_assign`
    * `:assign_assign_assign`
    * `:angle_open`
    * `:angle_open_assign`
    * `:angle_open_pipe`
    * `:angle_open_angle_open`
    * `:angle_close`
    * `:angle_close_assign`
    * `:angle_close_angle_close`
    * `:string`
    * `:character`
    * `:directive`
    * `:identifier`
    * `:mod`
    * `:use`
    * `:pub`
    * `:priv`
    * `:trait`
    * `:impl`
    * `:struct`
    * `:union`
    * `:enum`
    * `:type`
    * `:fn`
    * `:ext`
    * `:ref`
    * `:glob`
    * `:tls`
    * `:mut`
    * `:imm`
    * `:let`
    * `:as`
    * `:if`
    * `:else`
    * `:cond`
    * `:match`
    * `:loop`
    * `:while`
    * `:for`
    * `:break`
    * `:goto`
    * `:return`
    * `:safe`
    * `:unsafe`
    * `:asm`
    * `:true`
    * `:false`
    * `:null`
    * `:new`
    * `:assert`
    * `:in`
    * `:meta`
    * `:test`
    * `:macro`
    * `:quote`
    * `:unquote`
    * `:yield`
    * `:fixed`
    * `:pragma`
    * `:scope`
    * `:tls`
    * `:move`
    * `:float`
    * `:integer`
    * `:f32`
    * `:f64`
    * `:i8`
    * `:u8`
    * `:i16`
    * `:u16`
    * `:i32`
    * `:u32`
    * `:i64`
    * `:u64`
    * `:i`
    * `:u`
    """

    record_type(type: atom(),
                value: String.t(),
                location: Flect.Compiler.Syntax.Location.t())
end

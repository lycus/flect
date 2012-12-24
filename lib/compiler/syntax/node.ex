defrecord Flect.Compiler.Syntax.Node, type: nil,
                                      location: nil,
                                      tokens: [],
                                      children: [] do
    record_type(type: atom(),
                location: Flect.Compiler.Syntax.Location.t(),
                tokens: [{atom(), Flect.Compiler.Syntax.Token.t()}, ...],
                children: [t()])
end

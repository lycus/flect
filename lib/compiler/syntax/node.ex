defrecord Flect.Compiler.Syntax.Node, type: nil,
                                      tokens: [],
                                      location: nil,
                                      children: [] do
    record_type(type: atom(),
                tokens: [{atom(), Flect.Compiler.Syntax.Token.t()}],
                location: Flect.Compiler.Syntax.Location.t(),
                children: [t()])
end

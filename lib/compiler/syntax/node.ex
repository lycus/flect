defrecord Flect.Compiler.Syntax.Node, type: nil,
                                      location: nil,
                                      tokens: [],
                                      named_children: [],
                                      children: [],
                                      data: nil do
    record_type(type: atom(),
                location: Flect.Compiler.Syntax.Location.t(),
                tokens: [{atom(), Flect.Compiler.Syntax.Token.t()}, ...],
                named_children: [{atom(), t()}],
                children: [t()],
                data: term())
end

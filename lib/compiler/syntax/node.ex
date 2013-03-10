defrecord Flect.Compiler.Syntax.Node, type: nil,
                                      location: nil,
                                      tokens: [],
                                      named_children: [],
                                      children: [],
                                      data: nil do
    @moduledoc """
    Represents an AST (abstract syntax tree) node.

    `type` is an atom indicating the kind of node. `location` is a
    `Flect.Compiler.Syntax.Location` indicating the node's location in
    the source code document. `tokens` is a list of the
    `Flect.Compiler.Syntax.Token`s that make up this node. `children` is
    a list of all children. `data` is an arbitrary term associated with the
    node - it can have different meanings depending on which compiler stage
    the node is being used in.
    """

    record_type(type: atom(),
                location: Flect.Compiler.Syntax.Location.t(),
                tokens: [{atom(), Flect.Compiler.Syntax.Token.t()}, ...],
                children: [{atom(), t()}],
                data: term())

    @doc """
    Formats the node and all of its children in a user-presentable way.
    Returns the resulting binary.

    `self` is the node record.
    """
    @spec format(t()) :: String.t()
    def format(self) do
        do_format(self, "")
    end

    @spec do_format(t(), String.t()) :: String.t()
    defp do_format(node, indent) do
        loc = fn(loc) -> "(#{loc.line()},#{loc.column()})" end

        str = indent <> "#{atom_to_binary(node.type())} #{loc.(node.location())} "
        str = str <> "[ " <> Enum.join((lc {_, t} inlist node.tokens(), do: "\"#{t.value()}\" #{loc.(t.location())}"), ", ") <> " ]\n"
        str = str <> indent <> "{\n"
        str = str <> Enum.join(lc {_, child} inlist node.children(), do: do_format(child, indent <> "    ") <> "\n")
        str = str <> indent <> "}"

        str
    end
end

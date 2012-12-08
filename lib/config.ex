defrecord Flect.Config, tool: "",
                        options: [],
                        arguments: [] do
    record_type(tool: atom(),
                options: Keyword.t(),
                arguments: [String.t()])
end

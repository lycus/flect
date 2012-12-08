defrecord Flect.Config, tool: "",
                        options: [],
                        arguments: [] do
    record_type(tool: String.t(),
                options: Keyword.t(),
                arguments: [String.t()])
end

defrecord Flect.Config, tool: "",
                        options: [],
                        arguments: [] do
    @moduledoc """
    Represents the configuration for an invocation of a Flect tool.

    `tool` is a binary containing the tool name. `options` is a keyword
    list of global options. `arguments` is a list of binaries containing
    the command line arguments.

    `options` should contain only any the following keys:

    * `help`: Boolean value indicating whether to print the help message.
    * `version`: Boolean value indicating whether to print the version.
    * `preload`: Boolean value indicating whether to preload all modules.
    """

    record_type(tool: atom(),
                options: Keyword.t(),
                arguments: [String.t()])
end

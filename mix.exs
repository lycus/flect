defmodule Flect.Mixfile do
    use Mix.Project

    def project() do
        [app: :flect,
         version: "0.1",
         deps: deps(),
         elixirc_options: [debug_info: true],
         escript_embed_elixir: true,
         escript_main_module: Flect.Application]
    end

    def application() do
        [applications: [],
         mod: {Flect.Application, []}]
    end

    defp deps() do
        []
    end
end

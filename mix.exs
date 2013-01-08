defmodule Flect.Mixfile do
    use Mix.Project

    def project() do
        [app: :flect,
         version: "0.1",
         deps: deps(),
         escript_main_module: Flect.Application,
         escript_path: File.join("ebin", "flect")]
    end

    def application() do
        [applications: [],
         mod: {Flect.Application, []}]
    end

    defp deps() do
        [{:ansiex, github: "yrashk/ansiex"}]
    end
end

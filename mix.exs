defmodule Flect.Mixfile do
    use Mix.Project

    def project() do
        [app: :flect,
         version: "0.1",
         deps: deps(),
         escript_main_module: Flect.Application,
         escript_path: Path.join("ebin", "flect"),
         escript_emu_args: "%%! -noinput +B\n"]
    end

    def application() do
        [applications: [],
         mod: {Flect.Application, []}]
    end

    defp deps() do
        [{:ansiex, github: "yrashk/ansiex"}]
    end
end

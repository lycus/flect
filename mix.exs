defmodule Flect.Mixfile do
    use Mix.Project

    def project() do
        [app: :flect,
         version: "0.1",
         escript_main_module: Flect.Application,
         escript_path: Path.join("ebin", "flect"),
         escript_emu_args: "%%! -noshell +B\n"]
    end

    def application() do
        [applications: [],
         mod: {Flect.Application, []}]
    end
end

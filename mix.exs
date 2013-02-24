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

defmodule Mix.Tasks.Docs do
    @shortdoc "Generates documentation for the compiler library"

    def run(_) do
        Mix.Task.run("loadpaths")

        Mix.shell.cmd("elixir -pa ebin -S exdoc " <>
                      "Flect #{Mix.project()[:version]} " <>
                      "-m Flect.Application " <>
                      "-u https://github.com/lycus/flect/blob/master/%{path}#L%{line}")
    end
end

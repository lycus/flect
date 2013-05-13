path = hd(System.argv())

passes = :file.list_dir(path) |>
         elem(1) |>
         Enum.filter(fn(x) -> Path.extname(x) == '.pass' end) |>
         Enum.sort() |>
         Enum.map(fn(x) -> Path.join(path, x) end) |>
         Enum.map(fn(x) -> [pass: x |> Path.basename() |> Path.rootname()] ++ Enum.at!(elem(:file.consult(x), 1), 0) end)

files = :file.list_dir(path) |>
        elem(1) |>
        Enum.filter(fn(x) -> Path.extname(x) == '.fl' end) |>
        Enum.map(fn(x) -> :unicode.characters_to_binary(x) end) |>
        Enum.sort()

vars = lc {a, s} inlist [arch: "ARCH",
                         os: "OS",
                         abi: "ABI",
                         fpabi: "FPABI",
                         endian: "ENDIAN",
                         cross: "CROSS",
                         cc_type: "CC_TYPE",
                         ld_type: "LD_TYPE"] do
    {a, System.get_env("FLECT_" <> s) |> String.replace("-", "_") |> binary_to_atom()}
end

otp = :erlang.system_info(:otp_release)

if otp >= 'R16B' && System.get_env("FLECT_COVER") == "1" do
    Mix.loadpaths()

    :cover.compile_beam_directory(Mix.project()[:compile_path] |> to_char_list())

    dir = Path.join(Mix.project()[:compile_path], "cover")

    :cover.import(Path.join(dir, "flect.coverdata") |> to_char_list())
end

File.cd!(path)

results = Enum.map(passes, fn(pass) ->
    IO.puts("")
    IO.puts("  Testing #{path} (#{pass[:description]})...")
    IO.puts("")

    Enum.map(files, fn(file) ->
        check = fn(file, pass, text, code) ->
            exp = case File.read(file <> "." <> pass[:pass] <> ".exp") do
                {:ok, data} -> String.strip(text) == String.strip(data)
                {:error, :enoent} -> true
            end

            cond do
                code != pass[:code] ->
                    IO.puts(IO.ANSI.escape("%{red, bright}fail (#{code})"))
                    false
                !exp ->
                    IO.puts(IO.ANSI.escape("%{red, bright}fail (exp)"))
                    false
                true ->
                    IO.puts(IO.ANSI.escape("%{green, bright}ok (#{code})"))
                    true
            end
        end

        {extra_args, expr, condition} = case :file.consult(file <> "." <> pass[:pass] <> ".arg") do
            {:ok, [args, expr]} ->
                args = Enum.map(args, fn(arg) -> :unicode.characters_to_binary(arg) end)
                expr = :unicode.characters_to_binary(expr)
                condition = elem(Code.eval(expr, vars), 0)

                {args, expr, condition}
            {:error, :enoent} -> {[], "", true}
        end

        args = Enum.map(pass[:command], fn(arg) ->
            arg |>
            :unicode.characters_to_binary() |>
            String.replace("<file>", file) |>
            String.replace("<name>", Path.rootname(file))
        end) ++ extra_args

        IO.write("    flect #{args |> Enum.join(" ")} ... ")

        if condition do
            {opts, rest} = Flect.Application.parse(args)

            cfg = Flect.Config[tool: binary_to_atom(hd(rest)),
                               options: opts,
                               arguments: Enum.drop(rest, 1)]

            :application.set_env(:flect, :flect_event_pid, self())
            Flect.Application.start()

            proc = Process.whereis(:flect_worker)
            Flect.Worker.work(proc, cfg)

            Flect.Application.stop()

            recv = fn(recv, acc) ->
                receive do
                    {:flect_stdout, str} -> recv.(recv, acc <> str)
                    {:flect_shutdown, code} -> {acc, code}
                end
            end

            {text, code} = recv.(recv, "")

            check.(file, pass, text, code)
        else
            IO.puts(IO.ANSI.escape("%{blue, bright}skip (#{expr})"))
            nil
        end
    end)
end)

File.cd!(Path.join("..", ".."))

results = List.flatten(results)

test_passes = Enum.count(results, fn(x) -> x end)
test_skips = Enum.count(results, fn(x) -> x == nil end)
test_failures = Enum.count(results, fn(x) -> x == false end)
tests = test_passes + test_failures

IO.puts("")
IO.puts(IO.ANSI.escape_fragment("  %{yellow, bright}#{tests}%{reset} test passes executed, " <>
                                "%{blue, bright}#{test_skips}%{reset} skipped, " <>
                                "%{green, bright}#{test_passes}%{reset} successful, " <>
                                "%{red, bright}#{test_failures}%{reset} failed"))
IO.puts("")

code = if test_failures > 0, do: 1, else: 0

if otp >= 'R16B' && System.get_env("FLECT_COVER") == "1" && code == 0 do
    File.mkdir_p!(dir)

    :cover.export(Path.join(dir, "flect.coverdata") |> to_char_list())

    Enum.each(:cover.modules(), fn(x) ->
        :cover.analyse_to_file(x, Path.join(dir, "#{x}.html") |> to_char_list(), [:html])
    end)
end

System.halt(code)

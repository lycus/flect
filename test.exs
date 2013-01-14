path = Enum.at!(System.argv(), 0)

passes = :file.list_dir(path) |>
         elem(1) |>
         Enum.filter(fn(x) -> File.extname(x) == '.pass' end) |>
         Enum.sort() |>
         Enum.map(fn(x) -> File.join(path, x) end) |>
         Enum.map(fn(x) -> [pass: x |> File.basename() |> File.rootname()] ++ Enum.at!(elem(:file.consult(x), 1), 0) end)

files = :file.list_dir(path) |>
        elem(1) |>
        Enum.filter(fn(x) -> File.extname(x) == '.fl' end) |>
        Enum.map(fn(x) -> list_to_binary(x) end) |>
        Enum.sort()

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
                    IO.puts(ANSI.bright() <> ANSI.red() <> "fail (#{code})" <> ANSI.reset())
                    false
                !exp ->
                    IO.puts(ANSI.bright() <> ANSI.red() <> "fail (exp)" <> ANSI.reset())
                    false
                true ->
                    IO.puts(ANSI.bright() <> ANSI.green() <> "ok (#{code})" <> ANSI.reset())
                    true
            end
        end

        if is_list(pass[:command]) do
            args = Enum.map(pass[:command], fn(arg) ->
                arg |>
                list_to_binary() |>
                String.replace("<file>", file) |>
                String.replace("<name>", File.rootname(file))
            end)

            IO.write("    flect #{args |> Enum.join(" ")} ... ")

            {opts, rest} = Flect.Application.parse(args)

            cfg = Flect.Config[tool: binary_to_atom(Enum.at!(rest, 0)),
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
            cmd = pass[:command] |>
                  list_to_binary() |>
                  String.replace("<file>", file) |>
                  String.replace("<name>", File.rootname(file))

            IO.write("    #{cmd} ... ")

            port = Port.open({:spawn, binary_to_list(cmd)}, [:stream,
                                                             :binary,
                                                             :exit_status,
                                                             :hide])

            recv = fn(recv, port, acc) ->
                receive do
                    {^port, {:data, data}} -> recv.(recv, port, acc <> data)
                    {^port, {:exit_status, code}} -> {acc, code}
                end
            end

            {text, code} = recv.(recv, port, "")

            check.(file, pass, text, code)
        end
    end)
end)

File.cd!(File.join("..", ".."))

results = List.flatten(results)

test_passes = Enum.count(results, fn(x) -> x end)
test_failures = Enum.count(results, fn(x) -> !x end)
tests = test_passes + test_failures

IO.puts("")
IO.puts("  " <> ANSI.bright() <> ANSI.yellow() <> "#{tests}" <> ANSI.reset() <>
        " test passes executed, " <> ANSI.bright() <> ANSI.green() <>
        "#{test_passes}" <> ANSI.reset() <> " successful, " <> ANSI.bright() <> ANSI.red() <>
        "#{test_failures}" <> ANSI.reset() <> " failed")
IO.puts("")

System.halt(if test_failures > 0, do: 1, else: 0)

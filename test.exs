path = Enum.at!(System.argv(), 0)

passes = :file.list_dir(path) />
         elem(1) />
         Enum.filter(fn(x) -> File.extname(x) == '.pass' end) />
         Enum.sort() />
         Enum.map(fn(x) -> File.join(path, x) end) />
         Enum.map(fn(x) -> [pass: x /> File.basename() /> File.rootname()] ++ Enum.at!(elem(:file.consult(x), 1), 0) end)

files = :file.list_dir(path) />
        elem(1) />
        Enum.filter(fn(x) -> File.extname(x) == '.fl' end) />
        Enum.map(fn(x) -> list_to_binary(x) end) />
        Enum.sort()

File.cd!(path)

results = Enum.map(passes, fn(pass) ->
    IO.puts("")
    IO.puts("Testing #{path} (#{pass[:description]})...")
    IO.puts("")

    Enum.map(files, fn(file) ->
        cmd = pass[:command] />
              list_to_binary() />
              String.replace("<flect>", File.join(["..", "..", "flect"])) />
              String.replace("<file>", file) />
              String.replace("<name>", File.rootname(file)) />
              binary_to_list()

        IO.write("#{file}... ")

        port = Port.open({:spawn, cmd}, [:stream,
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

        exp = case File.read(file <> "." <> pass[:pass] <> ".exp") do
            {:ok, data} -> String.strip(text) == String.strip(data)
            {:error, :enoent} -> true
        end

        cond do
            code != pass[:code] ->
                IO.puts("failure (#{code})")
                false
            !exp ->
                IO.puts("failure (output)")
                false
            true ->
                IO.puts("success (#{code})")
                true
        end
    end)
end)

File.cd!(File.join("..", ".."))

results = List.flatten(results)

test_passes = Enum.count(results, fn(x) -> x end)
test_failures = Enum.count(results, fn(x) -> !x end)
tests = test_passes + test_failures

IO.puts("")
IO.puts("#{tests} test passes executed, #{test_passes} successful, #{test_failures} failed")
IO.puts("")

System.halt(if test_failures > 0, do: 1, else: 0)

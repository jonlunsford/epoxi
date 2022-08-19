support_dir = "test/support"
support_dir
|> Path.join("**/*.ex")
|> Path.wildcard()
|> Enum.map(&Code.compile_file/1)

ExUnit.start()

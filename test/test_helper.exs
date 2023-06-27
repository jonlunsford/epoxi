support_dir = "test/support"

support_dir
|> Path.join("**/*.ex")
|> Path.wildcard()
|> Enum.map(&Code.compile_file/1)

exclude = if Node.alive?(), do: [], else: [distributed: true]

ExUnit.start(exclude: exclude)
Epoxi.TestSmtpServer.start(2525)

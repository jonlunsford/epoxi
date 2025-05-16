support_dir = "test/support"

support_dir
|> Path.join("**/*.ex")
|> Path.wildcard()
|> Enum.map(&Code.compile_file/1)

include = Keyword.get(ExUnit.configuration(), :include)

if :distributed in include do
  Epoxi.TestCluster.spawn([:"node1@127.0.0.1", :"node2@127.0.0.1"])
end

Epoxi.TestSmtpServer.start(2525)

ExUnit.start(exclude: [distributed: true])

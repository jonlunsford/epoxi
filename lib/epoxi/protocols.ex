defprotocol Epoxi.Adapter do
  @moduledoc "Protocol for sending adapters to implement"
  def send_blocking(context, email, message)
  # def deliver(config, email, message)
end

defprotocol Epoxi.Compiler do
  @moduledoc "Protocol for compilers to implement"
  def compile(email)
end

defmodule Vexil.Errors do
  defmodule ParseError do
    defexception message: "failed to parse argv"
  end
end

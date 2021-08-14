defmodule Vexil.Errors do
  @moduledoc """
  Module for various errors used throughout Vexil.
  """

  defmodule ArgvError, do: defexception(message: "invalid argv, must be a list of strings")

  defmodule InvalidFlagError, do: defexception([:key, message: "invalid flag given"])
  defmodule InvalidOptionError, do: defexception([:key, message: "invalid option given"])

  defmodule ConflictingKeyError,
    do: defexception([:key, message: "conflicting key between flags and options"])

  defmodule UnknownOptionError, do: defexception([:key, message: "unknown option"])
  defmodule DuplicateOptionError, do: defexception([:key, message: "duplicate option"])

  defmodule InvalidValueError,
    do: defexception([:key, :value, message: "invalid value for option"])

  defmodule RequiredOptionError, do: defexception([:keys, message: "required options missing"])

  defmodule UnknownParserError,
    do:
      defexception([
        :key,
        message: "unknown parser, must be :string, :integer, :float, or a unary function"
      ])

  defmodule UnknownFlagError, do: defexception([:key, message: "unknown flag"])
  defmodule DuplicateFlagError, do: defexception([:key, message: "duplicate flag"])
end

defmodule Vexil.Parsers do
  @moduledoc """
  Module containing default parsers for Vexil.
  """

  @type custom :: (String.t() -> {:ok, any()} | {:error, String.t()})
  @type builtins :: :string | :integer | :float

  def string(input), do: {:ok, input}

  def integer(input) do
    try do
      {:ok, String.to_integer(input)}
    rescue
      _ -> {:error, "expected integer, got `#{input}`"}
    end
  end

  def float(input) do
    try do
      {:ok, String.to_float(input)}
    rescue
      _ -> {:error, "expected float, got `#{input}"}
    end
  end
end

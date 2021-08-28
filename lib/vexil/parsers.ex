defmodule Vexil.Parsers do
  @moduledoc """
  Module containing default parsers for Vexil.
  """

  @type custom :: (list(String.t()), boolean() -> {:ok, any()} | {:error, String.t()})
  @type builtins :: :string | :integer | :float

  def string(input, greedy) do
    if greedy,
      do: {:ok, input},
      else: {:ok, Enum.join(input, " ")}
  end

  def integer(input, greedy) do
    try do
      if greedy,
        do: {:ok, Enum.map(input, &String.to_integer/1)},
        else: {:ok, input |> Enum.map(&String.to_integer/1) |> Enum.at(0)}
    rescue
      _ -> {:error, "expected integer, got `#{input}`"}
    end
  end

  def float(input, greedy) do
    try do
      if greedy,
        do: {:ok, Enum.map(input, &String.to_float/1)},
        else: {:ok, input |> Enum.map(&String.to_float/1) |> Enum.at(0)}
    rescue
      _ -> {:error, "expected float, got `#{input}"}
    end
  end

  defmacro all() do
    quote do
      [:string, :integer, :float]
    end
  end
end

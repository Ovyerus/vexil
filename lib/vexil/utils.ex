defmodule Vexil.Utils do
  @moduledoc false
  alias Vexil.Errors

  @type argv() :: list(String.t())

  @spec split_double_dash(argv(), boolean()) :: {argv(), argv()}
  def split_double_dash(argv, obey \\ true) do
    if obey do
      {argv, remainder} = Enum.split_while(argv, fn x -> x !== "--" end)
      # Slice remainder to remove leading --
      {argv, Enum.slice(remainder, 1..-1)}
    else
      {argv, []}
    end
  end

  def bangify_parse_error(err) do
    case err do
      {:error, :flags_not_keywords} ->
        raise ArgumentError, "flags must be a keyword list"

      {:error, :options_not_keywords} ->
        raise ArgumentError, "options must be a keyword list"

      {:error, :invalid_argv} ->
        raise Errors.ArgvError

      {:error, :invalid_flag, key} ->
        raise Errors.InvalidFlagError,
          key: key,
          message: "invalid flag given '#{key}', must be `Vexil.Structs.Flag`"

      {:error, :invalid_option, key} ->
        raise Errors.InvalidOptionError,
          key: key,
          message: "invalid option given '#{key}', must be `Vexil.Structs.Option`"

      {:error, :required_option_has_default, key} ->
        raise Errors.RequiredOptionHasDefaultError,
          key: key,
          message: "required option '#{key}' has a default value"

      {:error, :conflicting_key, key} ->
        raise Errors.ConflictingKeyError,
          key: key,
          message: "conflicting key '#{key}' given between flags and options"

      {:error, :invalid_parser, key} ->
        raise Errors.InvalidParserError,
          key: key,
          message:
            "invalid parser for option '#{key}', must be :string, :integer, :float, or a unary function"

      {:error, :unknown_option, key} ->
        raise Errors.UnknownOptionError, key: key, message: "unknown option '#{key}'"

      {:error, :duplicate_option, key} ->
        raise Errors.DuplicateOptionError, key: key, message: "duplicate option '#{key}'"

      {:error, :invalid_value, key, value} ->
        raise Errors.InvalidValueError,
          key: key,
          value: value,
          message: "invalid value for option '#{key}'"

      {:error, :missing_required_options, keys} ->
        raise Errors.RequiredOptionError,
          keys: keys,
          message: "missing required options '#{inspect(keys)}'"

      {:error, :unknown_flag, key} ->
        raise Errors.UnknownFlagError, key: key, message: "unknown flag '#{key}'"

      {:error, :duplicate_flag, key} ->
        raise Errors.DuplicateFlagError, key: key, message: "duplicate flag '#{key}'"
    end
  end

  @spec consume_argv_greedy(argv(), argv()) :: {argv(), argv()}
  def consume_argv_greedy(argv, acc \\ []) do
    case argv do
      [] -> {Enum.reverse(acc), argv}
      # Stop on next option starting with a dash because it could be an option
      ["-" <> _ | _] -> {Enum.reverse(acc), argv}
      [head | tail] -> consume_argv_greedy(tail, [head | acc])
    end
  end

  @spec split_eq(String.t(), argv()) :: {String.t(), argv()}
  def split_eq(str, tail) do
    if String.contains?(str, "=") do
      [option, value] = String.split(str, "=", parts: 2)
      {option, [value | tail]}
    else
      {str, tail}
    end
  end
end

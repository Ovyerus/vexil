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

      {:error, :conflicting_key, key} ->
        raise Errors.ConflictingKeyError,
          key: key,
          message: "conflicting key '#{key}' given between flags and options"

      {:error, :unknown_option, key} ->
        raise Errors.UnknownOptionError, key: key, message: "unknown option '#{key}'"

      {:error, :duplicate_option, key} ->
        raise Errors.DuplicateOptionError, key: key, message: "duplicate option '#{key}'"

      {:error, :invalid_value, key, value} ->
        raise Errors.InvalidValueError,
          key: key,
          value: value,
          message: "invalid value '#{value}' for option '#{key}'"

      {:error, :missing_required_options, keys} ->
        raise Errors.RequiredOptionError,
          keys: keys,
          message: "missing required options '#{keys}'"

      {:error, :unknown_parser, key} ->
        raise Errors.UnknownParserError,
          key: key,
          message:
            "unknown parser for option '#{key}', must be :string, :integer, :float, or a unary function"

      {:error, :unknown_flag, key} ->
        raise Errors.UnknownFlagError, key: key, message: "unknown flag '#{key}'"

      {:error, :duplicate_flag, key} ->
        raise Errors.DuplicateFlagError, key: key, message: "duplicate flag '#{key}'"
    end
  end
end

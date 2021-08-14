defmodule Vexil do
  @moduledoc """
  Documentation for `Vexil`.
  """
  alias Vexil.{Errors, Parsers, Structs}

  @type argv() :: list(String.t())
  @type flags() :: list({atom(), Structs.Flags.t()})
  @type options() :: list({atom(), Structs.Options.t()})

  @type found() :: list({:ok | :error, atom(), any()})

  @type validate_argv_error() :: {:error, :invalid_argv}
  @type validate_opts_error() ::
          {:error, :invalid_flag | :invalid_option | :conflicting_key, atom()}

  @type parse_spec_item() ::
          {:flags, flags()}
          | {:options, options()}
          | {:obey_double_dash, boolean()}
          | {:error_early, boolean()}
  @type parse_spec() :: list(parse_spec_item())
  @type parsed_items() :: %{:flags => parsed_flags(), :options => parsed_options(), argv: argv()}
  @type parse_result() ::
          {:ok, parsed_items(), {list(find_options_error()), list(find_flags_error())}}
          | validate_opts_error()
          | validate_argv_error()
          | find_options_error()
          | find_flags_error()

  @type find_options_error() ::
          {:error, :unknown_option, String.t()}
          | {:error, :duplicate_option, atom()}
          | {:error, :invalid_value, atom(), String.t()}
          | {:error, :missing_required_options, list(atom())}
          | {:error, :unknown_parser, atom()}
  @type parsed_options() :: list({atom(), any()})
  @type find_options_result() ::
          {:ok, parsed_options(), list(find_options_error()), argv()} | find_options_error()

  @type find_flags_error() ::
          {:error, :unknown_flag, String.t()}
          | {:error, :duplicate_flag, atom()}
  @type parsed_flags() :: list({atom(), pos_integer() | true})
  @type find_flags_result() ::
          {:ok, parsed_flags(), list(find_flags_error()), argv()}
          | find_flags_error()

  @ungreedy_parsers [:integer, :float]

  @spec parse(argv(), parse_spec()) :: parse_result()
  def parse(argv, opts \\ []) do
    double_dash = Keyword.get(opts, :obey_double_dash, false)
    error_early = Keyword.get(opts, :error_early, false)
    opt_flags = Keyword.get(opts, :flags, [])
    opt_options = Keyword.get(opts, :options, [])

    with :ok <- validate_argv(argv),
         :ok <- validate_opts(opt_flags, opt_options),
         {argv, argv_remainder} <- split_double_dash(argv, double_dash),
         {:ok, options, option_errors, argv} <- find_options(argv, opt_options, error_early),
         {:ok, flags, flag_errors, argv} <- find_flags(argv, opt_flags, error_early) do
      {
        :ok,
        %{flags: flags, options: options, argv: argv ++ argv_remainder},
        {option_errors, flag_errors}
      }
    end
  end

  @spec parse!(argv(), parse_spec()) :: any()
  def parse!(argv, opts \\ []) do
    case Vexil.parse(argv, opts) do
      {:ok, result} -> result
      # TODO: better differentiation if its an input error or what
      {:error, _} -> raise Errors.ParseError
    end
  end

  @spec validate_argv(argv()) :: :ok | validate_argv_error()
  defp validate_argv(argv) when is_list(argv) do
    if Enum.all?(argv, &is_binary/1) do
      :ok
    else
      {:error, :invalid_argv}
    end
  end

  @spec validate_opts(flags(), options()) :: :ok | validate_opts_error()
  defp validate_opts(flags, options) do
    {bad_flag, _} =
      Enum.find(flags, {nil, nil}, fn {_, struct} -> !match?(%Structs.Flag{}, struct) end)

    {bad_option, _} =
      Enum.find(options, {nil, nil}, fn {_, struct} -> !match?(%Structs.Option{}, struct) end)

    flag_keys = Enum.map(flags, fn {key, _} -> key end)
    option_keys = Enum.map(options, fn {key, _} -> key end)
    # TODO: a way to do this without concat? (use a reduce with them in a tuple)
    conflicts =
      (flag_keys ++ option_keys)
      |> Enum.frequencies()
      |> Enum.filter(fn {_, v} -> v != 1 end)
      |> Enum.map(fn {k, _} -> k end)

    cond do
      bad_flag != nil -> {:error, :invalid_flag, bad_flag}
      bad_option != nil -> {:error, :invalid_option, bad_option}
      conflicts != [] -> {:error, :conflicting_key, List.first(conflicts)}
      true -> :ok
    end
  end

  @spec split_double_dash(argv(), boolean()) :: {argv(), argv()}
  defp split_double_dash(argv, obey) do
    if obey do
      {argv, remainder} = Enum.split_while(argv, fn x -> x !== "--" end)
      # Slice remainder to remove leading --
      {argv, Enum.slice(remainder, 1..-1)}
    else
      {argv, []}
    end
  end

  @spec find_options(argv(), options(), boolean(), found(), argv()) ::
          find_options_result()
  defp find_options(argv, wanted_options, error_early, seen_options \\ [], remainder \\ []) do
    consume_option = fn lookup_name, tail, comparison_key ->
      # TODO: need to lookup `flags` as well to make sure we don't error with an `unknown option` despite it existing as a flag
      option = Enum.find(wanted_options, fn {_, opt} -> opt[comparison_key] == lookup_name end)

      {name, option} = option || {nil, nil}

      cond do
        !option ->
          if error_early,
            do: {:error, :unknown_option, lookup_name},
            else: find_options(tail, wanted_options, seen_options, [lookup_name | remainder])

        not option.multiple && seen_options[name] ->
          err = {:error, :duplicate_option, name}

          if error_early,
            do: err,
            else: find_options(tail, wanted_options, [err | seen_options], remainder)

        true ->
          {value, tail} =
            if option.greedy and option.parser not in @ungreedy_parsers do
              consume_argv_greedy(tail)
            else
              [head | tail] = tail
              {head, tail}
            end

          value = Enum.join(value, " ")

          {success, value} =
            case option.parser do
              parser when parser in [:string, :integer, :float] ->
                apply(Parsers, parser, [value])

              # Run custom parser
              parser when is_function(parser) ->
                parser.(value)

              parser ->
                {:error, :unknown_parser, parser}
            end

          result =
            if success == :error,
              do: {:error, :invalid_value, name, value},
              else: {success, name, value}

          if success == :error and error_early,
            do: result,
            else: find_options(tail, wanted_options, [result | seen_options], remainder)
      end
    end

    case argv do
      [] ->
        found_options =
          seen_options
          |> Enum.filter(&match?({:ok, _, _}, &1))
          # Remove leading `:ok` from tuples
          |> Enum.map(&Tuple.delete_at(&1, 0))

        found_names = Enum.map(found_options, &elem(&1, 0))

        all_errors =
          Enum.filter(seen_options, fn
            {:error, _type, _arg0, _arg1} -> true
            {:error, _type, _arg0} -> true
            _ -> false
          end)

        # TODO: merge `multiple` options into the same list item which is `{:ok, list(blah blah)}`

        missing =
          wanted_options
          |> Enum.filter(fn {name, opt} -> opt.required and name not in found_names end)
          |> Enum.map(fn {name, _} -> name end)

        missing = if missing != [], do: {:error, :missing_required_options, missing}, else: nil
        all_errors = if missing, do: [missing | all_errors], else: all_errors

        if error_early and missing do
          missing
        else
          {
            :ok,
            found_options,
            all_errors,
            Enum.reverse(remainder)
          }
        end

      ["--" <> long | tail] ->
        {long, tail} = split_eq(long, tail)
        consume_option.(long, tail, :long)

      ["-" <> short | tail] ->
        {short, tail} = split_eq(short, tail)
        consume_option.(short, tail, :short)

      [head | tail] ->
        find_options(tail, wanted_options, seen_options, [head | remainder])
    end
  end

  @spec find_flags(argv(), flags(), boolean(), found(), argv()) :: find_flags_result()
  defp find_flags(argv, wanted_flags, error_early, seen_flags \\ [], remainder \\ []) do
    consume_flag = fn lookups, tail, comparison_key ->
      results =
        for lookup_name <- lookups do
          flag = Enum.find(wanted_flags, fn {_, opt} -> opt[comparison_key] == lookup_name end)

          {name, flag} = flag || {nil, nil}

          cond do
            !flag ->
              {:error, :unknown_flag, lookup_name}

            not flag.multiple and seen_flags[name] ->
              {:error, :duplicate_flag, name}

            true ->
              {:ok, name, true}
          end
        end

      first_error = Enum.find(results, &match?({:error, _, _}, &1))

      if error_early and first_error,
        do: first_error,
        else: find_flags(tail, wanted_flags, results ++ seen_flags, remainder)
    end

    case argv do
      [] ->
        found_flags =
          seen_flags
          |> Enum.filter(&match?({:ok, _, _}, &1))
          # Get amount of times each name occurs (used for multiple flags like verbosity)
          |> Enum.frequencies_by(&elem(&1, 1))
          |> Enum.map(fn
            {key, 1} ->
              if wanted_flags[key].multiple,
                do: {key, 1},
                else: {key, true}

            x ->
              x
          end)

        all_errors = seen_flags |> Enum.filter(&match?({:error, _type, _arg0}, &1)) |> Enum.uniq()

        {:ok, found_flags, all_errors, Enum.reverse(remainder)}

      ["--" <> long | tail] ->
        consume_flag.([long], tail, :long)

      ["-" <> short | tail] ->
        # Allow grouping short flags together like `-abcdeeee`
        flags = if String.length(short) > 1, do: String.split(short), else: [short]
        consume_flag.(flags, tail, :short)

      [head | tail] ->
        find_flags(tail, wanted_flags, seen_flags, [head | remainder])
    end
  end

  @spec split_eq(String.t(), argv()) :: {String.t(), argv()}
  defp split_eq(str, tail) do
    if String.contains?(str, "=") do
      [option, value] = String.split(str, "=", parts: 2)
      {option, [value | tail]}
    else
      {str, tail}
    end
  end

  @spec consume_argv_greedy(argv(), argv()) :: {argv(), argv()}
  defp consume_argv_greedy(argv, acc \\ []) do
    case argv do
      [] -> {Enum.reverse(acc), argv}
      # Stop on next option starting with a dash because it could be an option
      ["-" <> _ | _] -> {Enum.reverse(acc), argv}
      [head | tail] -> consume_argv_greedy(tail, [head | acc])
    end
  end
end

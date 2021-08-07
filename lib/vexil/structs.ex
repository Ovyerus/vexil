defmodule Vexil.Structs do
  @moduledoc """
  Module containing structs used throughout Vexil.
  """
  use TypedStruct

  typedstruct module: Option do
    @moduledoc """
    A struct used for defining options in Vexil.
    """

    field :short, String.t(), enforce: true
    field :long, String.t(), enforce: true
    field :parser, Vexil.Parsers.custom() | Vexil.Parsers.builtins(), default: :string
    field :required, bool(), default: false
    field :greedy, bool() | pos_integer(), default: false
    field :multiple, bool(), default: false
    field :default, any()
  end

  typedstruct module: Flag do
    @moduledoc """
    A struct used for defining boolean flags in Vexil.
    """

    field :short, String.t(), enforce: true
    field :long, String.t(), enforce: true
    field :multiple, bool(), default: false
  end
end

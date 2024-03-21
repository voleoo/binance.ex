defmodule BinanceFutures.OpenInterest do
  @moduledoc """
  Struct for representing the result returned by /fapi/v1/openInterest

  ```
  defstruct [:symbol, :openInterest, :time]
  ```
  """

  defstruct [:symbol, :openInterest, :time]
  use ExConstructor
end

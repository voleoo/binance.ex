defmodule BinanceFutures.OpenInterestHist do
  @moduledoc """
  Struct for representing the result returned by /futures/data/openInterestHist

  ```
  defstruct [:symbol, :sumOpenInterest, :sumOpenInterestValue, :timestamp]
  ```
  """

  defstruct [:symbol, :sumOpenInterest, :sumOpenInterestValue, :timestamp]
  use ExConstructor
end

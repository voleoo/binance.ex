defmodule BinanceFutures.Rest.HTTPClient do
  # import Binance.Rest.HTTPClient

  @endpoint Application.get_env(:binance, :futures_end_point, "https://fapi.binance.com")

  def get_binance(url, headers \\ []) do
    HTTPoison.get("#{@endpoint}#{url}", headers)
    |> parse_response
  end

  def delete_binance(url, headers \\ []) do
    HTTPoison.delete("#{@endpoint}#{url}", headers)
    |> parse_response
  end

  def get_binance(url, params, secret_key, api_key) do
    case prepare_request(url, params, secret_key, api_key) do
      {:error, _} = error ->
        error

      {:ok, url, headers} ->
        get_binance(url, headers)
    end
  end

  def delete_binance(url, params, secret_key, api_key) do
    case prepare_request(url, params, secret_key, api_key) do
      {:error, _} = error ->
        error

      {:ok, url, headers} ->
        delete_binance(url, headers)
    end
  end

  defp prepare_request(url, params, secret_key, api_key) do
    case validate_credentials(secret_key, api_key) do
      {:error, _} = error ->
        error

      _ ->
        headers = [{"X-MBX-APIKEY", api_key}]
        receive_window = 5000
        ts = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

        params =
          Map.merge(params, %{
            timestamp: ts,
            recvWindow: receive_window
          })

        argument_string = URI.encode_query(params)

        signature =
          generate_signature(
            :sha256,
            secret_key,
            argument_string
          )
          |> Base.encode16()

        {:ok, "#{url}?#{argument_string}&signature=#{signature}", headers}
    end
  end

  def signed_request_binance(url, params, method) do
    argument_string =
      params
      |> prepare_query_params()

    # generate signature
    signature =
      generate_signature(
        :sha256,
        Application.get_env(:binance, :secret_key),
        argument_string
      )
      |> Base.encode16()

    body = "#{argument_string}&signature=#{signature}"

    case apply(HTTPoison, :request, [
           method,
           "#{@endpoint}#{url}?#{body}",
           "",
           [
             {"X-MBX-APIKEY", Application.get_env(:binance, :api_key)}
           ],
           []
         ]) do
      {:error, err} ->
        {:error, {:http_error, err}}

      {:ok, response} ->
        case Poison.decode(response.body) do
          {:ok, data} -> {:ok, data}
          {:error, err} -> {:error, {:poison_decode_error, err}}
        end
    end
  end

  @doc """
  You need to send an empty body and the api key
  to be able to create a new listening key.

  """
  def unsigned_request_binance(url, data, method) do
    headers = [
      {"X-MBX-APIKEY", Application.get_env(:binance, :api_key)}
    ]

    case do_unsigned_request(url, data, method, headers) do
      {:error, err} ->
        {:error, {:http_error, err}}

      {:ok, response} ->
        case Poison.decode(response.body) do
          {:ok, data} -> {:ok, data}
          {:error, err} -> {:error, {:poison_decode_error, err}}
        end
    end
  end

  defp do_unsigned_request(url, nil, method, headers) do
    apply(HTTPoison, method, [
      "#{@endpoint}#{url}",
      headers
    ])
  end

  defp do_unsigned_request(url, data, :get, headers) do
    argument_string =
      data
      |> prepare_query_params()

    apply(HTTPoison, :get, [
      "#{@endpoint}#{url}" <> "?#{argument_string}",
      headers
    ])
  end

  defp do_unsigned_request(url, body, method, headers) do
    apply(HTTPoison, method, [
      "#{@endpoint}#{url}",
      body,
      headers
    ])
  end

  defp validate_credentials(nil, nil),
    do: {:error, {:config_missing, "Secret and API key missing"}}

  defp validate_credentials(nil, _api_key),
    do: {:error, {:config_missing, "Secret key missing"}}

  defp validate_credentials(_secret_key, nil),
    do: {:error, {:config_missing, "API key missing"}}

  defp validate_credentials(_secret_key, _api_key),
    do: :ok

  defp parse_response({:ok, response}) do
    response.body
    |> Poison.decode()
    |> parse_response_body
  end

  defp parse_response({:error, err}) do
    {:error, {:http_error, err}}
  end

  defp parse_response_body({:ok, data}) do
    case data do
      %{"code" => _c, "msg" => _m} = error -> {:error, error}
      _ -> {:ok, data}
    end
  end

  defp parse_response_body({:error, err}) do
    {:error, {:poison_decode_error, err}}
  end

  defp prepare_query_params(params) do
    params
    |> Map.to_list()
    |> Enum.map(fn x -> Tuple.to_list(x) |> Enum.join("=") end)
    |> Enum.join("&")
  end

    # TODO: remove when we require OTP 22.1
    if Code.ensure_loaded?(:crypto) and function_exported?(:crypto, :mac, 4) do
      defp generate_signature(digest, key, argument_string), do: :crypto.mac(:hmac, digest, key, argument_string)
    else
      defp generate_signature(digest, key, argument_string), do: :crypto.hmac(digest, key, argument_string)
    end
end

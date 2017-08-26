defmodule Metexopt.Worker do
  @moduledoc """
  Worker using GenServer
  """
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def get_temperature(pid, location) do
    GenServer.call(pid, {:location, location})
  end

  def handle_call({:location, location}, _from, stats) do
    case temperature_of(location) do
      {:ok, location} ->
        new_stats = update_stats(stats, location)
        {:reply, "#{temp}", new_stats}
      _ ->
        {:reply, :error, stats}
    end
  end

  def handle_call(:get_stats, _from, stats) do
    {:reply, stats, stats}
  end

  def handle_cast(:reset_stats, _stats) do
    {:noreply, %{}}
  end

  def update_stats(old_stats, location) do
    case Map.has_key?(old_stats, location) do
      true  -> Map.update(old_stats, location, &(&1 + 1))
      false -> Map.put(old_stats, location, 1)
    end
  end

  def get_stats(pid) do
    GenServer.call(pid, :get_stats)
  end

  def reset_stats(pid) do
    GenServer.cast(pid, :reset_stats)
  end

  defp temperature_of(location) do
    location |> url_for |> HTTPoison.get |> parse_response
  end

  defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
    body |> Poison.decode! |> compute_temperature
  end

  defp parse_response(_) do
    :error
  end

  defp compute_temperature(response_json) do
    temp = (response_json["main"]["temp"] * 1.8 - 459.67) |> Float.round(1)
    {:ok, temp}
    rescue
      _ -> :error
  end

  defp url_for(location) do
    "http://api.openweathermbap.org/data/2.5/weather?q=#{location}&APPID=#{api_key()}"
  end

  defp api_key do
    Application.get_env(:metexopt, :api_key)
  end
end

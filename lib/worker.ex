defmodule Metexotp.Worker do
  @moduledoc """
  Implementation of weather app using Genserver
  """
  use GenServer

  # CLIENT API

  @doc """
  Starts the process and links the server process to the parent process
  When called, invokes `Metexotp.init/1` and waits until `Metexotp.init/1` has returned before returning
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Makes synchronous request to the server
  `Genserver.call/3` expects a `handle_call/3` and invokes it accordingly
  """
  def get_temperature(pid, location), do: GenServer.call(pid, {:location, location})

  @doc """
  Makes call to get stats by invoking `handle_call/3`
  """
  def get_stats(pid), do: GenServer.call(pid, :get_stats)

  def reset_stats(pid), do: GenServer.cast(pid, :reset_stats)


  # SERVER API

  @doc """
  Arguments
  * the expected request to be handled (`atom()`)
  * `{pid, tag}`
    * `pid` is the pid of the client
    * `tag` is a unique reference to the message

  Valid Responses
  * `{:reply, reply, state}`
  * `{:reply, reply, state, timeout}`
  * `{:reply, reply, state, :hibernate}`
  * `{:noreply, state}`
  * `{:noreply, state, timeout}`
  * `{:noreply, state, hibernate}`
  * `{:stop, reason, reply, state}`
  * `{:stop, reason, state}`
  """
  def handle_call({:location, location}, _from, stats) do
    case temperature_of(location) do
      {:ok, temp} ->
        new_stats = update_stats(stats, location)
        {:reply, "#{location}: #{temp}°C", new_stats}
      _ ->
        {:reply, "Unable to find temperature for #{location}", stats}
    end
  end

  def handle_call(:get_stats, _from, stats), do: {:reply, stats, stats}

  def handle_cast(:reset_stats, _stats), do: {:noreply, %{}}


  # SERVER CALLBACKS

  @doc """
  Valid return values for `init/1`:
  * `{:ok, state}`
  * `{:ok, state, timeout}`
  * `:ignore`
  * `{:stop, reason}`
  """
  def init(:ok) do
    {:ok, %{}}
  end


  # HELPER FUNCTIONS

  defp temperature_of(location) do
    url_for(location) |> HTTPoison.get |> parse_response
  end

  defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
    body |> Poison.decode! |> compute_temperature
  end

  defp parse_response(_), do: :error

  defp compute_temperature(json) do
    try do
      temp = (json["main"]["temp"] - 273.15) |> Float.round(1)
      {:ok, temp}
    rescue
      _ -> :error
    end
  end

  defp url_for(location) do
    location = URI.encode(location)
    "http://api.openweathermap.org/data/2.5/weather?q=#{location}&appid=#{api_key()}"
  end

  def api_key, do: Application.get_env(:metexotp, :api_key)

  defp update_stats(old_stats, location) do
    case Map.has_key?(old_stats, location) do
      true  -> Map.update!(old_stats, location, &(&1 + 1))
      false -> Map.put_new(old_stats, location, 1)
    end
  end
end

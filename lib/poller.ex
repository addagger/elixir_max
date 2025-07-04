defmodule MAX.Poller do

  defmacro __using__([bot_module | opts]) do
    quote(location: :keep) do
      defmodule Poller do
        alias __MODULE__.PollerTask, as: PollerTask

        use Supervisor, restart: :transient

        def start_link(_) do
          with {:ok, %{"subscriptions" => [_head | _tail] = subscriptions}} <- unquote(bot_module).get("/subscriptions") do
            urls = subscriptions |> Enum.map(fn s -> s["url"] end) |> Enum.join("; ")
            Logger.info("Running #{unquote(bot_module)} in webhook mode for url(s): #{urls}")
            :ignore
          else
            _ -> Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
          end
        end

        @impl true
        def init(_) do
          children = [
            Supervisor.child_spec({PollerTask, unquote(bot_module)}, id: __MODULE__)
          ]
          Supervisor.init(children, strategy: :one_for_one)
        end
        
        def stop do
          Supervisor.stop(__MODULE__, :shutdown)
          Logger.info("#{inspect(__MODULE__)} stopped.")
        end

        defmodule PollerTask do
          require Logger

          use Task, restart: :permanent

          def start_link(bot_module) do
            Task.start_link(__MODULE__, :run, [bot_module])
          end

          def run(bot_module) do
            Logger.metadata(bot: bot_module)
            Logger.info("Running #{inspect(bot_module)} in polling mode")

            query = [timeout: unquote(opts[:timeout])]
            query = if marker = read_marker_tmp(), do: Keyword.put(query, :marker, marker), else: query
            query = if unquote(opts[:limit]), do: Keyword.put(query, :limit, unquote(opts[:limit])), else: query
            query = if unquote(opts[:types]), do: Keyword.put(query, :types, Enum.join(unquote(opts[:types]), ",")), else: query

            loop(bot_module, query)
          end

          defp loop(bot_module, query \\ []) do
            with {:ok, resp} <- bot_module.get("/updates", query),
                 %{"marker" => marker, "updates" => updates} <- resp do
              next_marker = marker + 1
              write_marker_tmp(next_marker)

              if unquote(opts[:inspect_updates]) do
                Logger.info("#{inspect(bot_module)} updates received (next marker: #{next_marker})")
                IO.inspect(updates)
              end

              Enum.each(updates, fn update ->
                MAX.Session.handle_update(bot_module, update, unquote(opts[:session_timeout]))
              end)
              loop(bot_module, Keyword.put(query, :marker, next_marker))
            else
              {:error, :timeout} ->
                loop(bot_module, query)
              _ ->
                Process.sleep(1000)
                loop(bot_module, query)
            end
          end

          defp write_marker_tmp(marker) do
            File.write(unquote(opts[:tmp_file]), :erlang.term_to_binary(marker))
          end

          defp read_marker_tmp do
            with {:ok, binary} <- File.read(unquote(opts[:tmp_file])) do
              binary |> :erlang.binary_to_term
            else
              _ -> nil
            end
          end

        end
      end

    end

  end
end

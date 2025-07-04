defmodule MAX.Bot do

  defmacro __using__(_opts) do
    bot_module = __CALLER__.module

    config = Application.get_env(:elixir_max, bot_module)

    token = config |> get_in([:token])

    base_url = config |> get_in([:base_url]) || "https://botapi.max.ru"

    max_retries = config |> get_in([:max_retries]) || 5

    finch_specs = (config |> get_in([:finch_specs]) || [
      name: Module.concat(bot_module, Finch),
      pools: %{
        :default => [size: 500, count: 1],
        base_url => [size: 500, count: 1, start_pool_metrics?: true]
      }
    ]) |> Macro.escape

    finch_name = config |> get_in([:finch_name]) || finch_specs[:name]

    uploader_chunk_size = config |> get_in([:uploader, :chunk_size]) || 65536

    uploader_max_retries = config |> get_in([:uploader, :max_retries]) || 15

    max_sessions = config |> get_in([:max_sessions]) || :infinity

    session_timeout = config |> get_in([:session_timeout]) || 60

    poller_tmp_file = config |> get_in([:poller, :tmp_file]) || MAX.Helper.tmp_file(bot_module, token, "poller_marker")

    poller_limit = config |> get_in([:poller, :limit]) || nil

    poller_timeout = config |> get_in([:poller, :timeout]) || 30

    poller_types = config |> get_in([:poller, :types]) || nil

    poller_inspect_updates = config |> get_in([:poller, :inspect_updates]) || false

    webhook_path = config |> get_in([:webhook, :path]) || MAX.Helper.webhook_path(bot_module, token)

    quote(location: :keep) do
      alias MAX.Types

      require Logger

      use MAX.Registry

      use MAX.Api, [
        token: unquote(token),
        base_url: unquote(base_url),
        max_retries: unquote(max_retries),
        finch_name: unquote(finch_name)
      ]

      use MAX.Uploader, [
        chunk_size: unquote(uploader_chunk_size),
        max_retries: unquote(uploader_max_retries),
        finch_name: unquote(finch_name)
      ]

      use MAX.SessionSupervisor, max_sessions: unquote(max_sessions)

      use MAX.Poller, [
        unquote(bot_module),
        tmp_file: unquote(poller_tmp_file),
        limit: unquote(poller_limit),
        timeout: unquote(poller_timeout),
        types: unquote(poller_types),
        inspect_updates: unquote(poller_inspect_updates),
        session_timeout: unquote(session_timeout)
      ]

      use MAX.Router, [
        unquote(bot_module),
        session_timeout: unquote(session_timeout),
        webhook_path: unquote(webhook_path)
      ]

      use Supervisor

      def start_link(_opts) do
        Supervisor.start_link(__MODULE__, _opts, name: __MODULE__)
      end

      @impl true
      def init(_opts) do
        Logger.info("Starting #{inspect(__MODULE__)} (MAX Messenger Bot)")
        children = [
          unquote(bot_module).Registry,
          unquote(bot_module).SessionSupervisor,
          unquote(bot_module).Poller
        ]

        children =
          if unquote(finch_name) == unquote(finch_specs[:name]) do
            children |> List.insert_at(1, {Finch, unquote(finch_specs)})
          else
            children
          end

        Supervisor.init(children, strategy: :one_for_one)
      end

      alias __MODULE__.Api, as: Api
      alias __MODULE__.Uploader, as: Uploader

      ## Front UI ##

      @spec get(String.t()) :: {:ok, any()} | {:error, any()}
      def get(url), do: Api.fetch(:get, url)

      @spec get(String.t(), keyword()) :: {:ok, any()} | {:error, any()}
      def get(url, query), do: Api.fetch(:get, url, query)

      @spec post(String.t(), map() | binary()) :: {:ok, any()} | {:error, any()}
      def post(url, body), do: Api.fetch(:post, url, body)

      @spec post(String.t(), map() | binary(), keyword()) :: {:ok, any()} | {:error, any()}
      def post(url, body, query), do: Api.fetch(:post, url, body, query)

      @spec put(String.t(), map() | binary()) :: {:ok, any()} | {:error, any()}
      def put(url, body), do: Api.fetch(:put, url, body)

      @spec post(String.t(), map() | binary(), keyword()) :: {:ok, any()} | {:error, any()}
      def put(url, body, query), do: Api.fetch(:put, url, body, query)

      @spec patch(String.t(), map() | binary()) :: {:ok, any()} | {:error, any()}
      def patch(url, body), do: Api.fetch(:patch, url, body)

      @spec patch(String.t(), map() | binary(), keyword()) :: {:ok, any()} | {:error, any()}
      def patch(url, body, query), do: Api.fetch(:patch, url, body, query)

      @spec delete(String.t()) :: {:ok, any()} | {:error, any()}
      def delete(url), do: Api.fetch(:delete, url)

      @spec delete(String.t(), keyword()) :: {:ok, any()} | {:error, any()}
      def delete(url, query), do: Api.fetch(:delete, url, query)

      # https://dev.max.ru/docs-api/methods/POST/uploads
      @spec upload(Types.file_or_content(), String.t()) :: {:ok, any()} | {:error, any()}
      def upload(file_or_content, type) do
        # type: "image" "video" "audio" "file"
        with {:ok, %{"url" => url} = api_resp} <- post("/uploads", type: type) do
          with {:ok, upload_resp} <- Uploader.upload(url, file_or_content) do
            if Map.has_key?(api_resp, "token") do
              {:ok, %{"token" => api_resp["token"]}}
            else
              {:ok, upload_resp}
            end
          end
        end
      end

      @spec upload_attachment(Types.file_or_content(), String.t()) :: {:ok, any()} | {:error, any()}
      def upload_attachment(file_or_content, type) do
        # type: "image" "video" "audio" "file"
        with {:ok, upload_resp} <- upload(file_or_content, type) do
          %{type: type, payload: upload_resp}
        else
          _ -> %{}
        end
      end

      ## Behaviour callbacks ##

      @spec handle_update(Types.update(), Types.bot_state()) :: Types.callback_result()
      def handle_update(update, bot_state) do
        inspect(update) |> Logger.info(bot_module: __MODULE__)
        text = "Define function <code>handle_update/2</code> in module <code>#{inspect(__MODULE__)}</code> and create the best chat bot ever for a great good!"
        text |> IO.puts
        chat_id = MAX.Helper.extract_chat_id(update)
        post("/messages", %{text: "Hello world!\n" <> text, format: "html"}, chat_id: chat_id)
        {:ok, bot_state}
      end

      @spec handle_timeout(Types.session_key(), Types.bot_state()) :: Types.callback_result()
      def handle_timeout(_session_key, bot_state) do
        {:stop, bot_state}
      end

      @spec handle_info(String.t(), Types.session_key(), Types.bot_state()) :: Types.callback_result()
      def handle_info(msg, _session_key, bot_state) do
        Logger.info(msg)
        {:ok, bot_state}
      end

      @spec handle_error(struct(), Exception.Types.stacktrace(), Types.session_key(), Types.update(), Types.bot_state()) :: Types.callback_result()
      def handle_error(_error, _stacktrace, _session_key, _update, bot_state) do
        {:stop, bot_state}
      end

      # Default session_key is {:chat_id, chat_id}
      @spec session_key(Types.update()) :: Types.session_key()
      def session_key(update) do
        chat_id = MAX.Helper.extract_chat_id(update)
        {:chat_id, chat_id}
      end

      defoverridable handle_update: 2, handle_timeout: 2, handle_info: 3, handle_error: 5, session_key: 1

    end
  end

end
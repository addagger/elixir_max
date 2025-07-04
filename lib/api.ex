defmodule MAX.Api do
  require Logger

  defmacro __using__(opts) do
    quote(location: :keep) do
      defmodule Api do
        require Logger

        def client do
          Tesla.client([
            {Tesla.Middleware.BaseUrl, unquote(opts[:base_url])},
            {Tesla.Middleware.Retry, max_retries: unquote(opts[:max_retries]),
               should_retry: fn
                 {:ok, %{status: status}}, _env, _context when status in [400, 500] -> true
                 {:ok, %{status: status}}, _env, _context when status in [429] ->
                   Logger.warning("API MAX throttling, HTTP 429 'Too Many Requests'")
                   true
                 {:ok, _reason}, _env, _context -> false
                 # {:error, _reason}, %Tesla.Env{method: :post}, _context -> false
                 # {:error, _reason}, %Tesla.Env{method: :put}, %{retries: 2} -> false
                 {:error, _reason}, _env, _context -> true
               end},

            Tesla.Middleware.JSON,
          ], {Tesla.Adapter.Finch, name: unquote(opts[:finch_name])})
        end

        # Коды ответов HTTP
        #
        # 200 — успешная операция
        # 400 — недействительный запрос
        # 401 — ошибка аутентификации
        # 404 — ресурс не найден
        # 405 — метод не допускается
        # 429 — превышено количество запросов
        # 503 — сервис недоступен

        def fetch(method, url, body, query) when is_list(query), do: fetch(method: method, url: url, body: body, query: query)
        def fetch(method, url, query) when is_list(query), do: fetch(method: method, url: url, query: query)
        def fetch(method, url, body), do: fetch(method: method, url: url, body: body)
        def fetch(method, url), do: fetch(method: method, url: url)
        def fetch(args) do
          args = args |> Keyword.put(:query, Keyword.put_new(args[:query]||[], :access_token, unquote(opts[:token])))

          with {:ok, %Tesla.Env{status: status, body: body}} <- Tesla.request(client(), args) do
            if status in (200..299) do
              {:ok, body}
            else
              comment = case status do
                400 -> "Invalid request"
                401 -> "Authentication error"
                404 -> "Resource not found"
                405 -> "Method not allowed"
                # 429 -> "Request limit exceeded"
                503 -> "Service unavailable"
                _ -> "Unknown error"
              end
              Logger.warning("API MAX error requesting #{fetch_args_info(args)} responded HTTP #{status}: '#{comment}'\nResponse body: #{inspect(body)}")
              {:error, body}
            end
          else
            {:error, :timeout} -> {:error, :timeout}
            {:error, error} ->
              Logger.warning("API MAX connection error #{fetch_args_info(args)}: #{inspect(error)}")
              {:error, error}
          end
        end

        def fetch_args_info(args) do
          "#{args[:method] |> to_string |> String.upcase} #{args[:url]} #{Keyword.filter(args[:query], fn {key, _val} -> key != :access_token end) |> inspect}"
        end
      end

    end
  end

end
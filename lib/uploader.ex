defmodule MAX.Uploader do

  defmacro __using__(opts) do
    quote(location: :keep) do
      defmodule Uploader do
        require Logger

        def client do
          Tesla.client([
            {Tesla.Middleware.Retry, max_retries: unquote(opts[:max_retries]),
               should_retry: fn
                 {:ok, %{status: status}}, _env, _context when status in [400, 500] ->
                   true
                 {:ok, %{status: status}}, %Tesla.Env{headers: headers}, _context when status in [416] ->
                   Logger.info("API MAX UPLOADER error #{status}, trying restore session from range request #{Enum.find(headers, fn {name, _v} -> name == "Content-Range" end) |> inspect}")
                   true
                 {:ok, %{status: status}}, _env, _context when status in [429] ->
                   Logger.warning("API MAX UPLOADER throttling, HTTP 429 'Too Many Requests'")
                   true
                 {:ok, _reason}, _env, _context -> false
                 # {:error, _reason}, %Tesla.Env{method: :post}, _context -> false
                 # {:error, _reason}, %Tesla.Env{method: :put}, %{retries: 2} -> false
                 {:error, _reason}, _env, _context -> true
               end},

            Tesla.Middleware.DecodeJson,
          ], {Tesla.Adapter.Finch, name: unquote(opts[:finch_name])})
        end

        def upload(url, {:file, path}) do
          with %{size: size} <- File.stat!(path) do
            stream = File.stream!(path, unquote(opts[:chunk_size]))
            upload(url, stream, Path.basename(path), size)
          end
        end

        def upload(url, {:file_content, blob, filename}) do
          with {:ok, stream} <- StringIO.open(blob) do
            stream = stream |> IO.binstream(unquote(opts[:chunk_size]))
            upload(url, stream, filename, byte_size(blob))
          end
        end

        def upload(url, stream, filename, size) do
          {_, res} =
            Enum.reduce_while(stream, {-1, nil}, fn chunk, {prev_chunk, _resp_body} ->
              start_bite = prev_chunk+1
              end_bite = prev_chunk+byte_size(chunk)
              headers = [
                {"Content-Type", "application/octet-stream"},
                {"Content-Disposition", "attachment; filename=\"#{filename}\""},
                {"Content-Range", "bytes #{start_bite}-#{end_bite}/#{size}"}
              ]
              with {:ok, %Tesla.Env{status: status, body: body}} <- Tesla.post(client(), url, chunk, headers: headers) do
                case status do
                  200 -> {:cont, {end_bite, {:ok, body}}}
                  201 -> {:cont, {end_bite, {:ok, nil}}}
                  _ ->
                    Logger.warning("API MAX UPLOADER responds status #{status} while sending #{filename} (#{size} bytes) to #{url}\nResponse body: #{inspect(body)}")
                    {:halt, {prev_chunk, {:error, status}}}
                end
              else
                error ->
                  Logger.warning("API MAX UPLOADER responds error while sending #{filename} (#{size} bytes) to #{url}: #{error}")
                  {:halt, {prev_chunk, error}}
              end
            end)
          res
        end

        #
        # def upload(url, {:file, path}) do
        #   with %{size: size} <- File.stat!(path) do
        #     stream = File.stream!(path, unquote(opts[:chunk_size])) |> Stream.map(fn chunk -> chunk end)
        #     upload(url, stream, Path.basename(path), size)
        #   end
        # end
        #
        # def upload(url, {:file_content, blob, filename}) do
        #   with {:ok, pid} <- StringIO.open(blob) do
        #     stream = IO.binstream(pid, unquote(opts[:chunk_size])) |> Stream.map(fn chunk -> chunk end)
        #     upload(url, stream, filename, byte_size(blob))
        #   end
        # end
        #
        # def upload(url, stream, filename, size) do
        #   headers = [
        #     {"Content-Type", "application/octet-stream"},
        #     {"Content-Length", size},
        #     {"Transfer-Encoding", "chunked"},
        #     {"Content-Disposition", "attachment; filename=\"#{filename}\""},
        #     {"Content-Range", "bytes 0-#{size-1}/#{size}"}
        #   ]
        #   with {:ok, %Tesla.Env{status: 200} = tesla_env} <- Tesla.post(client(), url, stream, headers: headers) |> dbg do
        #     {:ok, tesla_env.body}
        #   else
        #     {:ok, %Tesla.Env{status: status}} ->
        #       Logger.warning("API MAX UPLOADER responds status #{status} while sending #{filename} (#{size} bytes) to #{url}")
        #       {:error, status}
        #     {:error, error} ->
        #       Logger.warning("API MAX UPLOADER responds error while sending #{filename} (#{size} bytes) to #{url}: #{error}")
        #       {:error, error}
        #   end
        # end
        #
        #

      end

    end
  end

end
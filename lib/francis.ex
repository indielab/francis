defmodule Francis do
  import Plug.Conn

  defmacro __using__(opts \\ []) do
    quote location: :keep do
      use Application

      def start(_type, _args) do
        children = [
          {Bandit, [plug: __MODULE__] ++ Keyword.get(unquote(opts), :bandit_opts, [])}
        ]

        Supervisor.start_link(children, strategy: :one_for_one)
      end

      defoverridable(start: 2)

      defp handle_resp(handler, conn, status \\ 200) do
        case handler.(conn) do
          res when is_struct(res, Plug.Conn) ->
            res

          res when is_binary(res) ->
            conn
            |> send_resp(status, res)
            |> halt()

          res when is_map(res) or is_list(res) ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(status, Jason.encode!(res))
            |> halt()
        end
      end

      use Francis.Plug.Router

      plug(:match)

      Enum.map(Keyword.get(unquote(opts), :plugs, []), fn
        plug when is_atom(plug) -> plug(plug)
        {plug, opts} when is_atom(plug) -> plug(plug, opts)
      end)

      plug(:dispatch)
    end
  end

  defmacro get(path, handler) do
    quote location: :keep do
      Plug.Router.get(unquote(path), do: handle_resp(unquote(handler), var!(conn)))
    end
  end

  defmacro post(path, handler) do
    quote location: :keep do
      Plug.Router.post(unquote(path), do: handle_resp(unquote(handler), var!(conn)))
    end
  end

  defmacro put(path, handler) do
    quote location: :keep do
      Plug.Router.put(unquote(path), do: handle_resp(unquote(handler), var!(conn)))
    end
  end

  defmacro delete(path, handler) do
    quote location: :keep do
      Plug.Router.delete(unquote(path), do: handle_resp(unquote(handler), var!(conn)))
    end
  end

  defmacro patch(path, handler) do
    quote location: :keep do
      Plug.Router.patch(unquote(path), do: handle_resp(unquote(handler), var!(conn)))
    end
  end

  defmacro ws(path, handler) do
    module_name =
      path
      |> URI.parse()
      |> then(& &1.path)
      |> then(&String.split(&1, "/"))
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(".")
      |> then(&"#{__MODULE__}.#{&1}")
      |> String.to_atom()

    handler_ast =
      quote do
        defmodule unquote(module_name) do
          require WebSockAdapter

          require Logger
          def init(_opts), do: {:ok, %{}}

          def handle_in(message, state) do
            case unquote(handler).(elem(message, 0)) do
              res when is_binary(res) ->
                {:push, [{:text, res}], state}

              res when is_map(res) ->
                {:push, [{:text, Jason.encode!(res)}], state}
            end
          rescue
            e ->
              Logger.error("WS Handler error: #{inspect(e)} ")
              {:stop, :error, e}
          end

          def terminate(reason, state) do
            Logger.info("WS Handler terminated: #{inspect(reason)} ")
            :ok
          end
        end
      end

    Code.compile_quoted(handler_ast)

    quote location: :keep do
      get(unquote(path), fn conn ->
        var!(conn)
        |> WebSockAdapter.upgrade(unquote(module_name), [], timeout: 60_000)
        |> halt()
      end)
    end
  end

  defmacro unmatched(handler) do
    quote location: :keep do
      match _ do
        handle_resp(unquote(handler), var!(conn), 404)
      end
    end
  end
end

defmodule FrancisTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Francis

  describe "get/1" do
    test "returns a response with the given body" do
      handler = quote do: get("/", fn _ -> "test" end)
      mod = Support.RouteTester.generate_module(handler)

      assert Req.get!("/", plug: mod).body == "test"
    end
  end

  describe "post/1" do
    test "returns a response with the given body" do
      handler = quote do: post("/", fn _ -> "test" end)
      mod = Support.RouteTester.generate_module(handler)

      assert Req.post!("/", plug: mod).body == "test"
    end
  end

  describe "put/1" do
    test "returns a response with the given body" do
      handler = quote do: put("/", fn _ -> "test" end)
      mod = Support.RouteTester.generate_module(handler)

      assert Req.put!("/", plug: mod).body == "test"
    end
  end

  describe "delete/1" do
    test "returns a response with the given body" do
      handler = quote do: delete("/", fn _ -> "test" end)
      mod = Support.RouteTester.generate_module(handler)

      assert Req.delete!("/", plug: mod).body == "test"
    end
  end

  describe "patch/1" do
    test "returns a response with the given body" do
      handler = quote do: patch("/", fn _ -> "test" end)
      mod = Support.RouteTester.generate_module(handler)

      assert Req.patch!("/", plug: mod).body == "test"
    end
  end

  describe "ws/1" do
    test "returns a response with the given body" do
      parent_pid = self()

      handler =
        quote do:
                ws("ws", fn "test" ->
                  send(unquote(parent_pid), {:handler, "received"})
                  "reply"
                end)

      mod = Support.RouteTester.generate_module(handler)

      {:ok, francis_pid} = mod.start([], [])
      {:ok, tester_pid} = Support.WsTester.start("ws://localhost:4000/ws", parent_pid)
      WebSockex.send_frame(tester_pid, {:binary, "test"})

      assert_receive {:client, "reply"}, 5000
      assert_receive {:handler, "received"}, 5000

      on_exit(fn ->
        Process.exit(francis_pid, :normal)
        Process.exit(tester_pid, :normal)
      end)

      :ok
    end
  end

  describe "unmatched/1" do
    test "returns a response with the given body" do
      handler = quote do: unmatched(fn _ -> "test" end)

      mod = Support.RouteTester.generate_module(handler)
      response = Req.get!("/", plug: mod)

      assert response.body == "test"
      assert response.status == 404
    end
  end

  describe "plug usage" do
    test "uses given plug by given order" do
      handler =
        quote do: get("/", fn %{assigns: %{plug_assgined: plug_assgined}} -> plug_assgined end)

      plug1 = {Support.PlugTester, to_assign: "plug1"}
      plug2 = {Support.PlugTester, to_assign: "plug2"}

      mod = Support.RouteTester.generate_module(handler, plugs: [plug1, plug2])
      assert Req.get!("/", plug: mod).body == ["plug1", "plug2"]
    end
  end

  describe "non matching routes without unmatched handler" do
    test "returns an log error with the method and path of the failed route" do
      mod = Support.RouteTester.generate_module(quote do: get("/", fn _ -> "test" end))

      assert capture_log(fn -> Req.get!("/not_here", plug: mod) end) =~
               "Failed to match route: GET /not_here"
    end
  end

  describe "static configuration" do
    test "returns a static file" do
      handler = quote do: unmatched(fn _ -> "" end)

      mod =
        Support.RouteTester.generate_module(handler,
          static: [at: "/", from: "test/support/priv/static/"]
        )

      assert Req.get!("/app.css", plug: mod).status == 200
    end

    test "returns a 404 for non-existing static file" do
      handler = quote do: unmatched(fn _ -> "" end)

      mod =
        Support.RouteTester.generate_module(handler,
          static: [at: "/", from: "test/support/static"]
        )

      assert Req.get!("/not_found.txt", plug: mod).status == 404
    end
  end
end

defmodule GameOfLifeWeb.GameLive do
  use Phoenix.LiveView
  @topic "game"
  @default_size 10
  @default_grid for(_ <- 1..@default_size, do: 0)
                |> List.duplicate(@default_size)
                |> Conway.Grid.new()
  def mount(_params, _session, socket) do
    GameOfLifeWeb.Endpoint.subscribe(@topic)

    {
      :ok,
      assign(
        socket,
        grid_size: @default_size,
        grid_data: @default_grid,
        game_state: :stopped,
        gen_prob: 5
      )
    }
  end

  def render(assigns), do: GameOfLifeWeb.PageView.render("game.html", assigns)

  def handle_event("set-size", %{"size" => size}, socket) do
    size = String.to_integer(size)
    grid = for _ <- 1..size, do: 0 |> List.duplicate(size)
    grid_data = Conway.Grid.new(grid)

    GameOfLifeWeb.Endpoint.broadcast_from(self(), @topic, "update-grid", %{
      grid_data: grid_data,
      grid_size: size
    })

    {:noreply, assign(socket, grid_data: grid_data, grid_size: size)}
  end

  def handle_event("randomize", _values, socket) do
    grid_data = Conway.Grid.new(socket.assigns.grid_size, socket.assigns.gen_prob)

    GameOfLifeWeb.Endpoint.broadcast_from(self(), @topic, "update-grid", %{
      grid_data: grid_data,
      grid_size: socket.assigns.grid_size
    })

    {:noreply, assign(socket, grid_data: grid_data)}
  end

  def handle_event("go", _values, socket) do
    GameOfLifeWeb.Endpoint.broadcast_from(self(), @topic, "update-grid", %{game_state: :playing})
    Process.send_after(self(), :play, 500)
    {:noreply, assign(socket, game_state: :playing)}
  end

  def handle_event("stop", _values, socket) do
    GameOfLifeWeb.Endpoint.broadcast_from(self(), @topic, "update-grid", %{game_state: :stopped})
    {:noreply, assign(socket, game_state: :stopped)}
  end

  def handle_event("chg-prob", %{"_target" => ["slider"], "slider" => prob}, socket) do
    prob = String.to_integer(prob)
    GameOfLifeWeb.Endpoint.broadcast_from(self(), @topic, "update-grid", %{gen_prob: prob})
    {:noreply, assign(socket, gen_prob: prob)}
  end

  def handle_event("switch-cell-state", %{"cell-col" => cell_col, "cell-row" => cell_row}, socket) do
    grid_data =
      Conway.Grid.switch_cell_status(
        socket.assigns.grid_data,
        String.to_integer(cell_col),
        String.to_integer(cell_row)
      )

    {:noreply, assign(socket, grid_data: grid_data)}
  end

  def handle_event("no-action", _, socket), do: {:noreply, socket}

  def handle_info(:play, socket) do
    if socket.assigns.game_state == :playing do
      grid_data = Conway.Grid.next(socket.assigns.grid_data)

      GameOfLifeWeb.Endpoint.broadcast_from(self(), @topic, "update-grid", %{grid_data: grid_data})

      Process.send_after(self(), :play, 1_000)
      {:noreply, assign(socket, grid_data: grid_data)}
    else
      {:noreply, assign(socket, game_state: :stopped)}
    end
  end

  def handle_info(info, socket) do
    {:noreply, assign(socket, info.payload)}
  end
end

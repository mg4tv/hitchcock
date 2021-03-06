defmodule Hitchcock.VideoController do
  use Hitchcock.Web, :controller

  alias Hitchcock.{AuthenticationController, ErrorView, Video}
  alias Ecto.UUID
  alias Guardian.Plug.EnsureAuthenticated


  plug EnsureAuthenticated, [handler: AuthenticationController] when action in [:create, :update, :delete]


  ### GET /videos
  def index(conn, _params) do
    videos = Repo.all(Video)
    render(conn, "index.json", videos: videos)
  end


  ### GET /videos/:id
  def show(conn, %{"id" => id}) do
    # FIXME: verify visible
    case UUID.cast(id) do
      {:ok, uuid} ->
        case Repo.get(Video, uuid) do
          nil ->
            conn
            |> put_status(:not_found)
            |> render(ErrorView, "404.json", type: "Video")

          video ->
            render(conn, "show.json", video: video)
        end

      :error ->
        conn
        |> put_status(:bad_request)
        |> render(ErrorView, "400.json", %{description: "Invalid request.", fields: ["id"]})
    end
  end


  ### POST /videos
  def create(conn, video_params) do
    current_user = Guardian.Plug.current_resource(conn)
                   |> Repo.preload(:user_group)
                   |> Repo.preload(:user_group_group)

    # FIXME: permissions and don't allow group jumping
    video_params = Map.merge(video_params, %{"user_id" => current_user.id, "group_id" => current_user.user_group_group.id})
    changeset = Video.changeset(%Video{}, video_params)

    case Repo.insert(changeset) do
      {:ok, video} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", video_path(conn, :show, video.id))
        |> render("show.json", video: video)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, "422.json", changeset: changeset)
    end
  end


  ### PATCH/PUT /videos/:id
  def update(conn, video_params) do
    # FIXME: auth permissions and group jumping
    case UUID.cast(video_params["id"]) do
      {:ok, uuid} ->
        case Repo.get(Video, uuid) do
          nil ->
            conn
            |> put_status(:not_found)
            |> render(ErrorView, "404.json", type: "Video")

          video ->
            changeset = Video.changeset(video, video_params)
            case Repo.update(changeset) do
              {:ok, video} ->
                render(conn, "show.json", video: video)

              {:error, changeset} ->
                conn
                |> put_status(:unprocessable_entity)
                |> render(ErrorView, "422.json", changeset: changeset)
            end
        end

      :error ->
        conn
        |> put_status(:bad_request)
        |> render(ErrorView, "400.json", %{description: "Invalid request.", fields: ["id"]})
    end
  end


  ### DELETE /videos/:id
  def delete(conn, %{"id" => id}) do
    current_user = Guardian.Plug.current_resource(conn)
                   |> Repo.preload(:user_group)
                   |> Repo.preload(:user_group_group)

    case UUID.cast(id) do
      {:ok, uuid} ->
        case Repo.get(Video, uuid) do
          nil ->
            conn
            |> put_status(:not_found)
            |> render(ErrorView, "404.json", %{type: "Video"})

          video ->
            video = video |> Repo.preload(:user)
            case video.user.id == current_user.id do
              true ->
                Repo.delete!(video)
                send_resp(conn, :no_content, "")
              _ ->
                conn
                |> put_status(:forbidden)
                |> render(ErrorView, "403.json")
            end
        end
      :error ->
        conn
        |> put_status(:bad_request)
        |> render(ErrorView, "400.json", %{description: "Invalid request.", fields: ["id"]})
    end
  end
end

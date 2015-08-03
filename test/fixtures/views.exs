import Phoenix.HTML

defmodule MyApp.View do
  use Phoenix.View, root: "test/fixtures/templates"

  def escaped_title(title) do
    html_escape title
  end
end

defmodule MyApp.LayoutView do
  use Phoenix.View, root: "test/fixtures/templates"

  def default_title do
    "MyApp"
  end
end

defmodule MyApp.UserView do
  use Phoenix.View, root: "test/fixtures/templates"

  def escaped_title(title) do
    html_escape title
  end

  def render("edit.html", %{} = assigns) do
    "EDIT#{assigns[:layout]} - #{assigns[:title]}"
  end
end

defmodule MyApp.Templates.UserView do
  use Phoenix.View, root: "test/fixtures"

  def escaped_title(title) do
    html_escape title
  end
end

defmodule MyApp.Nested.UserView do
  use Phoenix.View, root: "test/fixtures/templates", namespace: MyApp.Nested

  def escaped_title(title) do
    html_escape title
  end
end

defmodule MyApp.Post do
  defstruct title: nil, user: nil
end

defmodule MyApp.User do
  defstruct name: nil
end

defmodule MyApp.V1.PostView do
  use Phoenix.View, root: "test/fixtures"

  def render("show.json", %{post: post}) do
    %{user: render_one(post.user, "show.json")}
  end
end

defmodule MyApp.V2.PostView do
  use Phoenix.View, root: "test/fixtures"

  def render("show.json", %{post: post}) do
    %{user: render_one(post.user, "show.json")}
  end
end

defmodule MyApp.V1.UserView do
  def render("show.json", %{user: user}), do: %{version: 1}
end

defmodule MyApp.V2.UserView do
  def render("show.json", %{user: user}), do: %{version: 2}
end

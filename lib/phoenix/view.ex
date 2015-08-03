defmodule Phoenix.View do
  @moduledoc """
  Defines the view layer of a Phoenix application.

  This module is used to define the application main view, which
  serves as the base for all other views and templates in the
  application.

  The view layer also contains conveniences for rendering templates,
  including support for layouts and encoders per format.

  ## Examples

  Phoenix defines the view template at `web/web.ex`:

      defmodule YourApp.Web do
        def view do
          quote do
            use Phoenix.View, root: "web/templates"

            # Import common functionality
            import YourApp.Router.Helpers

            # Use Phoenix.HTML to import all HTML functions (forms, tags, etc)
            use Phoenix.HTML
          end
        end

        # ...
      end

  We can use the definition above to define any view in your application:

      defmodule YourApp.UserView do
        use YourApp.Web, :view
      end

  Because we have defined the template root to be "web/template", `Phoenix.View`
  will automatically load all templates at "web/template/user" and include them
  in the `YourApp.UserView`. For example, imagine we have the template:

      # web/templates/user/index.html.eex
      Hello <%= @name %>

  The `.eex` extension is called a template engine which tells Phoenix how
  to compile the code in the file into actual Elixir source code. After it is
  compiled, the template can be rendered as:

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
      #=> {:safe, "Hello John Doe"}

  We will discuss rendering in detail next.

  ## Rendering

  The main responsibility of a view is to render a template.

  A template has a name, which also contains a format. For example,
  in the previous section we have rendered the "index.html" template:

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
      #=> {:safe, "Hello John Doe"}

  When a view renders a template, the result returned is an inner
  representation specific to the template format. In the example above,
  we got: `{:safe, "Hello John Doe"}`. The safe tuple annotates that our
  template is safe and that we don't need to escape its contents because
  all data was already encoded so far. Let's try to inject custom code:

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John<br />Doe")
      #=> {:safe, "Hello John&lt;br /&gt;Doe"}

  This inner representation allows us to render and compose templates easily.
  For example, if you want to render JSON data, we could do so by adding a
  "show.json" entry to `render/2` in our view:

      defmodule YourApp.UserView do
        use YourApp.View

        def render("show.json", %{user: user}) do
          %{name: user.name, address: user.address}
        end
      end

  Notice that in order to render JSON data, we don't need to explicitly
  return a JSON string! Instead, we just return data that is encodable to
  JSON.

  Both JSON and HTML formats will be encoded only when passing the data
  to the controller via the `render_to_iodata/3` function. The
  `render_to_iodata/3` uses the notion of format encoders to convert a
  particular format to its string/iodata representation.

  Phoenix ships with some template engines and format encoders, which
  can be further configured in the Phoenix application. You can read
  more about format encoders in `Phoenix.Template` documentation.
  """

  @doc """
  When used, defines the current module as a main view module.

  ## Options

    * `:root` - the template root to find templates
    * `:namespace` - the namespace to consider when calculating view paths

  The `:root` option is required while the `:namespace` defaults to the
  first nesting in the module name. For instance, both `MyApp.UserView`
  and `MyApp.Admin.UserView` have namespace `MyApp`.

  The namespace is used to calculate paths. For example, if you are in
  `MyApp.UserView` and the namespace is `MyApp`, templates are expected
  at `Path.join(root, "user")`. On the other hand, if the view is
  `MyApp.Admin.UserView`, the path will be `Path.join(root, "admin/user")`
  and so on.

  Setting the namespace to `MyApp.Admin` in the second example will force
  the template to also be looked up at `Path.join(root, "user")`.
  """
  defmacro __using__(options) do
    if root = Keyword.get(options, :root) do
      namespace =
        if given = Keyword.get(options, :namespace) do
          given
        else
          __CALLER__.module
          |> Module.split()
          |> Enum.take(1)
          |> Module.concat()
        end

      quote do
        import Phoenix.View

        use Phoenix.Template, root:
          Path.join(unquote(root),
                    Phoenix.Template.module_to_template_root(__MODULE__, unquote(namespace), "View"))
      end
    else
      raise "expected :root to be given as an option"
    end
  end

  @doc """
  Renders a template.

  It expects the view module, the template as a string, and a
  set of assigns.

  Notice this function returns the inner representation of a
  template. If you want the encoded template as a result, use
  `render_to_iodata/3` instead.

  ## Examples

      Phoenix.View.render(YourApp.UserView, "index.html", name: "John Doe")
      #=> {:safe, "Hello John Doe"}

  ## Assigns

  Assigns are meant to be user data that will be available in templates.
  However there are keys under assigns that are specially handled by
  Phoenix, they are:

    * `:layout` - tells Phoenix to wrap the rendered result in the
      given layout. See next section.

  ## Layouts

  Templates can be rendered within other templates using the `:layout`
  option. `:layout` accepts a tuple of the form
  `{LayoutModule, "template.extension"}`.

  When a template is rendered, the layout template will have an `@inner`
  assign containing the rendered contents of the sub-template. For HTML
  templates, `@inner` will be always marked as safe.

      Phoenix.View.render(YourApp.UserView, "index.html",
                          layout: {YourApp.LayoutView, "application.html"})
      #=> {:safe, "<html><h1>Hello!</h1></html>"}

  """
  def render(module, template, assigns) do
    assigns
    |> to_map()
    |> Map.pop(:layout, false)
    |> render_within(module, template)
  end

  defp to_map(assigns) when is_map(assigns), do: assigns
  defp to_map(assigns) when is_list(assigns), do: :maps.from_list(assigns)
  defp to_map(assigns), do: Dict.merge(%{}, assigns)

  defp render_within({{layout_mod, layout_tpl}, assigns}, inner_mod, template) do
    template
    |> inner_mod.render(assigns)
    |> render_layout(layout_mod, layout_tpl, assigns)
  end

  defp render_within({false, assigns}, module, template) do
    template
    |> module.render(assigns)
  end

  defp render_layout(inner_content, layout_mod, layout_tpl, assigns) do
    assigns = Map.put(assigns, :inner, inner_content)
    layout_mod.render(layout_tpl, assigns)
  end

  @doc """
  Renders the template and returns iodata.
  """
  def render_to_iodata(module, template, assign) do
    render(module, template, assign) |> encode(template)
  end

  @doc """
  Renders the template and returns a string.
  """
  def render_to_string(module, template, assign) do
    render_to_iodata(module, template, assign) |> IO.iodata_to_binary
  end

  defp encode(content, template) do
    if encoder = Phoenix.Template.format_encoder(template) do
      encoder.encode_to_iodata!(content)
    else
      content
    end
  end

  def view_for_record(%{__struct__: model}, view) do
    model_name = Module.split(model) |> List.last
    view_namespace(view)
    |> Enum.join(".")
    |> Kernel.<>(".#{model_name}View")
    |> IO.inspect
    |> String.split(".")
    |> Module.concat
  end

  def view_namespace(view) do
    view |> Module.split |> List.delete_at(-1)
  end

  defmacro render_one(record, template) do
   quote bind_quoted: [record: record, template: template] do
      view_for_record(record, __MODULE__).render(template, %{user: record})
    end
  end
end


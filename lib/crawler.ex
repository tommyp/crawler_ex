defmodule Crawler do
  @default_headers []
  @default_options [follow_redirects: true]
  @default_max_depth 3

  def get_links(url, opts \\ []) do
    url = URI.parse(url)

    context = %{
      host: url.host,
      headers: Keyword.get(opts, :headers, @default_headers),
      options: Keyword.get(opts, :options, @default_options),
      max_depth: Keyword.get(opts, :max_depth, @default_max_depth)
    }

    get_links(url, [], context)
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
  end

  defp get_links(url, pathes, context) do
    if continue_crawl?(pathes, context) and crawlable_url?(url, context) do
      url
      |> to_string
      |> HTTPoison.get(context.headers, context.options)
      |> handle_response(url, pathes, context)
    else
      [url]
    end
  end

  def handle_response({:ok, %{body: body}}, url, pathes, context) do
    [
      url
      | body
        |> Floki.find("a")
        |> Floki.attribute("href")
        |> Enum.map(&URI.merge(url, &1))
        |> Enum.reject(&Enum.member?(pathes, &1))
        |> Enum.map(&to_string/1)
        |> Enum.map(&Task.async(fn -> get_links(&1, [&1 | pathes], context) end))
        |> Enum.map(&Task.await/1)
        |> List.flatten()
    ]
  end

  def handle_response(_response, url) do
    [url]
  end

  defp crawlable_url?(%{host: host}, %{host: initial}) when host == initial, do: true
  defp crawlable_url?(_, _), do: false

  defp continue_crawl?(path, %{max_depth: max}) when length(path) > max, do: false
  defp continue_crawl?(_, _), do: true
end

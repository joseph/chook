require 'rubygems'
require 'erb'
require 'sinatra'

require 'lib/ochook'
require 'lib/componentizer'
require 'lib/outliner'
require 'lib/epub'


get '/publish' do
  erb :publish
end


post '/publish' do
  @ook = Chook::Ochook.from_zhook(
    params[:file][:tempfile].path,
    params[:secure] ? 24 : 4
  )
  if @ook.valid?
    redirect("/read/#{@ook.id}")
  else
    @ook.destroy
    erb(:publish)
  end
end


get '/read/:book_id' do
  @id = params[:book_id]
  @ook = Chook::Ochook.from_id(@id)
  @ook && @ook.exists? ? erb(:read) : halt(404)
end


get '/books/:book_id/' do
  path = File.join("public", "books", params[:book_id], "index.html")
  File.exists?(path) ? File.read(path) : halt(404)
end


get '/books/:book_id' do
  redirect("/books/#{params[:book_id]}/")
end


not_found do
  "Resource not found."
end


enable :inline_templates

__END__

@@ publish
<!DOCTYPE html>
<html>
  <head>
    <title>Publish an Ochook</title>
    <style type="text/css">
      p.warn {
        background: #C55;
        color: white;
        padding: 0.5em 1em;
      }
    </style>
  </head>
  <body>
    <h1>Publish an Ochook</h1>
    <form action="/publish" method="POST" enctype="multipart/form-data">
      <% if @ook && @ook.invalidity %>
        <p class="warn">
          <%= Rack::Utils.escape_html(@ook.invalidity.inspect) %>
        </p>
      <% end %>
      <fieldset>
        <legend>Upload a Zhook</legend>
        <p>
          <input type="file" name="file" />
        </p>
        <p>
          <label>Secure URL?
            <input type="checkbox" name="secure" />
          </label>
        </p>
        <p>
          <input type="submit" value="Publish" />
        </p>
      </fieldset>
    </form>
  </body>
</html>


@@ read
<!DOCTYPE html>
<html manifest="<%= @ook.public_path(@ook.id, "ochook.manifest") %>">
  <head>
    <title><%= @ook.metadata('title') %></title>
    <meta name="viewport"
      content="width=device-width; initial-scale=1.0; maximum-scale=1.0; user-scalable=no;"
    />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <meta name="apple-mobile-web-app-status-bar-style" content="black" />
    <style type="text/css">
      body {
        background: black;
        margin: 0;
      }
      img {
        position: absolute;
        max-width: 100%;
        max-height: 100%;
      }
      iframe {
        position: absolute;
        visibility: hidden;
        border: none;
        background: white;
      }
    </style>
    <script type="text/javascript">
      function setup() {
        var frame = document.getElementById('reader');
        frame.contentDocument.documentElement.setAttribute(
          'id',
          'RS:org.ochook.reader'
        );
      }

      function read() {
        var cover = document.getElementById('cover');
        var frame = document.getElementById('reader');
        frame.style.width = cover.offsetWidth+"px";
        frame.style.height = cover.offsetHeight+"px";
        cover.style.display = "none";
        frame.style.visibility = "visible";
      }
    </script>
  </head>
  <body>
    <img id="cover" src="/books/<%= @id %>/cover.png" onclick="read()" />
    <iframe id="reader" src="/books/<%= @id %>/index.html" onload="setup()">
    </iframe>
  </body>
</html>

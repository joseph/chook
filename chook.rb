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
        z-index: 0;
      }
      #nav {
        position: absolute;
        top: 0;
        left: 0;
        display: none;
        z-index: 1;
      }
      #tocCntr {
        max-height: 50%;
        overflow: auto;
        background: #222;
        display: none;
        color: #999;
        font: 9pt Lucide Grande, Tahoma, sans-serif;
      }
      #tocCntr ol {
        padding-left: 1em;
        counter-reset: item;
      }
      #tocCntr ol li {
        display: block;
      }
      #tocCntr ol li:before {
        content: counters(item, ".") " ";
        counter-increment: item;
      }
      #tocCntr a {
        color: #EEE;
        text-decoration: none;
      }
      #tocButtons {
        margin-left: 50%;
        width: 46%;
        color: white;
        text-align: center;
        cursor: pointer;
        font: 10pt Lucide Grande, Tahoma, sans-serif;
      }
      #tocArrLeft {
        font-weight: bold;
        width: 2em;
        float: left;
        background: #222;
        -webkit-border-bottom-left-radius: 6px;
        -moz-border-radius-bottomleft: 6px;
        border-bottom-left-radius: 6px;
        padding: 0 0 0.3em;
      }
      #tocArrRight {
        font-weight: bold;
        width: 2em;
        float: right;
        background: #222;
        -webkit-border-bottom-right-radius: 6px;
        -moz-border-radius-bottomright: 6px;
        border-bottom-right-radius: 6px;
        padding: 0 0 0.3em;
      }
      #tocTab {
        background: #222;
        overflow: hidden;
        padding: 0.5em 0;
      }
    </style>
    <script type="text/javascript">
      var $ = function (id) { return document.getElementById(id) };
      var ochook = {};

      function setup() {
        var frame = $('reader');
        frame.contentDocument.documentElement.setAttribute(
          'id',
          'RS:org.ochook.reader'
        );
      }

      function read() {
        var cover = $('cover');
        var nav = $('nav');
        var frame = $('reader');
        nav.style.width = cover.offsetWidth+"px";
        frame.style.width = cover.offsetWidth+"px";
        frame.style.height = cover.offsetHeight+"px";
        cover.style.display = "none";
        nav.style.display = "block";
        frame.style.visibility = "visible";
        applyTOC(frame);
      }

      function applyTOC(frame) {
        var doc = frame.contentDocument;
        $('tocArrLeft').onclick = function () {
          if (!ochook.prevChapter) { return; }
          ochook.prevChapter.anchor.scrollIntoView();
        }
        $('tocArrRight').onclick = function () {
          if (!ochook.nextChapter) { return; }
          ochook.nextChapter.anchor.scrollIntoView();
        }

        ochook.tocCntr = $('tocCntr');
        ochook.tocTab = $('tocTab');
        ochook.tocTab.onclick = toggleTOC;

        lineariseTOC(frame);
        updateTOCTab(frame);
        frame.contentWindow.addEventListener(
          "scroll",
          function () { updateTOCTab(frame); },
          true
        );
      }


      function toggleTOC() {
        ochook.tocCntr.style.display =
          (ochook.tocCntr.style.display == "block") ?  "none" : "block";
      }


      function lineariseTOC(frame) {
        ochook.linearTOC = [];
        var curse = function (list) {
          for (var i = 0; i < list.childNodes.length; ++i) {
            var ch = list.childNodes[i];
            if (ch.tagName.toLowerCase() == "li") {
              for (var j = 0; j < ch.childNodes.length; ++j) {
                var lich = ch.childNodes[j];
                if (!lich.tagName) {
                } else if (lich.tagName.toLowerCase() == "ol") {
                  curse(lich);
                } else if (lich.tagName.toLowerCase() == "a") {
                  prepTocItem(lich, frame);
                }
              }
            }
          }
        }
        curse($('tocCntr').getElementsByTagName('ol')[0]);
      }


      function prepTocItem(lich, frame) {
        var id = lich.getAttribute("href");
        id = id.replace(/^#/, '');
        var anchor = frame.contentDocument.getElementById(id);
        if (anchor) {
          ochook.linearTOC.push({
            id: id,
            anchor: anchor,
            offset: anchor.offsetTop
          });
          lich.onclick = function (l) {
            anchor.scrollIntoView();
            toggleTOC();
            return false;
          }
        } else {
          console.log("ID not found: "+id);
        }
      }


      function updateTOCTab(frame) {
        var sY = frame.contentWindow.scrollY;
        var setTabText = function (tocItem) {
          ochook.tocTab.innerHTML = tocItem.anchor.innerHTML;
        }
        for (var i = 0; i < ochook.linearTOC.length; ++i) {
          var n0 = ochook.linearTOC[i], n1 = ochook.linearTOC[i+1];
          if (n0 && n1) {
            if (
              (n0.offset <= sY && n1.offset > sY) ||
              (n0.offset > sY)
            ){
              setTabText(n0);
              ochook.nextChapter = n1;
              ochook.prevChapter = ochook.linearTOC[i-1] || n0;
              break;
            }
          } else if (n0) {
            setTabText(n0);
            ochook.nextChapter = null;
            ochook.prevChapter = ochook.linearTOC[i-1] || n0;
            break;
          }
        }
      }

    </script>
  </head>
  <body>
    <img id="cover" src="/books/<%= @id %>/cover.png" onclick="read()" />
    <div id="nav">
      <div id="tocCntr"><%= @ook.toc_html %></div>
      <div id="tocButtons">
        <div id="tocArrLeft">&larr;</div>
        <div id="tocArrRight">&rarr;</div>
        <div id="tocTab"></div>
      </div>
    </div>
    <iframe id="reader" src="/books/<%= @id %>/index.html" onload="setup()">
    </iframe>
  </body>
</html>

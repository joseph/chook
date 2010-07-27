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
      #hiddenTOC {
        display: none;
      }
    </style>
    <script type="text/javascript">
      var ochook = {};

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
        applyTOC(frame);
      }

      function applyTOC(frame) {
        var doc = frame.contentDocument;
        ochook.ctrl = doc.createElement('div');
        ochook.ctrl.style.cssText = "position: fixed; top: 0; left: 0; width: 100%;";
        doc.body.appendChild(ochook.ctrl);

        ochook.tocCntr = doc.createElement('div');
        ochook.tocCntr.innerHTML = document.getElementById('hiddenTOC').innerHTML;
        ochook.tocCntr.style.cssText = "max-height: 50%; overflow: auto; background: #CCC; display: none;";
        ochook.ctrl.appendChild(ochook.tocCntr);

        ochook.tocButtons = doc.createElement('div');
        ochook.tocButtons.style.cssText = "margin-left: 50%; width: 48%; color: white; text-align: center; cursor: pointer;";
        ochook.ctrl.appendChild(ochook.tocButtons);

        ochook.tocArrLeft = doc.createElement('div');
        ochook.tocArrRight = doc.createElement('div');
        ochook.tocArrLeft.innerHTML = "&larr;";
        ochook.tocArrRight.innerHTML = "&rarr;";
        ochook.tocArrLeft.style.cssText = "width: 2em; background: #900; float: left;";
        ochook.tocArrRight.style.cssText = "width: 2em; background: #009; float: right;";
        ochook.tocArrLeft.onclick = function () {
          if (!ochook.prevChapter) { return; }
          ochook.prevChapter.anchor.scrollIntoView();
        }
        ochook.tocArrRight.onclick = function () {
          if (!ochook.nextChapter) { return; }
          ochook.nextChapter.anchor.scrollIntoView();
        }

        ochook.tocButtons.appendChild(ochook.tocArrLeft);
        ochook.tocButtons.appendChild(ochook.tocArrRight);

        ochook.tocTab = doc.createElement('div');
        ochook.tocTab.innerHTML = "The title of this chapter";
        ochook.tocTab.style.cssText = "background: #909; overflow: hidden; text-overflow: ellipsis;"
        ochook.tocTab.onclick = toggleTOC;
        ochook.tocButtons.appendChild(ochook.tocTab);

        lineariseTOC(frame);
        updateTOCTab(frame);
        frame.contentWindow.addEventListener("scroll", function () { updateTOCTab(frame); }, true);
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
                if (lich.tagName.toLowerCase() == "ol") {
                  curse(lich);
                } else if (lich.tagName.toLowerCase() == "a") {
                  var id = lich.getAttribute("href");
                  if (id) {
                    id = id.replace(/^#/, '');
                    var anchor = frame.contentDocument.getElementById(id);
                    ochook.linearTOC.push({
                      id: id,
                      anchor: anchor,
                      offset: anchor.offsetTop
                    });
                    lich.onclick = function () {
                      anchor.scrollIntoView();
                      toggleTOC();
                      return false;
                    }
                  } else {
                    lich.setAttribute("href", "#");
                    lich.onclick = function () {
                      frame.contentWindow.scrollTo(0, 0);
                      toggleTOC();
                      return false;
                    }
                  }
                }
              }
            }
          }
        }
        curse(frame.contentDocument.getElementsByTagName('ol')[0]);
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
    <iframe id="reader" src="/books/<%= @id %>/index.html" onload="setup()">
    </iframe>
    <div id="hiddenTOC"><%= @ook.toc_html %></div>
  </body>
</html>

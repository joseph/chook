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

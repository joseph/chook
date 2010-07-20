require 'rubygems'
require 'erb'
require 'sinatra'

require 'models/ochook.rb'


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
  if @ook && @ook.exists?
    erb(:read)
  else
    "Sorry, could not find this book." # FIXME
  end
end


get '/books/:book_id' do
  redirect("/books/#{params[:book_id]}/")
end


get '/books/:book_id/' do
  path = File.join("public", "books", params[:book_id], "index.html")
  if File.exists?(path)
    File.read(path)
  else
    "Sorry, could not find this book." # FIXME
  end
end

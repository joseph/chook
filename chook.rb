require 'rubygems'
require 'erb'
require 'sinatra'

require 'lib/ochook'
require 'lib/componentizer'
require 'lib/outliner'
require 'lib/epub'

mime_type :epub, 'application/epub+zip'
mime_type :zhook, 'application/zhook+zip'


helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def book_action(action, options = {})
    @id = params[:book_id]
    @ook = Chook::Ochook.from_id(@id)
    if @ook && @ook.exists?
      yield  if block_given?
      erb(action, options)
    else
      halt(404)
    end
  end

end


#--------------------------------------------------------------------------
# UPLOADING
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

get '/publish' do
  erb :publish, :layout => false
end


post '/publish' do
  @ook = Chook::Ochook.from_zhook(
    params[:file][:tempfile].path,
    { "public" => 4, "private" => 24 }[params[:security]]
  )
  if @ook.valid?
    redirect("/fix/#{@ook.id}")
  else
    @ook.destroy
    erb(:publish, :layout => false)
  end
end



#--------------------------------------------------------------------------
# VIEW AS OCHOOK
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

get '/book/:book_id/' do
  path = File.join("public", "book", params[:book_id], "index.html")
  File.exists?(path) ? File.read(path) : halt(404)
end


get '/book/:book_id' do
  redirect("/book/#{params[:book_id]}/")
end


#--------------------------------------------------------------------------
# BOOK DETAILS, DOWNLOAD LINKS
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

get '/:book_id' do
  book_action(:book_index)
end


# Read the book in the Zhook reference Reading System.
#
get '/:book_id/read' do
  book_action(:read, :layout => false)
end


# Convert the Ochook to EPUB or Zhook.
#
get '/:book_id/format/:format' do
  halt(404)  unless %w[epub zhook].include?(params[:format])
  path = "/formats/#{params[:book_id]}/#{params[:book_id]}.#{params[:format]}"
  unless File.exists?("public#{path}")
    @id = params[:book_id]
    @ook = Chook::Ochook.from_id(@id)
    if params[:format].downcase == "epub"
      Chook::Epub.from_ochook(@ook)
    elsif params[:format].downcase == "zhook"
      # TODO: convert to zhook?
    else
      halt(404)
    end
  end
  redirect(path)
end


# View the Table of Contents and Table of Figures.
#
get '/:book_id/contents' do
  book_action(:contents)
end


# Viewing and editing the metadata.
#
get '/:book_id/metadata' do
  book_action(:metadata)
end


post '/:book_id/metadata' do
  # TODO
end


# Viewing and editing the HTML.
#
get '/:book_id/html' do
  book_action(:html)
end


post '/:book_id/html' do
  # TODO
end


# 404!
#
not_found do
  "Resource not found."
end

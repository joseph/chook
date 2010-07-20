require 'rubygems'
require 'sinatra'

disable :run

set :app_file, 'chook.rb'

require 'chook'
run Sinatra::Application

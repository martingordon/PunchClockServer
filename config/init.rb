require 'sinatra'
require 'sinatra/sequel'
require 'sequel'
require 'parse-ruby-client'

configure do
  Sequel::Model.plugin :json_serializer
  DB = Sequel.connect(ENV['DATABASE_URL'])
  require './config/migrations'
  require './config/data'
end

use Rack::Auth::Basic do |username, password|
  username == ENV['AUTH_USER'] && password == ENV['AUTH_PASSWORD']
end

configure :production do
  Parse.init  application_id: ENV["PARSE_PROD_APP_ID"],
              api_key:        ENV["PARSE_PROD_API_KEY"]
end

configure :development do
  require 'logger'
  DB.logger = Logger.new($stdout)
  Parse.init  application_id: ENV["PARSE_DEV_APP_ID"],
              api_key:        ENV["PARSE_DEV_API_KEY"]
end

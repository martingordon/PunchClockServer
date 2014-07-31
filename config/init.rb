require 'sinatra'
require 'sinatra/sequel'
require 'sequel'
require 'parse-ruby-client'

class String
  def titleize
    arr = self.split(" ")
    arr.each { |w| w.capitalize! }.join(" ")
  end
end

if $0 == "irb"
  File.open(".env").each do |line|
    arr = line.strip.split("=")

    key = arr[0] if arr.length > 0
    val = arr[1] if arr.length > 1

    if !key.nil? and key != ""
      ENV[key] = val.gsub("\"", "") || ""
    end
  end
end

configure do
  Sequel::Model.plugin :json_serializer
  DB = Sequel.connect(ENV['DATABASE_URL'])
  require './config/migrations'
  require './config/data'
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



require 'rubygems'
require 'sinatra'
require 'json'
require 'rss'

require 'pp' if ENV['RACK_ENV'] == 'development'

require './config/init.rb'

STATUS_OK = 0
STATUS_ERROR = 1
STATUS_UNREGISTERED = 2
STATUS_ALREADY_WATCHED = 3

MINIMUM_VERSION = 73

class String
  def titleize
    arr = self.split(" ")
    arr.each { |w| w.capitalize! }.join(" ")
  end
end

helpers do
  def slack_webhook_uri
    URI.join(ENV['SLACK_URL'], "services/hooks/incoming-webhook?token=#{ENV['SLACK_TOKEN']}")
  end

  def agent_version
    agent = request.env['HTTP_USER_AGENT']
    if agent
      matches = /^\w+\/(\d+)\s/.match(agent)
      if matches
        version = matches[1]
      else
        version = 9999
      end
    else
      version = 9999
    end
  end
end

get '/' do
  halt 404
end

get '/status' do
  erb :index
end

get '/status/table' do

  # @people = Person.where{version >= MINIMUM_VERSION}.select_order_map([:name, :status])
  # @count = Person.where(:status => 'In').where{version >= MINIMUM_VERSION}.count

  @people = Person.select_order_map([:name, :status])
  @count = Person.where(:status => 'In').count

  erb :table
end

get '/status/list' do
  DB.transaction do
    DB.fetch("update people set status = 'Stale' where date < NOW() - INTERVAL '1 DAY' and status != 'Stale';")
  end

#  people = Person.order(:name).where{version >= MINIMUM_VERSION}
  people = Person.order(:name)

  if params[:name]
    lowName = params[:name].downcase
    requestor = Person[:name => lowName]
    halt 400 unless requestor
  end

  content_type :json

  output = []

  people.each do |p|

    watched_by = false
    watches = false

    if requestor
      watched_by = p.watched_by_name(requestor.name)
      watches = p.watches_name(requestor.name)
    end

    output << { "status" => p.status, "name" => p.name, "watched_by_requestor" => watched_by, "watches_requestor" => watches }
  end

  output.to_json
end

post '/status/update' do
  content_type :json
  require_params :name, :status

  output = ""

  DB.transaction do
    lowName = params[:name].downcase

    person = Person.for_update.first(:name => lowName)

    if !person
      person = Person.new()
      output = {"result" => STATUS_UNREGISTERED, "msg" => "Name not found"}.to_json
    else

      status_changed = params[:status] != person.status
      output = {"result" => STATUS_OK, "status_changed" => status_changed}.to_json

      if status_changed
        # Send notifications
        #        count = Person.where(:status => 'In').where{version >= MINIMUM_VERSION}.count

        change = StatusChange.new
        change.person = person
        change.date = DateTime.now
        change.status = params[:status]
        change.save

        count = Person.where(:status => 'In').count

        recipient_ids = []
        person.watchers.each do |w|
          if w.push_id != ""
            recipient_ids << w.push_id
            puts "Queuing notification for #{w.name}"
          end
        end

        recipient_ids.each do |id|
          push = Parse::Push.new({
            alert: "#{sender.name.titleize} is #{params[:status]}",
            sound: "status.caf",
            badge: ""
          })
          push.where = { "deviceToken" => id }
          push.save
        end
      end
    end

    person.status = params[:status]
    person.name = lowName
    person.push_id = params[:push_id]
    person.beacon_minor = params[:beacon_minor]
    person.version = agent_version
    person.date = DateTime.now
    person.save or {"result" => STATUS_ERROR, "reason" => "The record could not be saved"}.to_json

    puts "STATUS UPDATE: #{person.name.titleize} is #{params[:status]}"
  end


  output
end

post '/message/in' do
  content_type :json
  require_params :name, :message

  lowName = params[:name].downcase
  lowName = 'steven' if lowName == 'stevenf'

  sender = Person.first(:name => lowName)
  in_people = Person.where(:status => 'In')

  message = Message.new
  message.person = sender
  message.date = DateTime.now
  message.message = params[:message]
  message.save or { "result" => STATUS_ERROR, "reason" => "The record could not be saved" }.to_json
  recipient_ids = []

  in_people.each do |p|
    if p.push_id != ""
      recipient_ids << p.push_id
      puts "Queuing message notification for #{p.name}"
    end
  end

  recipient_ids.each do |id|
    push = Parse::Push.new({
      alert: "#{sender.name.titleize}: #{params[:message]}",
      sound: "status.caf",
      badge: ""
    })
    push.where = { "deviceToken" => id }
    push.save
  end

  {"result" => STATUS_OK}.to_json
end

get '/ins/:name.xml' do
  require_params :name
  content_type :xml

  lowName = params[:name].downcase

  sender = Person.first(:name => lowName)

  RSS::Rss::NSPOOL.delete("content")
  RSS::Rss::NSPOOL.delete("trackback")
  RSS::Rss::NSPOOL.delete("itunes")

  rss = RSS::Maker.make("2.0") do |maker|
    maker.channel.title = "Arrival Feed for #{sender.name.titleize}"
    maker.channel.description = "Arrival Feed for #{sender.name.titleize}"

    maker.channel.author = ENV["RSS_AUTHOR"]
    maker.channel.about = ENV["RSS_ABOUT"]
    maker.channel.link = ENV["RSS_LINK"]

    ins = sender.ins_dataset.reverse_order(:date)

    if !params[:before].nil? or params[:before] == ""
      before = params[:before].to_i
      ins = sender.ins_dataset.where { Sequel.function(:date_part, "hour", date) <= before }.reverse_order(:date)
    end

    maker.channel.updated = ins.first.nil? ? nil : ins.first.date
    ins.each do |in_status|
      maker.items.new_item do |item|
        item.title = in_status.status
        item.updated = in_status.date
        item.link = ENV["RSS_LINK"]
      end
    end
  end

  rss.to_s
end

get '/outs/:name.xml' do
  require_params :name
  content_type :xml

  lowName = params[:name].downcase

  sender = Person.first(:name => lowName)

  RSS::Rss::NSPOOL.delete("content")
  RSS::Rss::NSPOOL.delete("trackback")
  RSS::Rss::NSPOOL.delete("itunes")

  rss = RSS::Maker.make("2.0") do |maker|
    maker.channel.title = "Arrival Feed for #{sender.name.titleize}"
    maker.channel.description = "Arrival Feed for #{sender.name.titleize}"

    maker.channel.author = ENV["RSS_AUTHOR"]
    maker.channel.about = ENV["RSS_ABOUT"]
    maker.channel.link = ENV["RSS_LINK"]

    outs = sender.outs_dataset.reverse_order(:date)

    if !params[:after].nil? or params[:after] == ""
      after = params[:after].to_i
      outs = sender.outs_dataset.where { Sequel.function(:date_part, "hour", date) >= after }.reverse_order(:date)
    end

    maker.channel.updated = outs.first.nil? ? nil : outs.first.date
    outs.each do |in_status|
      maker.items.new_item do |item|
        item.title = in_status.status
        item.updated = in_status.date
        item.link = ENV["RSS_LINK"]
      end
    end
  end

  rss.to_s
end

get '/messages' do
  content_type :json

  Message.reverse_order(:date).to_json(
    except: [:id, :person_id],
    include: { person: { only: :name } }
  )
end

post '/watch/:target' do
  content_type :json
  require_params :name, :target

  target = Person[:name => params[:target].downcase]
  watcher = Person[:name => params[:name].downcase]

  if target.watched_by_name(watcher.name)
    { "status" => STATUS_ALREADY_WATCHED }.to_json
  else
    target.add_watcher(watcher)
    { "status" => STATUS_OK }.to_json
  end
end

post '/unwatch/:target' do
  content_type :json
  require_params :name, :target

  target = Person[:name => params[:target].downcase]
  watcher = Person[:name => params[:name].downcase]

  if target.watched_by_name(watcher.name)
    target.remove_watcher(watcher)
  end

  { "status" => STATUS_OK }.to_json
end

get '/image/:name' do
  require_params :name

  image_name = "#{params[:name]}.png"
  image_path = File.expand_path(image_name, settings.public_folder)

  if File.exists?(image_path)
    send_file image_path
  else
    send_file File.expand_path("unknown.png", settings.public_folder)
  end
end

def require_params(*parameters)
  parameters.each do |param|
    halt 400 unless params[param]
  end
end

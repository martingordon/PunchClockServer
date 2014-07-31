require 'rss'

class Person < Sequel::Model
  many_to_many :watchers, :class => :Person
  many_to_many :watches, :class => :Person, :right_key => :person_id, :left_key => :watcher_id

  one_to_many :status_changes
  one_to_many :ins, class: :StatusChange do |ds|
    ds.where(status: "In")
  end

  one_to_many :nears, class: :StatusChange do |ds|
    ds.where(status: "Near")
  end

  one_to_many :outs, class: :StatusChange do |ds|
    ds.where(status: "Out")
  end

  def watched_by_name(watcher_name)
    filtered_watchers = self.watchers.select {|w| w.name == watcher_name}
    return filtered_watchers.count == 1
  end

  def watches_name(target_name)
    filtered_targets = self.watches.select {|w| w.name == target_name}
    return filtered_targets.count == 1
  end

  def in_feed(before_hour = nil)
    ins = self.ins_dataset.reverse_order(:date)

    if !before_hour.nil? and before_hour != ""
      ins = self.ins_dataset.where { Sequel.function(:date_part, "hour", date) <= before_hour }.reverse_order(:date)
    end

    _status_feed("Arrival Feed for #{self.name.titleize}", "Arrival Feed for #{self.name.titleize}", ins)
  end

  def out_feed(after_hour = nil)
    outs = self.outs_dataset.reverse_order(:date)

    if !after_hour.nil? and after_hour != ""
      outs = self.outs_dataset.where { Sequel.function(:date_part, "hour", date) >= after_hour }.reverse_order(:date)
    end

    _status_feed("Departure Feed for #{self.name.titleize}", "Departure Feed for #{self.name.titleize}", outs)
  end

  private
  def _status_feed(title, description, statuses)
    RSS::Rss::NSPOOL.delete("content")
    RSS::Rss::NSPOOL.delete("trackback")
    RSS::Rss::NSPOOL.delete("itunes")

    rss = RSS::Maker.make("2.0") do |maker|
      maker.channel.title = title
      maker.channel.about = title
      maker.channel.description = description

      maker.channel.author = self.name
      maker.channel.link = ENV["RSS_LINK"]
      maker.channel.updated = statuses.first.nil? ? nil : statuses.first.date

      statuses.each do |status|
        maker.items.new_item do |item|
          item.title = status.status
          item.updated = status.date
          item.link = "#{ENV["RSS_LINK"]}/status/#{status.id}"

          item.guid.content = "#{status.status}-#{self.id}-#{status.id}-#{status.date.to_i}"
          item.guid.isPermaLink = false
        end
      end
    end
  end
end

class Message < Sequel::Model
  many_to_one :person

  def date
    super.iso8601
  end
end

class StatusChange < Sequel::Model
  many_to_one :person
end

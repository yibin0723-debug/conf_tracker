# frozen_string_literal: true

require "json"
require "date"

# 使用方式：
#
# bundle exec rails runner script/import_conference_alerts.rb
#
# 指定其他 JSON 文件：
#
# JSON_PATH=/path/to/file.json \
# bundle exec rails runner script/import_conference_alerts.rb

json_path =
  ENV.fetch(
    "JSON_PATH",
    Rails.root.join(
      "crawler",
      "output",
      "conference_alerts_ai.json"
    ).to_s
  )

unless File.exist?(json_path)
  abort "JSON file does not exist: #{json_path}"
end

begin
  payload = JSON.parse(File.read(json_path))
rescue JSON::ParserError => error
  abort "JSON parsing failed: #{error.message}"
end

conference_data = payload["conferences"]

unless conference_data.is_a?(Array)
  abort 'JSON does not contain a valid "conferences" array'
end

statistics = {
  total: conference_data.length,
  created: 0,
  updated: 0,
  skipped: 0,
  failed: 0
}

puts "=" * 80
puts "Conference Alerts importer"
puts "=" * 80
puts "Input: #{json_path}"
puts "Records: #{conference_data.length}"
puts

conference_data.each_with_index do |item, index|
  number = index + 1
  name = item["name"].to_s.strip

  begin
    starts_on =
      Date.iso8601(
        item.fetch("event_date")
      )

    ends_on =
      Date.iso8601(
        item.fetch("end_date")
      )

    submission_deadline =
      Date.iso8601(
        item.fetch("submission_deadline")
      )

    location =
      item["location"].to_s.strip

    website_url =
      item["website_url"].to_s.strip

    publication =
      item["publication"].to_s.strip

    topics =
      Array(item["topics"])
        .map(&:to_s)
        .map(&:strip)
        .reject(&:empty?)

    missing_fields = []

    missing_fields << "name" if name.empty?
    missing_fields << "location" if location.empty?
    missing_fields << "event_date" if item["event_date"].to_s.empty?
    missing_fields << "end_date" if item["end_date"].to_s.empty?

    if item["submission_deadline"].to_s.empty?
      missing_fields << "submission_deadline"
    end

    unless missing_fields.empty?
      statistics[:skipped] += 1

      puts(
        "[SKIPPED #{number}/#{conference_data.length}] " \
        "#{name.empty? ? '(unnamed conference)' : name}"
      )

      puts(
        "  Missing required fields: " \
        "#{missing_fields.join(', ')}"
      )

      next
    end

    # 目前数据库没有 source_url 字段。
    #
    # 暂时使用：
    #   会议名称 + 开始日期 + 地点
    #
    # 作为一条会议的唯一识别条件。
    conference =
      Conference.find_or_initialize_by(
        name: name,
        starts_on: starts_on,
        location: location
      )

    new_record = conference.new_record?

    conference.assign_attributes(
      ends_on: ends_on,
      submission_deadline: submission_deadline,
      website_url:
        website_url.empty? ? nil : website_url,
      description:
        publication.empty? ? nil : publication
    )

    Conference.transaction do
      conference.save!
      conference.replace_topics!(topics)
    end

    if new_record
      statistics[:created] += 1
      status = "CREATED"
    else
      statistics[:updated] += 1
      status = "UPDATED"
    end

    puts(
      "[#{status} #{number}/#{conference_data.length}] " \
      "#{conference.name}"
    )

    puts "  Date: #{conference.starts_on} — #{conference.ends_on}"
    puts "  Deadline: #{conference.submission_deadline}"
    puts "  Location: #{conference.location}"
    puts "  Topics: #{conference.topic_names}"
  rescue KeyError => error
    statistics[:skipped] += 1

    puts(
      "[SKIPPED #{number}/#{conference_data.length}] " \
      "#{name.empty? ? '(unnamed conference)' : name}"
    )

    puts "  Missing JSON key: #{error.message}"
  rescue Date::Error => error
    statistics[:skipped] += 1

    puts(
      "[SKIPPED #{number}/#{conference_data.length}] " \
      "#{name.empty? ? '(unnamed conference)' : name}"
    )

    puts "  Invalid date: #{error.message}"
  rescue ActiveRecord::RecordInvalid => error
    statistics[:failed] += 1

    puts(
      "[FAILED #{number}/#{conference_data.length}] " \
      "#{name.empty? ? '(unnamed conference)' : name}"
    )

    puts(
      "  Validation errors: " \
      "#{error.record.errors.full_messages.join(', ')}"
    )
  rescue StandardError => error
    statistics[:failed] += 1

    puts(
      "[FAILED #{number}/#{conference_data.length}] " \
      "#{name.empty? ? '(unnamed conference)' : name}"
    )

    puts "  #{error.class}: #{error.message}"

    if ENV["DEBUG"] == "true"
      puts error.backtrace.join("\n")
    end
  end

  puts
end

puts "=" * 80
puts "Import completed"
puts "=" * 80
puts "JSON records: #{statistics[:total]}"
puts "Created: #{statistics[:created]}"
puts "Updated: #{statistics[:updated]}"
puts "Skipped: #{statistics[:skipped]}"
puts "Failed: #{statistics[:failed]}"
puts "Database conferences: #{Conference.count}"
puts "=" * 80

exit(
  statistics[:failed].positive? ? 1 : 0
)
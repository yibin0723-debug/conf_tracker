# frozen_string_literal: true

require "date"
require "fileutils"
require "json"
require "net/http"
require "nokogiri"
require "time"
require "uri"

class ConferenceAlertsCrawler
  BASE_URL = "https://conferencealerts.com"

  LIST_URL = URI(
    "#{BASE_URL}/topic-listing.php?" \
    "ipp=All&" \
    "page=1&" \
    "topic=artificial%20intelligence"
  )

  USER_AGENT =
    "ConferenceTrackerStudentProject/0.2 " \
    "(educational crawler; low request frequency)"

  MONTH_PATTERN =
    /\A(?:January|February|March|April|May|June|July|August|
         September|October|November|December)\s+\d{4}\z/x

  def initialize(
    limit: nil,
    detail_limit: 0,
    filter_past: true,
    sample_path: nil,
    request_delay: 1.5
  )
    @limit = limit
    @detail_limit = detail_limit
    @filter_past = filter_past
    @sample_path = sample_path
    @request_delay = request_delay
  end

  def call
    list_html =
      if @sample_path
        read_sample(@sample_path)
      else
        fetch_html(LIST_URL)
      end

    conferences = parse_list(list_html)
    conferences = remove_duplicates(conferences)

    if @filter_past
      conferences =
        conferences.select do |conference|
          Date.iso8601(conference[:event_date]) >= Date.today
        end
    end

    conferences = conferences.first(@limit) if @limit

    enrich_conferences(conferences)

    {
      source: "conference_alerts",
      topic: "artificial intelligence",
      fetched_at: Time.now.utc.iso8601,
      count: conferences.length,
      detail_limit: @detail_limit,
      details_fetched:
        conferences.count do |conference|
          conference[:detail_status] == "ok"
        end,
      conferences: conferences
    }
  end

  private

  # ==================================================
  # 网络请求
  # ==================================================

  def fetch_html(uri, redirect_limit: 5)
    raise "Too many redirects" if redirect_limit <= 0

    request = Net::HTTP::Get.new(uri)

    request["User-Agent"] = USER_AGENT
    request["Accept"] =
      "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    request["Accept-Language"] = "en-US,en;q=0.9"
    request["Connection"] = "close"

    response =
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 10,
        read_timeout: 30
      ) do |http|
        http.request(request)
      end

    case response
    when Net::HTTPSuccess
      response.body

    when Net::HTTPRedirection
      location = response["location"]

      unless location
        raise "Redirect response does not contain a Location header"
      end

      redirected_uri =
        URI.join(
          uri.to_s,
          location
        )

      fetch_html(
        redirected_uri,
        redirect_limit: redirect_limit - 1
      )

    else
      raise(
        "HTTP request failed: " \
        "#{response.code} #{response.message}"
      )
    end
  rescue Timeout::Error => error
    raise "Request timed out: #{error.message}"
  rescue SocketError, SystemCallError => error
    raise "Network error: #{error.class}: #{error.message}"
  end

  def read_sample(path)
    expanded_path = File.expand_path(path)

    unless File.exist?(expanded_path)
      raise "Sample HTML does not exist: #{expanded_path}"
    end

    File.read(expanded_path)
  end

  # ==================================================
  # 列表页解析
  # ==================================================

  def parse_list(html)
    document = Nokogiri::HTML.parse(html)
    conference_table = find_conference_table(document)

    unless conference_table
      raise(
        "Conference table was not found. " \
        "The website structure may have changed."
      )
    end

    conferences = []
    current_month_year = nil

    conference_table.css("tr").each do |row|
      cells = row.xpath("./td")

      next if cells.empty?

      month_year = parse_month_header(cells)

      if month_year
        current_month_year = month_year
        next
      end

      conference =
        parse_conference_row(
          cells,
          current_month_year
        )

      conferences << conference if conference
    end

    conferences
  end

  def find_conference_table(document)
    document.css("table").find do |table|
      table.at_css(
        'span#searchName a[href*="show-event"]'
      )
    end
  end

  def parse_month_header(cells)
    return unless cells.length == 1

    cell = cells.first
    return unless cell["colspan"] == "2"

    strong = cell.at_css("strong")
    return unless strong

    month_year = clean_text(strong.text)

    return unless month_year.match?(MONTH_PATTERN)

    month_year
  end

  def parse_conference_row(cells, month_year)
    return unless cells.length == 2
    return unless month_year

    day_cell = cells[0]
    details_cell = cells[1]

    event_link =
      details_cell.at_css(
        'span#searchName a[href*="show-event"]'
      )

    return unless event_link

    event_date =
      parse_list_event_date(
        day_cell.text,
        month_year
      )

    return unless event_date

    location_node =
      details_cell.at_css(
        "span#searchPlace"
      )

    attendance_node =
      find_attendance_node(details_cell)

    source_url =
      URI.join(
        "#{BASE_URL}/",
        event_link["href"]
      ).to_s

    {
      name: clean_text(event_link.text),
      event_date: event_date.iso8601,
      end_date: nil,

      location:
        blank_to_nil(
          clean_text(location_node&.text)
        ),

      attendance_mode:
        blank_to_nil(
          clean_text(attendance_node&.text)
        ),

      submission_deadline: nil,
      website_url: nil,
      contact_person: nil,
      organizer: nil,
      publication: nil,

      topics: [
        "artificial intelligence"
      ],

      source: "conference_alerts",
      source_url: source_url,
      detail_status: "not_fetched"
    }
  end

  def find_attendance_node(details_cell)
    details_cell.css("span").find do |span|
      class_name = span["class"].to_s
      text = clean_text(span.text)

      class_name.include?("badge") ||
        text.match?(
          /\A(?:online|in-person|online and in-person)\z/i
        )
    end
  end

  def parse_list_event_date(day_text, month_year)
    match =
      clean_text(day_text).match(
        /\A(\d{1,2})(?:st|nd|rd|th)?\z/i
      )

    return unless match

    Date.strptime(
      "#{match[1]} #{month_year}",
      "%d %B %Y"
    )
  rescue Date::Error => error
    warn(
      "List date parsing failed: " \
      "day=#{day_text.inspect}, " \
      "month=#{month_year.inspect}, " \
      "error=#{error.message}"
    )

    nil
  end

  # ==================================================
  # 详情页抓取
  # ==================================================

  def enrich_conferences(conferences)
    detail_count =
      [
        @detail_limit,
        conferences.length
      ].min

    conferences.each_with_index do |conference, index|
      if index >= detail_count
        conference[:detail_status] = "not_fetched"
        next
      end

      sleep(@request_delay) if index.positive?

      begin
        puts(
          "Fetching detail #{index + 1}/#{detail_count}: " \
          "#{conference[:name]}"
        )

        detail_html =
          fetch_html(
            URI(conference[:source_url])
          )

        details = parse_detail(detail_html)

        conference.merge!(details)
        conference[:detail_status] = "ok"
      rescue StandardError => error
        conference[:detail_status] = "failed"
        conference[:detail_error] =
          "#{error.class}: #{error.message}"

        warn(
          "Detail fetch failed for " \
          "#{conference[:source_url]}: " \
          "#{error.class}: #{error.message}"
        )
      end
    end
  end

  # ==================================================
  # 详情页解析
  # ==================================================

  def parse_detail(html)
    document = Nokogiri::HTML.parse(html)
    container = find_detail_container(document)

    unless container
      raise "Detail container was not found"
    end

    text = clean_text(container.text)

    detail_start_date, detail_end_date =
      parse_detail_date_range(text)

    {
      detail_start_date:
        detail_start_date&.iso8601,

      end_date:
        detail_end_date&.iso8601,

      submission_deadline:
        parse_submission_deadline(text)&.iso8601,

      website_url:
        extract_official_website(container),

      contact_person:
        blank_to_nil(
          extract_section(
            text,
            "Contact person:",
            [
              "Publication:",
              "Organized by:",
              "Deadline for abstracts/proposals:",
              "Check the event website"
            ]
          )
        ),

      publication:
        blank_to_nil(
          extract_section(
            text,
            "Publication:",
            [
              "Organized by:",
              "Deadline for abstracts/proposals:",
              "Check the event website"
            ]
          )
        ),

      organizer:
        blank_to_nil(
          extract_section(
            text,
            "Organized by:",
            [
              "Deadline for abstracts/proposals:",
              "Check the event website"
            ]
          )
        )
    }
  end

  def find_detail_container(document)
    document.css("td").find do |cell|
      text = clean_text(cell.text)

      text.include?("Website:") &&
        text.include?(
          "Deadline for abstracts/proposals:"
        )
    end || document.at_css("body")
  end

  # ==================================================
  # 官网链接
  # ==================================================

  def extract_official_website(container)
    link =
      container.css("a[href]").find do |candidate|
        external_website_url?(
          candidate["href"]
        )
      end

    link&.[]("href")
  end

  def external_website_url?(href)
    return false if href.to_s.empty?

    uri = URI.parse(href)

    return false unless uri.is_a?(URI::HTTP)

    host = uri.host.to_s.downcase

    return false if host.include?("conferencealerts.com")
    return false if host.include?("google.com")

    true
  rescue URI::InvalidURIError
    false
  end

  # ==================================================
  # 详情页日期范围
  # ==================================================

  def parse_detail_date_range(text)
    # 例：
    # 30th July 2026 to 1st August 2026
    match =
      text.match(
        /(\d{1,2})(?:st|nd|rd|th)?\s+
         ([A-Za-z]+)\s+
         (\d{4})\s+
         to\s+
         (\d{1,2})(?:st|nd|rd|th)?\s+
         ([A-Za-z]+)\s+
         (\d{4})/ix
      )

    if match
      start_date =
        build_date(
          match[1],
          match[2],
          match[3]
        )

      end_date =
        build_date(
          match[4],
          match[5],
          match[6]
        )

      return [
        start_date,
        end_date
      ]
    end

    # 例：
    # 30th July to 1st August 2026
    match =
      text.match(
        /(\d{1,2})(?:st|nd|rd|th)?\s+
         ([A-Za-z]+)\s+
         to\s+
         (\d{1,2})(?:st|nd|rd|th)?\s+
         ([A-Za-z]+)\s+
         (\d{4})/ix
      )

    if match
      year = match[5]

      start_date =
        build_date(
          match[1],
          match[2],
          year
        )

      end_date =
        build_date(
          match[3],
          match[4],
          year
        )

      return [
        start_date,
        end_date
      ]
    end

    # 例：
    # 30th to 31st July 2026
    match =
      text.match(
        /(\d{1,2})(?:st|nd|rd|th)?\s+
         to\s+
         (\d{1,2})(?:st|nd|rd|th)?\s+
         ([A-Za-z]+)\s+
         (\d{4})/ix
      )

    if match
      start_date =
        build_date(
          match[1],
          match[3],
          match[4]
        )

      end_date =
        build_date(
          match[2],
          match[3],
          match[4]
        )

      return [
        start_date,
        end_date
      ]
    end

    [
      nil,
      nil
    ]
  rescue Date::Error => error
    warn "Detail date parsing failed: #{error.message}"

    [
      nil,
      nil
    ]
  end

  def build_date(day, month, year)
    Date.strptime(
      "#{day} #{month} #{year}",
      "%d %B %Y"
    )
  end

  # ==================================================
  # 投稿截止日期
  # ==================================================

  def parse_submission_deadline(text)
    match =
      text.match(
        /Deadline\s+for\s+abstracts\/proposals:\s*
         (\d{1,2})(?:st|nd|rd|th)?\s+
         ([A-Za-z]+)\s+
         (\d{4})/ix
      )

    return unless match

    build_date(
      match[1],
      match[2],
      match[3]
    )
  rescue Date::Error => error
    warn(
      "Submission deadline parsing failed: " \
      "#{error.message}"
    )

    nil
  end

  # ==================================================
  # 文本字段提取
  # ==================================================

  def extract_section(text, label, following_labels)
    stopping_pattern =
      following_labels
        .map do |following_label|
          Regexp.escape(following_label)
        end
        .join("|")

    pattern =
      /#{Regexp.escape(label)}
       \s*
       (.*?)
       (?=#{stopping_pattern}|\z)/ix

    match = text.match(pattern)

    return "" unless match

    clean_text(match[1])
  end

  # ==================================================
  # 去重、排序、清洗
  # ==================================================

  def remove_duplicates(conferences)
    conferences
      .uniq do |conference|
        conference[:source_url]
      end
      .sort_by do |conference|
        [
          conference[:event_date],
          conference[:name]
        ]
      end
  end

  def clean_text(text)
    text
      .to_s
      .gsub("\u00A0", " ")
      .gsub(/\s+/, " ")
      .strip
  end

  def blank_to_nil(value)
    value.to_s.empty? ? nil : value
  end
end

# ==================================================
# 程序入口
# ==================================================

begin
  output_directory =
    File.expand_path(
      "output",
      __dir__
    )

  FileUtils.mkdir_p(output_directory)

  output_path =
    File.join(
      output_directory,
      "conference_alerts_ai.json"
    )

  sample_path = ENV["SAMPLE_HTML"]

  limit =
    if ENV["CRAWL_LIMIT"].to_s.empty?
      nil
    else
      Integer(
        ENV["CRAWL_LIMIT"],
        10
      )
    end

  detail_limit =
    Integer(
      ENV.fetch(
        "DETAIL_LIMIT",
        "0"
      ),
      10
    )

  filter_past =
    ENV.fetch(
      "FILTER_PAST",
      "true"
    ) != "false"

  request_delay =
    Float(
      ENV.fetch(
        "REQUEST_DELAY",
        "1.5"
      )
    )

  crawler =
    ConferenceAlertsCrawler.new(
      limit: limit,
      detail_limit: detail_limit,
      filter_past: filter_past,
      sample_path: sample_path,
      request_delay: request_delay
    )

  payload = crawler.call

  File.write(
    output_path,
    JSON.pretty_generate(payload)
  )

  puts
  puts "=" * 70
  puts "Conference Alerts crawler finished"
  puts "=" * 70
  puts "Source: #{payload[:source]}"
  puts "Topic: #{payload[:topic]}"
  puts "Conference count: #{payload[:count]}"
  puts "Details fetched: #{payload[:details_fetched]}"
  puts "Output: #{output_path}"
  puts

  if payload[:conferences].empty?
    puts "No conferences were found."
  else
    puts "First three conferences:"
    puts

    payload[:conferences]
      .first(3)
      .each_with_index do |conference, index|
        puts "#{index + 1}. #{conference[:name]}"
        puts "   Start date: #{conference[:event_date]}"
        puts "   End date: #{conference[:end_date]}"
        puts "   Deadline: #{conference[:submission_deadline]}"
        puts "   Location: #{conference[:location]}"
        puts "   Mode: #{conference[:attendance_mode]}"
        puts "   Website: #{conference[:website_url]}"
        puts "   Organizer: #{conference[:organizer]}"
        puts "   Detail status: #{conference[:detail_status]}"
        puts "   Source URL: #{conference[:source_url]}"
        puts
      end
  end
rescue StandardError => error
  warn "=" * 70
  warn "Crawler failed"
  warn "=" * 70
  warn "#{error.class}: #{error.message}"

  if ENV["DEBUG"] == "true"
    warn
    warn error.backtrace.join("\n")
  end

  exit 1
end
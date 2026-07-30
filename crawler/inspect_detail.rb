# frozen_string_literal: true

require "nokogiri"

path =
  File.expand_path(
    "output/detail_sample.html",
    __dir__
  )

unless File.exist?(path)
  abort "Detail sample does not exist: #{path}"
end

html = File.read(path)
document = Nokogiri::HTML.parse(html)

def clean_text(text)
  text
    .to_s
    .gsub("\u00A0", " ")
    .gsub(/\s+/, " ")
    .strip
end

puts "=" * 80
puts "PAGE TITLE"
puts "=" * 80
puts document.title
puts

puts "=" * 80
puts "HEADINGS"
puts "=" * 80

document.css("h1, h2, h3, h4, h5, strong").each_with_index do |node, index|
  text = clean_text(node.text)
  next if text.empty?

  puts "#{index}: <#{node.name}> #{text.inspect}"
end

puts
puts "=" * 80
puts "TABLE ROWS"
puts "=" * 80

document.css("tr").each_with_index do |row, row_index|
  cells = row.xpath("./th|./td")
  next if cells.empty?

  texts =
    cells.map do |cell|
      clean_text(cell.text)
    end

  next if texts.all?(&:empty?)

  puts "ROW #{row_index}: #{texts.inspect}"

  row.css("a[href]").each do |link|
    puts(
      "  LINK: " \
      "#{clean_text(link.text).inspect} " \
      "=> #{link["href"].inspect}"
    )
  end
end

puts
puts "=" * 80
puts "POSSIBLE IMPORTANT TEXT"
puts "=" * 80

keywords = [
  "deadline",
  "submission",
  "website",
  "conference website",
  "important date",
  "abstract",
  "description"
]

document.css("body *").each do |node|
  next unless node.element?
  next unless node.element_children.empty?

  text = clean_text(node.text)
  next if text.empty?
  next if text.length > 500

  if keywords.any? { |keyword| text.downcase.include?(keyword) }
    puts "<#{node.name}> #{text.inspect}"
  end
end
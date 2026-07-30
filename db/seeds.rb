admin_email = ENV.fetch(
  "SEED_ADMIN_EMAIL",
  "admin@conf-tracker.local"
)
admin_password = ENV.fetch(
  "SEED_ADMIN_PASSWORD",
  "admin12345"
)

scientist_email = ENV.fetch(
  "SEED_SCIENTIST_EMAIL",
  "scientist@conf-tracker.local"
)
scientist_password = ENV.fetch(
  "SEED_SCIENTIST_PASSWORD",
  "science12345"
)

conference_rows = [
  {
    name: "NeurIPS",
    location: "Vancouver, Canada",
    starts_on: Date.new(2024, 12, 10),
    ends_on: Date.new(2024, 12, 15),
    rating: "A*",
    website_url: "https://neurips.cc/",
    description: "Conference on Neural Information Processing Systems.",
    topics: [
      "Artificial Intelligence",
      "Machine Learning",
      "Neural Networks"
    ]
  },
  {
    name: "ICML",
    location: "Vienna, Austria",
    starts_on: Date.new(2024, 7, 21),
    ends_on: Date.new(2024, 7, 27),
    rating: "A*",
    website_url: "https://icml.cc/",
    description: "International Conference on Machine Learning.",
    topics: [
      "Artificial Intelligence",
      "Machine Learning"
    ]
  },
  {
    name: "ICLR",
    location: "Vienna, Austria",
    starts_on: Date.new(2024, 5, 7),
    ends_on: Date.new(2024, 5, 11),
    rating: "A*",
    website_url: "https://iclr.cc/",
    description: "International Conference on Learning Representations.",
    topics: [
      "Deep Learning",
      "Machine Learning",
      "Representation Learning"
    ]
  },
  {
    name: "AAAI Conference on Artificial Intelligence",
    location: "Vancouver, Canada",
    starts_on: Date.new(2024, 2, 20),
    ends_on: Date.new(2024, 2, 27),
    rating: "A",
    website_url: "https://aaai.org/conference/",
    description: "Annual AAAI Conference on Artificial Intelligence.",
    topics: [
      "Artificial Intelligence",
      "Knowledge Representation"
    ]
  },
  {
    name: "CVPR",
    location: "Seattle, USA",
    starts_on: Date.new(2024, 6, 17),
    ends_on: Date.new(2024, 6, 21),
    rating: "A*",
    website_url: "https://cvpr.thecvf.com/",
    description: "IEEE/CVF Conference on Computer Vision and Pattern Recognition.",
    topics: [
      "Computer Vision",
      "Deep Learning",
      "Image Processing"
    ]
  },
  {
    name: "ECCV",
    location: "Milan, Italy",
    starts_on: Date.new(2024, 9, 29),
    ends_on: Date.new(2024, 10, 4),
    rating: "A",
    website_url: "https://eccv.ecva.net/",
    description: "European Conference on Computer Vision.",
    topics: [
      "Computer Vision",
      "Image Processing"
    ]
  },
  {
    name: "ACL",
    location: "Bangkok, Thailand",
    starts_on: Date.new(2024, 8, 11),
    ends_on: Date.new(2024, 8, 16),
    rating: "A",
    website_url: "https://2024.aclweb.org/",
    description: "Annual Meeting of the Association for Computational Linguistics.",
    topics: [
      "Computational Linguistics",
      "Natural Language Processing"
    ]
  },
  {
    name: "EMNLP",
    location: "Miami, USA",
    starts_on: Date.new(2024, 11, 12),
    ends_on: Date.new(2024, 11, 16),
    rating: "A",
    website_url: "https://2024.emnlp.org/",
    description: "Conference on Empirical Methods in Natural Language Processing.",
    topics: [
      "Machine Learning",
      "Natural Language Processing"
    ]
  },
  {
    name: "KDD",
    location: "Barcelona, Spain",
    starts_on: Date.new(2024, 8, 25),
    ends_on: Date.new(2024, 8, 29),
    rating: "A",
    website_url: "https://kdd.org/kdd2024/",
    description: "ACM SIGKDD Conference on Knowledge Discovery and Data Mining.",
    topics: [
      "Data Mining",
      "Knowledge Discovery",
      "Machine Learning"
    ]
  },
  {
    name: "WWW (The Web Conference)",
    location: "Singapore",
    starts_on: Date.new(2024, 5, 13),
    ends_on: Date.new(2024, 5, 17),
    rating: "A",
    website_url: "https://www2024.thewebconf.org/",
    description: "International World Wide Web Conference.",
    topics: [
      "Data Mining",
      "Information Retrieval",
      "Web Technologies"
    ]
  }
]

conference_rows.each do |attributes|
  topic_names = attributes.fetch(:topics)

  conference =
    Conference.find_or_initialize_by(name: attributes.fetch(:name))

  conference.update!(
    attributes
      .except(:topics)
      .merge(
        # Development demonstration value:
        # 120 days before the conference begins.
        submission_deadline: attributes.fetch(:starts_on) - 120
      )
  )

  conference.replace_topics!(topic_names)
end

admin = User.find_or_initialize_by(email_address: admin_email)
admin.password = admin_password
admin.password_confirmation = admin_password
admin.admin = true
admin.save!

scientist =
  User.find_or_initialize_by(email_address: scientist_email)

scientist.password = scientist_password
scientist.password_confirmation = scientist_password
scientist.admin = false
scientist.save!

puts "Seeded #{Conference.count} conferences"
puts "Seeded #{Topic.count} topics"
puts "Seeded #{ConferenceTopic.count} conference-topic links"
puts "Admin: #{admin.email_address}"
puts "Scientist: #{scientist.email_address}"

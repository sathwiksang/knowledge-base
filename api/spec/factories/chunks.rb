FactoryBot.define do
  factory :chunk do
    document
    content { Faker::Lorem.paragraph }
    sequence(:chunk_index)
    embedding { Array.new(768) { rand(-1.0..1.0) } }
  end
end

FactoryBot.define do
  factory :knowledge_base do
    user
    name { Faker::Lorem.unique.words(number: 3).join(' ') }
    description { Faker::Lorem.paragraph }
  end
end

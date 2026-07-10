FactoryBot.define do
  factory :document do
    knowledge_base
    title { Faker::Lorem.sentence }
    content { Faker::Lorem.paragraphs(number: 5).join("\n\n") }
    status { 'pending' }
    metadata { { 'source' => 'factory', 'created_by' => 'rspec' } }

    trait :processing do
      status { 'processing' }
    end

    trait :indexed do
      status { 'indexed' }
    end

    trait :failed do
      status { 'failed' }
      metadata { { 'error' => 'Processing failed' } }
    end
  end
end

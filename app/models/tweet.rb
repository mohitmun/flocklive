class Tweet < ActiveRecord::Base

  after_create :after_create
  has_many :hashtag_mappings
  has_many :hashtags, :through => :hashtag_mappings, :source => :hashtag
  
  def after_create
    hashtags_string = content.scan(/#\S+/)
    hashtags_string.each do |hashtag|
      hashtags.create(content: hashtag)
    end
  end

end

class Hashtag < ActiveRecord::Base
  has_many :hashtag_mappings
  has_many :tweets, :through => :hashtag_mappings, :source => :tweet
  validates_uniqueness_of :content
end

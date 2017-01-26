class Hashtag < ActiveRecord::Base
  has_many :hashtag_mappings
  has_many :reactions, as: :item
  has_many :tweets, :through => :hashtag_mappings, :source => :tweet
  validates_uniqueness_of :content


  def reaction_types
    reaction_types = reactions.pluck(:reaction_type)
    histogram = reaction_types.inject(Hash.new(0)) { |hash, x| hash[x] += 1; hash}
    reaction_types.sort_by { |x| [histogram[x], x] }.reverse
  end
end

class HashtagMapping < ActiveRecord::Base
  belongs_to :tweet
  belongs_to :hashtag
  validates :hashtag_id, uniqueness: { scope: :tweet_id }

end

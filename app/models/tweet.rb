class Tweet < ActiveRecord::Base

  after_create :after_create
  has_many :hashtag_mappings
  has_many :hashtags, :through => :hashtag_mappings, :source => :hashtag
  store_accessor :json_store, :message_id, :chat_id, :public_tweet

  def after_create
    hashtags_string = content.scan(/#\S+/)
    hashtags_string.each do |hashtag|
      hashtags.create(content: hashtag[1..-1])
    end
  end

  def flock_ml
    # <flockml> click <action id='act1' type='openWidget' url='https://15dafcac.ngrok.io/tweets?hashtag=adas' desktopType='sidebar' mobileType='modal'>here</action> to launch a widget. </flockml>
    root = content
    hashtags.each do |h|
      hashtag_link = "<action id='act1' type='openWidget' url='https://15dafcac.ngrok.io/tweets?hashtag=#{h.content}' desktopType='sidebar' mobileType='modal'>##{h.content}</action>"
      root = root.gsub("##{h.content}", hashtag_link)
    end
    "<flockml> #{root} </flockml>"
  end

  def html_view
    # <flockml> click <action id='act1' type='openWidget' url='https://15dafcac.ngrok.io/tweets?hashtag=adas' desktopType='sidebar' mobileType='modal'>here</action> to launch a widget. </flockml>
    root = content
    hashtags.each do |h|
      hashtag_link = "<a href='https://15dafcac.ngrok.io/tweets?hashtag=#{h.content}'>##{h.content}</a>"
      root = root.gsub("##{h.content}", hashtag_link)
    end
    return root
  end

end

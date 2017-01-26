class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # protect_from_forgery with: :exception
  before_filter :permit_params
  # before_filter :login_if_not, :except => [:connect_google, :oauth2_callback_google, :youtube_liked, :send_to_telegram, :flock_events]
  before_filter :allow_iframe_requests

  def allow_iframe_requests
    response.headers.delete('X-Frame-Options')
  end

  def drive
    @query = params["query"] || ""
    render "welcome/drive"
  end

  def trends
    @query = params["query"] || ""
    render "welcome/trends"
  end

  def change_visibility
    tweet = Tweet.find(params[:tweet_id]) rescue nil
    # tweet.delete rescue nil
    tweet.next_visibility rescue nil
    redirect_to my_tweets_path
  end

  def tweets
    @tweets = Tweet.viewable(@current_user.teamId)
    hashtag = Hashtag.find_by(content: params[:hashtag])
    if !hashtag.blank?
      @title = "##{hashtag.content}"
    end
    @tweets = hashtag.tweets.viewable(@current_user.teamId) rescue @tweets
    render "welcome/tweets"
  end

  def my_tweets
    # hashtag = Hashtag.find_by(content: params[:hashtag])
    @tweets = Tweet.where(from_id: current_user1.flock_user_id).order(:created_at => :desc) rescue []
    render "welcome/tweets"
  end

  def create_event
    current_user.schedule(params[:summary], params[:start], params[:end])
    render json: {message: "ok"}, status: 200
  end

  def agenda
    render "welcome/agenda"
  end

  def attach
    # raise params.inspect
    file_id = params["file_id"]
    file_name = params["file_name"]
    mime = params["mime"]
    # file = current_user.get_drive_instance.get_file(file_id)
    # current_user.download(file_id, file_name)
    url = root_url+"download?file_name=#{file_name}&file_id=#{file_id}"
    attachments = {"src":  url.gsub("[","%5B").gsub("]","%5D").gsub(" ", "%20"), "mime": mime , "filename": file_name, "size": Random.new.rand(3 *1000*1000) }
    current_user.send_to_id(JSON.parse(params["flockEvent"])["chat"] ,"Attachments",attachments)
    redirect_to params["redirect_to"]
  end

  def download
    file_id = params["file_id"]
    file_name = params["file_name"]
    current_user.download(file_id, file_name)
    url = root_url + file_name
    url = url.gsub("[","%5B").gsub("]","%5D").gsub(" ", "%20")
    send_file "public/#{file_name}", :x_sendfile=>true
  end

  def permit_params
    params.permit!
    if params[:flockValidationToken]
      decoded_token = JWT.decode params[:flockValidationToken], "fb90273c-7bff-4aaf-83de-3722712f2c46", true, { :algorithm => 'HS256' }
      session[:current_user_id] = User.find_by(flock_user_id: decoded_token[0]["userId"]).id rescue nil
    end
    if params[:flockEventToken]
      decoded_token = JWT.decode params[:flockEventToken], "fb90273c-7bff-4aaf-83de-3722712f2c46", true, { :algorithm => 'HS256' }
      session[:current_user_id] = User.find_by(flock_user_id: decoded_token[0]["userId"]).id rescue nil
    end
    current_user1

  end

  def current_user
    puts "inside current_user"
    u = User.find session[:current_user_id] if session[:current_user_id]
    if u.blank?
      u = User.find_by(flock_user_id: params["userId"])
      puts "====="
      puts u.inspect
      puts "====="
    end
    return u
  end

  def current_user1
    puts "inside current_user"

     u = User.find session[:current_user_id] if session[:current_user_id]
    if u.blank?
      u = User.find_by(flock_user_id: params["userId"])
      puts "====="
      puts u.inspect
      puts "====="
    end
    @current_user = u
    if u.teamId.blank? && u.profileImage.blank?
      info = u.get_info
      u.teamId = info["teamId"]
      u.profileImage = info["profileImage"]
      u.save
    end
    return u
  end

  def gmail_inbound
    data = params["message"]["data"]
    decoded_data = JSON.parse(Base64.decode64(data))
    puts "=="*100
    puts decoded_data
    puts "=="*100
    history_id = decoded_data["historyId"]
    user_email_address = decoded_data["emailAddress"]
    user = User.find_by(gmail_address: user_email_address)
    if user
      user.delay(run_at: 10.seconds.from_now).get_history(history_id,root_url)
    end
    render json: {message: "ok"}, status: 200
  end

  def login_if_not
    if !user_signed_in?
      session[:redirect_to] = request.path
      redirect_to "/connect/google"
    end
  end

  def replyModal
    render 'welcome/replymodal'
  end

  def submit_reply
    current_user = User.find_by(flock_user_id: params[:flock_user_id])
    current_user.send_mail(params[:to], "Re: " + params[:subject], params[:body])
    render json: {message: "ok"}, status: 200
  end

  def flock_landing
    google_connected = false
    if current_user
      credentials = current_user.get_credentials
      authorizer = current_user.get_authorizer
      if !credentials.nil?
        @message = "Google Connected"
      else
        url = authorizer.get_authorization_url(base_url: root_url)
        puts "Open the following URL in your browser and authorize the application."
        puts url
        puts "Enter the authorization code:"
        @google_consent_url = url
      end
    else
      @message = "Please install Google For Work in Flock"
    end
    render 'welcome/index'
  end

  def flock_events
    puts "="*100
    puts params.inspect
    puts "="*100
    case params["name"]
    when "app.uninstall"
      @current_user.delete
    when "app.install"
      # localhost:3000/flock_events?token=98ac35f0-7b3e-4f0c-97df-e43614cce558&name=app.install&userId="u:auecvebiuce2xcjb"
      user = User.find_or_create_by(flock_user_id: params["userId"]) do |u|
        u.flock_token = params["token"]
        u.email = "#{params['userId'].split(':')[1]}@flockgfw.com"
        u.password = "User1234"
      end
      puts "==="*10
      puts user.inspect
      puts "==="*10
      # user.create_token_store
    when "client.pressButton"
      current_user = User.find_by(flock_user_id: params["userId"])
      if params["buttonId"].include?("calender")
        current_user.schedule(params["buttonId"].split(":")[1], (Time.now + 1.hours).to_s , (Time.now + 2.hours).to_s)
      elsif params["buttonId"].include?("reply")
        # from = params["buttonId"].split(":")[1]
        # subject = params["buttonId"].split(":")[2]
        # current_user.send_mail()
      end
    when "chat.receiveMessage"
      message = params["message"]
      text = message["text"]
      if text.split(" ")[0].to_s.downcase == "reply"
        user = User.find_by(flock_user_id: message["from"])
        user.send_mail(user.last_message["From"], "Re: #{user.last_message['Subject']}", text.split(" ")[1..-1])
      end
      # {"message"=>{"type"=>"CHAT", "id"=>"00003018-0000-0022-0000-000000c5862b", "to"=>"u:Br1h5szr7skwk1wz", "from"=>"u:auecvebiuce2xcjb", "actor"=>"", "text"=>"reply Cool buddy", "uid"=>"1477129719302-tRXqKC-mh105"}, "name"=>"chat.receiveMessage", "userId"=>"u:auecvebiuce2xcjb"}
    when "client.messageAction"
      # {"chat"=>"u:Br1h5szr7skwk1wz", "name"=>"client.messageAction", "chatName"=>"HackTest2 Bot", "userName"=>"mohit munjani", "userId"=>"u:auecvebiuce2xcjb", "messageUids"=>["1485427478629-R29S8w-apollo-z6"], "controller"=>"application", "action"=>"flock_events", "application"=>{"chat"=>"u:Br1h5szr7skwk1wz", "name"=>"client.messageAction", "chatName"=>"HackTest2 Bot", "userName"=>"mohit munjani", "userId"=>"u:auecvebiuce2xcjb", "messageUids"=>["1485427478629-R29S8w-apollo-z6"]}}
      @rendered = true
      action_message = ""
      message_id = params["messageUids"][0]
      t = Tweet.where("json_store ->> 'message_id' = ?", message_id).last
      message = current_user1.fetch_message(params["chat"], message_id)
      if t.blank?
        Tweet.create(content: message["text"], to_id: message["to"], from_id: message["from"], chat_id: params["chat"], visibility: "team", message_id: message_id)
        action_message = "Anyone in team can view this message Now. Press again to make it viewable across all Flock users"
      elsif t.visibility == "team"
        t.visibility = "flock"
        t.save
        action_message = "All users on Flock can view this message Now. Press again to make it private to this chat"
      elsif t.visibility == "flock"
        t.visibility = "private"
        t.save
        action_message = "Message is private now. Press again to make it viewable to your team"
      end
      render json: {text: action_message}
    when "client.slashCommand"
      tweet = params["text"]
      t = Tweet.create(visibility: "team", content: tweet, sender_id: params["userId"], from: params["userName"], chat_id: params["chat"])
      response = current_user1.send_to_id(params["chat"], tweet_ml, nil)
      uid = JSON.parse(response)["uid"]
      t.message_id = uid
      t.save
    end
    # {"userToken"=>"98ac35f0-7b3e-4f0c-97df-e43614cce558", "token"=>"98ac35f0-7b3e-4f0c-97df-e43614cce558", "name"=>"app.install", "userId"=>"u:auecvebiuce2xcjb", "controller"=>"application", "action"=>"flock_events", "application"=>{"userToken"=>"98ac35f0-7b3e-4f0c-97df-e43614cce558", "token"=>"98ac35f0-7b3e-4f0c-97df-e43614cce558", "name"=>"app.install", "userId"=>"u:auecvebiuce2xcjb"}}

    if !@rendered
      render json: {message: "ok"}, status: 200
    end
  end

  def connect_google
    credentials = User.initialize_google_credentials
    redirect_to credentials.authorization_uri.to_s
  end

  def oauth2_callback_google
    authorizer = current_user.get_authorizer
    credentials = authorizer.get_and_store_credentials_from_code(user_id: "", code: params["code"], base_url: root_url)
    current_user.update_attribute(:gmail_address, current_user.get_gmail_instance.get_user_profile("me").email_address)
    wr = Google::Apis::GmailV1::WatchRequest.new
    wr.topic_name = "projects/plucky-bulwark-676/topics/gmail"
    wr.label_ids = ["INBOX"]
    current_user.get_gmail_instance.watch_user("me", wr)
    redirect_to root_url
    # credentials = User.initialize_google_credentials
    # credentials.code = params["code"]
    # credentials.fetch_access_token!
    # user = User.save_from_google_user(credentials)
    # sign_in(:user, user)
    # if session[:redirect_to]
    #   redirect_to session[:redirect_to]
    # else
    #   redirect_to root_url
    # end
  end

  def send_to_telegram
    title = params[:title]
    content = params[:content]
    link = params[:link]
    RestClient.post("https://api.telegram.org/bot287297665:AAGf5sJQeRa_l8-JGre-GkwTtaXV-3IDGH4/sendMessage", {"chat_id": 230551077, "text": "*#{title}*\n#{content} [link](#{link})", parse_mode: "Markdown", disable_web_page_preview: true})
    head :ok
  end

  def file
    params.permit!
    file_name = params["name"]
    send_file("#{Rails.root}/tmp/#{file_name}")
  end

  def index
    
  end
end

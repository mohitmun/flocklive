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
      decoded_token = JWT.decode params[:flockValidationToken], "e716b534-55ff-45f4-b662-725ed9e39936", true, { :algorithm => 'HS256' }
      session[:current_user_id] = User.find_by(flock_user_id: decoded_token[0]["userId"]).id rescue nil
    end
    if params[:flockEventToken]
      decoded_token = JWT.decode params[:flockEventToken], "e716b534-55ff-45f4-b662-725ed9e39936", true, { :algorithm => 'HS256' }
      session[:current_user_id] = User.find_by(flock_user_id: decoded_token[0]["userId"]).id rescue nil
    end
  end

  def current_user
    User.find session[:current_user_id] if session[:current_user_id]
  end

  def gmail_inbound
    render json: {message: "ok"}, status: 200
    sleep 8
    data = params["message"]["data"]
    decoded_data = JSON.parse(Base64.decode64(data))
    puts "=="*100
    puts decoded_data
    puts "=="*100
    history_id = decoded_data["historyId"]
    user_email_address = decoded_data["emailAddress"]
    user = User.find_by(gmail_address: user_email_address)
    if user
      gmail = user.get_gmail_instance
      histories = gmail.list_user_histories("me", start_history_id: history_id).history || []
      histories.each do |history|
        if history.messages
          history.messages.each do |added_message|
            message = gmail.get_user_message("me", added_message.id)
            text = ""
            last_message = {}
            selected_headers = message.payload.headers.select{|a| ["Subject", "From"].include?(a.name)}
            selected_headers.each do |header|
              text = text + header.name + " : " + header.value + "\n"
              last_message[header.name.downcase] = header.value
            end
            if message.payload.body.data
              text = text + "Body : " + message.payload.body.data.strip
            end
            user.last_message = last_message
            user.save
            user.send_to_bot_mail(last_message["from"], last_message["subject"], text)
          end
        else

        end
      end
    end
    
  end

  def login_if_not
    if !user_signed_in?
      session[:redirect_to] = request.path
      redirect_to "/connect/google"
    end
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
    when "app.install"
      # localhost:3000/flock_events?token=98ac35f0-7b3e-4f0c-97df-e43614cce558&name=app.install&userId="u:auecvebiuce2xcjb"
      user = User.find_or_create_by(flock_user_id: params["userId"]) do |u|
        u.flock_token = params["token"]
        u.email = "#{params['userId'].split(':')[1]}@flockgfw.com"
        u.password = "User1234"
      end
      user.create_token_store
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

    end
    # {"userToken"=>"98ac35f0-7b3e-4f0c-97df-e43614cce558", "token"=>"98ac35f0-7b3e-4f0c-97df-e43614cce558", "name"=>"app.install", "userId"=>"u:auecvebiuce2xcjb", "controller"=>"application", "action"=>"flock_events", "application"=>{"userToken"=>"98ac35f0-7b3e-4f0c-97df-e43614cce558", "token"=>"98ac35f0-7b3e-4f0c-97df-e43614cce558", "name"=>"app.install", "userId"=>"u:auecvebiuce2xcjb"}}

    render json: {message: "ok"}, status: 200
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
    wr.topic_name = "projects/plucky-bulwark-676/topics/gmail-inbound"
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

# require 'google/apis/oauth2_v2/representations.rb'
# require 'google/apis/oauth2_v2/service.rb'
# require 'google/apis/oauth2_v2/classes.rb'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'google/apis/calendar_v3'
require 'google/apis/gmail_v1'
require 'rmail'
class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  after_initialize :init
  validates_uniqueness_of :flock_token, message: "must be unique"
  has_one :token_store
  
  store_accessor :content, :last_message

  def init
    self.content ||= {}
    # self.content.deep_symbolize_keys!
    # @session = get_gdrive_session
  end


  Gmail = Google::Apis::GmailV1
  Drive = Google::Apis::DriveV3
  
  def file_list(query)
    drive = get_drive_instance
    page_token = nil
    limit = 1000
    begin
      result = drive.list_files(q: query,
                                page_size: [limit, 100].min,
                                page_token: page_token,
                                fields: 'files(id,name),next_page_token')

      result.files.each { |file| puts "#{file.id}, #{file.name}" }
      limit -= result.files.length
      if result.next_page_token
        page_token = result.next_page_token
      else
        page_token = nil
      end
    end while !page_token.nil? && limit > 0
  end

  def get_drive_instance
    drive = Drive::DriveService.new
    drive.authorization = get_credentials
    return drive
  end

  def get_gmail_instance
    gmail = Gmail::GmailService.new
    gmail.authorization = get_credentials
    return gmail
  end

  def get_calender_instance
    calendar = Calendar::CalendarService.new
    calendar.authorization = get_credentials
    return calendar
  end

  def schedule(summary, start, _end)
    calendar = get_calender_instance
    event = {
      summary: summary,
      start: {
        date_time: Time.parse(start).iso8601
      },
      end: {
        date_time: Time.parse(_end).iso8601
      }
    }

    event = calendar.insert_event('primary', event, send_notifications: true)
  end

  def todays_agenda
    calendar = get_calender_instance
    page_token = nil
    limit = 1000
    now = Time.now
    max = now + 24.hours
    now = now.iso8601
    max = max.iso8601
    results = []
    begin
      result = calendar.list_events('primary', max_results: [limit, 100].min, single_events: true, order_by: 'startTime', time_min: now, time_max: max, page_token: page_token, fields: 'items(id,summary,start),next_page_token')
      result.items.each do |event|
        results << event
        time = event.start.date_time || event.start.date
        puts "#{time}, #{event.summary}"
      end
      limit -= result.items.length
      if result.next_page_token
        page_token = result.next_page_token
      else
        page_token = nil
      end
    end while !page_token.nil? && limit > 0
    return results
  end

  def send_to_bot(message)
    bot_token = "a8811fb5-7a5d-4eb0-b34e-e9a8afa962a5"
    RestClient.get "https://api.flock.co/v1/chat.sendMessage", params:{token: bot_token, to: flock_user_id, text: message}
    #send as
  end

  def send_to_bot_mail(sender, subject, body, root)
    # bot_token = "a8811fb5-7a5d-4eb0-b34e-e9a8afa962a5"
    # RestClient.get "https://api.flock.co/v1/chat.sendMessage",
    # params: {sendAs:{name: sender}, token: bot_token, to: flock_user_id, text: " ", attachments:[{views: {flockml: "Subject: <strong style='font-size: 16px;'>#{subject}</strong><br/>Body: <div>#{body}</div>"}, buttons:[{name: "Reply", action: { type: "sendToAppService", url: "" } },{ name: "Add to Calender", action: {type: "sendToAppService", url: "/create_event?summary=#{subject}&start=#{Time.now + 1.hour}&end=#{Time.now + 2.hour}" }}] } ]}
    require 'uri'
    require 'net/http'

    url = URI("https://api.flock.co/v1/chat.sendMessage")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(url)
    request["content-type"] = 'application/json'
    request["cache-control"] = 'no-cache'
    request.body = "{\"sendAs\":{\"name\": \"#{sender}\"}, \"token\": \"a8811fb5-7a5d-4eb0-b34e-e9a8afa962a5\", \"to\": \"#{flock_user_id}\", \"text\": \"\", \"attachments\":[{\"views\": {\"flockml\": \"Subject: <strong style='font-size: 16px;'>#{subject}</strong><br/>Body: <div>#{body}</div>\"}, \"buttons\":[{\"name\": \"Reply\", \"id\": \"reply\", \"action\": { \"type\": \"openWidget\", \"url\": \"#{root}/replyModal?flock_user_id=#{flock_user_id}&from=#{sender}&subject=#{subject}\", \"desktopType\": \"modal\", \"mobileType\": \"modal\" } },{  \"id\": \"calender:#{subject}\", \"name\": \"Add to Calender\", \"action\": {\"type\": \"sendToAppService\"}}] } ]} "
    response = http.request(request)
    puts response.read_body
  end

# {"token": "a8811fb5-7a5d-4eb0-b34e-e9a8afa962a5", "to": "u:auecvebiuce2xcjb", "text": "", "attachments":[{"views": {"flockml": "<b>Mohit Munjani</b><br/>Subject: <strong style='font-size: 16px;'>This is subject</strong><br/>Body: <div>Body is the main body of the mail</div>"}, "buttons":[{"name": "Reply", "action": { "type": "sendToAppService", "url": "" } },{ "name": "Add to Calender", "action": {"type": "sendToAppService", "url": "" }}] } ]}
  def send_to_id(id, message, attachments)
    require 'uri'
    require 'net/http'

    url = URI("https://api.flock.co/v1/chat.sendMessage")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(url)
    request["content-type"] = 'application/json'
    request["cache-control"] = 'no-cache'
    request.body = "{\"token\": \"#{flock_token}\", \"title\": \"#{attachments[:filename]}\", \"to\": \"#{id}\", \"text\": \"#{message}\", \"attachments\":[{\"downloads\":[{\"src\": \"#{attachments[:src]}\", \"mime\": \"#{attachments[:mime]}\", \"size\": \"#{attachments[:size]}\", \"filename\": \"#{attachments[:filename]}\" }]} ] }"
    puts "===="
    puts attachments
    puts "===="
    response = http.request(request)
    puts response.read_body
    # RestClient.post "https://api.flock.co/v1/chat.sendMessage", {token: flock_token, to: id, text: message, attachments: [attachments]}
  end

  def get_credentials
    local_url = "http://localhost:3000"
    authorizer = get_authorizer
    credentials = authorizer.get_credentials("") rescue nil
    return credentials
  end
  Calendar = Google::Apis::CalendarV3
  def download(file_id, file)
      drive = get_drive_instance
      path = "public/#{file}"
      file = File.open(path, 'wb')
      file.binmode
      dest = file
      drive.get_file(file_id, download_dest: dest)

      if dest.is_a?(StringIO)
        dest.rewind
        STDOUT.write(dest.read)
      else
        puts "File downloaded to #{file}"
      end
      return file
    end

  def get_authorizer
    client_id = Google::Auth::ClientId.new("705897375925-i3uets68hada6uuf8gootln7b4tg73ak.apps.googleusercontent.com", "74phjI-_NPRTpLShTqYHKEoP")
    # token_store = Google::Auth::Stores::FileTokenStore.new(:file => "lol")
    authorizer = Google::Auth::UserAuthorizer.new(client_id, [Drive::AUTH_DRIVE, Gmail::AUTH_SCOPE, "https://www.google.com/calendar/feeds"], token_store)
  end

  def send_mail(to, subject, body)
    gmail = get_gmail_instance
    message = RMail::Message.new
    message.header['To'] = "mohmun16@gmail.com"
    message.header['Subject'] = subject
    message.body = body
    gmail.send_user_message('me', upload_source: StringIO.new(message.to_s), content_type: 'message/rfc822')
  end

  def get_history(history_id)
    gmail = get_gmail_instance
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
            puts "===="*50
            puts last_message
            puts "===="*50
          end
          if message.payload.body.data
            text = text + "Body : " + message.payload.body.data.strip
          end
          puts "===="*50
          puts last_message
          puts "===="*50
          self.last_message = last_message
          self.save
          send_to_bot_mail(last_message["from"], last_message["subject"], text, root_url)
        end
      else

      end
    end
  end

  # def upload_to_drive(local_path, file_name, remote_folder = nil, public = true)
  #   if remote_folder
  #     collection_by_title = @session.collection_by_title(remote_folder)
  #     if collection_by_title
  #       file = collection_by_title.upload_from_file(local_path,file_name)
  #     else
  #       collection = @session.root_collection.create_subcollection(remote_folder)
  #       file = collection.upload_from_file(local_path, file_name)
  #     end
  #   else
  #     file = @session.upload_from_file(local_path, file_name)
  #   end
  #   if public
  #     file.acl.push({ scope_type: 'anyone', with_key: true, role: 'reader' })
  #   end
  #   return file
  # end

  # def get_google_credentials
  #   credentials = User.initialize_google_credentials
  #   auth_url = credentials.authorization_uri
  #   credentials.access_token = self.content[:google][:access_token]
  #   # credentials.fetch_access_token!
  # end

  # def get_gdrive_session
  #   credentials = get_google_credentials
  #   GoogleDrive.login_with_oauth(credentials)
  # end

  def self.initialize_google_credentials
    credentials = Google::Auth::UserRefreshCredentials.new(
    client_id: "705897375925-i3uets68hada6uuf8gootln7b4tg73ak.apps.googleusercontent.com",
    client_secret: "74phjI-_NPRTpLShTqYHKEoP",
    scope: [
          "https://www.googleapis.com/auth/userinfo.email",
          "https://www.googleapis.com/auth/userinfo.profile",
         "https://www.googleapis.com/auth/drive",
         "https://spreadsheets.google.com/feeds/",
         "https://mail.google.com/",
         # "https://www.google.com/calendar/feeds"
         "https://www.googleapis.com/auth/calendar"
       ],
    redirect_uri: "http://localhost:3000/oauth2/callback/google/")
  end

  # def self.save_from_google_user(credentials)
  #   authservice = Google::Apis::Oauth2V2::Oauth2Service.new
  #   authservice.authorization = credentials
  #   userinfo = authservice.get_userinfo_v2(fields: "email")
  #   user = User.find_by(email: userinfo.email)
  #   if user
  #     user.content[:google][:access_token] = credentials.access_token
  #     user.save
  #   else
  #     user = User.create(email: userinfo.email, password: SecureRandom.hex, content: {google: {access_token: credentials.access_token}})
  #   end
  #   return user
  # end
end

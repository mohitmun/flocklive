# require 'google/apis/oauth2_v2/representations.rb'
# require 'google/apis/oauth2_v2/service.rb'
# require 'google/apis/oauth2_v2/classes.rb'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
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
    self.content.deep_symbolize_keys!
    # @session = get_gdrive_session
  end


  Gmail = Google::Apis::GmailV1
  def get_gmail_instance
    gmail = Gmail::GmailService.new
    gmail.authorization = get_credentials
    return gmail
  end

  def send_to_bot(message)
    bot_token = "a8811fb5-7a5d-4eb0-b34e-e9a8afa962a5"
    RestClient.get "https://api.flock.co/v1/chat.sendMessage", params:{token: bot_token, to: flock_user_id, text: message}
    #send as
  end

  def get_credentials
    local_url = "http://localhost:3000"
    authorizer = get_authorizer
    credentials = authorizer.get_credentials("") rescue nil
    return credentials
  end

  def get_authorizer
    client_id = Google::Auth::ClientId.new("705897375925-i3uets68hada6uuf8gootln7b4tg73ak.apps.googleusercontent.com", "74phjI-_NPRTpLShTqYHKEoP")
    # token_store = Google::Auth::Stores::FileTokenStore.new(:file => "lol")
    authorizer = Google::Auth::UserAuthorizer.new(client_id, [Gmail::AUTH_SCOPE, "https://www.google.com/calendar/feeds"], token_store)
  end

  def send_mail(to, subject, body)
    gmail = get_gmail_instance
    message = RMail::Message.new
    message.header['To'] = "mohmun16@gmail.com"
    message.header['Subject'] = subject
    message.body = body
    gmail.send_user_message('me', upload_source: StringIO.new(message.to_s), content_type: 'message/rfc822')
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

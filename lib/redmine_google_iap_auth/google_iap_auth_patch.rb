require "base64"
require "json"
require "jwt"
require "net/http"
require "openssl"
require "sinatra"
require "uri"

module RedmineGoogleIAPAuth
    def find_current_user
        assertion = request.env["HTTP_X_GOOG_IAP_JWT_ASSERTION"]
        Rails.logger.info("assertion #{assertion}")
        #email, _user_id = validate_assertion assertion
        user = nil

            if (emailaddress = request.headers["X-Goog-Authenticated-User-Email"].to_s.presence)
                emailaddress.sub! 'accounts.google.com:', ''

                su = User.find_by_mail(emailaddress)
                if su
                    if su.active?
                        logger.info("  IAP Login for : #{emailaddress} (id=#{su.id})") if logger
                        user = su
                    else
                        logger.info("  IAP Login failed (NOT ACTIVE) : #{emailaddress} (id=#{su.id})") if logger
                        render_error :message => 'IAP Automatic Login Failed - Login Blocked', :status => 403
                    end
                else
                    emailsplit = emailaddress.split('@')

                    user = User.new
                    user.login = emailaddress
                    user.firstname = emailsplit[0]
                    user.lastname = emailsplit[1]
                    user.mail = emailaddress
                    user.language = Setting.default_language
                    user.admin = false

                    user.register
                    user.activate

                    if user.save
                        user.reload
                        logger.info("User '#{user.login}' created from IAP login: #{emailaddress} (id=#{su.id})") if logger
                    else
                        user = nil
                        logger.error("  Failed IAP user creation for : #{emailaddress}") if logger
                        render_error :message => 'IAP Automatic User Creation Failed', :status => 403
                    end
                end
            end

            # store current ip address in user object ephemerally
            user.remote_ip = request.remote_ip if user

            user.update_last_login_on! if user

            user
    end

    def certificates
        uri = URI.parse "https://www.gstatic.com/iap/verify/public_key"
        response = Net::HTTP.get_response uri
        JSON.parse response.body
    end


    def validate_assertion assertion
        a_header = Base64.decode64 assertion.split(".")[0]
        key_id = JSON.parse(a_header)["kid"]
        certs = certificates
        cert = OpenSSL::PKey::EC.new certs[key_id]
        info = JWT.decode assertion, cert, true, algorithm: "ES256", audience: Setting.plugin_redmine_google_iap_auth['audience']
        return info[0]["email"], info[0]["sub"]
      
    rescue StandardError => e
    puts "Failed to validate assertion: #{e}"
    [nil, nil]
    end
end
require 'redmine'
require 'redmine_google_iap_auth'

Redmine::Plugin.register :redmine_google_iap_auth do
    name 'Google IAP Auth'
    author 'Changho Song'
    description ''
    version '0.0.1'
    url 'https://github.com/lunakillz/redmine_google_iap_auth'
    author_url 'https://gitlab.com/lunakillz'
    requires_redmine :version_or_higher => '4.0.0'
  
    settings :default => {}, :partial => 'settings/google_iap_auth_settings'
end

RedmineApp::Application.config.after_initialize do
    ApplicationController.prepend(RedmineGoogleIAPAuth)
end
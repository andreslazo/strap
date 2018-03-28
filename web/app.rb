require "sinatra"
require "omniauth-github"
require "octokit"
require "securerandom"
require "awesome_print" if ENV["RACK_ENV"] == "development"

GITHUB_KEY = ENV["GITHUB_KEY"]
GITHUB_SECRET = ENV["GITHUB_SECRET"]
SESSION_SECRET = ENV["SESSION_SECRET"] || SecureRandom.hex
STRAP_ISSUES_URL = ENV["STRAP_ISSUES_URL"] || \
                   "https://github.com/mikemcquaid/strap/issues/new"
STRAP_BEFORE_INSTALL = ENV["STRAP_BEFORE_INSTALL"]
CUSTOM_HOMEBREW_TAP = ENV["CUSTOM_HOMEBREW_TAP"]
CUSTOM_BREW_COMMAND = ENV["CUSTOM_BREW_COMMAND"]
PRODUCT_SELECTED = ENV["PRODUCT_SELECTED"]

set :sessions, secret: SESSION_SECRET
set :protection, except: [:frame_options]

use OmniAuth::Builder do
  options = { scope: "user:email,repo" }
  options[:provider_ignores_state] = true if ENV["RACK_ENV"] == "development"
  provider :github, GITHUB_KEY, GITHUB_SECRET, options
end

get "/auth/github/callback" do
  session[:auth] = request.env["omniauth.auth"]
  return_to = session.delete :return_to
  return_to = "/" if !return_to || return_to.empty?
  redirect to return_to
end

get "/" do
  if request.scheme == "http" && ENV["RACK_ENV"] != "development"
    redirect to "https://#{request.host}#{request.fullpath}"
  end

  before_install_list_item = nil
  if STRAP_BEFORE_INSTALL
    before_install_list_item = "<li>#{STRAP_BEFORE_INSTALL}</li>"
  end

  @title = "¡Bienvenid@ a Lemon Strap!"
  @text = <<-EOS
Lemon Strap son una serie de Scripts que le permitiran la instalación y configuración de su equipo para que esten listos para ejecutar el producto que va a desarrollar ¡Con el minimo esfuerzo 🤩!

Para comenzar, seleccione su producto:
<ol>
  #{before_install_list_item}
  <li><a href="/strap.sh"><code>simple.sh</code></a>: que contiene una instalación simple (solo las herramientas basicas) usando su usuario de GitHub (Verlo <a href="/strap.sh?text=1">aqui</a>).</li>
  <li>Ejecuta el archivo descargado en la terminal <code>bash ~/Downloads/install.sh</code>.</li>
  <li>Recuerde eliminar el archivo <code>strap.sh</code></a> (contiene sus token de github 😱) en Terminal.app con <code>rm -f ~/Downloads/install.sh</code></a></li>
  <li>En construcción: If something failed, run Lemon Strap with more debugging output in Terminal.app with <code>bash ~/Downloads/strap.sh --debug</code> and file an issue at <a href="#{STRAP_ISSUES_URL}">#{STRAP_ISSUES_URL}</a></li>
</ol>

<a href="https://github.com/mikemcquaid/strap"><img style="position: absolute; top: 0; right: 0; border: 0; width: 149px; height: 149px;" src="//aral.github.com/fork-me-on-github-retina-ribbons/right-graphite@2x.png" alt="Fork me on GitHub"></a>
EOS
  erb :root
end

get "/strap.sh" do
  auth = session[:auth]

  if !auth && GITHUB_KEY && GITHUB_SECRET
    query = request.query_string
    query = "?#{query}" if query && !query.empty?
    session[:return_to] = "#{request.path}#{query}"
    redirect to "/auth/github"
  end

  content = IO.read(File.expand_path("#{File.dirname(__FILE__)}/../bin/strap.sh"))
  content.gsub!(/^STRAP_ISSUES_URL=.*$/, "STRAP_ISSUES_URL='#{STRAP_ISSUES_URL}'")
  content.gsub!(/^# CUSTOM_HOMEBREW_TAP=.*$/, "CUSTOM_HOMEBREW_TAP='#{CUSTOM_HOMEBREW_TAP}'")
  content.gsub!(/^# CUSTOM_BREW_COMMAND=.*$/, "CUSTOM_BREW_COMMAND='#{CUSTOM_BREW_COMMAND}'")
  content.gsub!(/^# PRODUCT_SELECTED=.*$/, "PRODUCT_SELECTED='#{PRODUCT_SELECTED}'")

  content_type = params["text"] ? "text/plain" : "application/octet-stream"

  if auth
    content.gsub!(/^# STRAP_GIT_NAME=$/, "STRAP_GIT_NAME='#{auth["info"]["name"]}'")
    content.gsub!(/^# STRAP_GIT_EMAIL=$/, "STRAP_GIT_EMAIL='#{auth["info"]["email"]}'")
    content.gsub!(/^# STRAP_GITHUB_USER=$/, "STRAP_GITHUB_USER='#{auth["info"]["nickname"]}'")
    content.gsub!(/^# STRAP_GITHUB_TOKEN=$/, "STRAP_GITHUB_TOKEN='#{auth["credentials"]["token"]}'")
  end

  erb content, content_type: content_type
end

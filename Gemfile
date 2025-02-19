# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }
git_source(:gitlab) { |repo| "https://gitlab.com/#{repo}.git" }

ruby ">= 3.2.0"

gem "apexcharts"

gem "babel-transpiler"

gem "bcrypt"

gem "bootsnap", ">=1.1.0", require: false

gem "cancancan"

gem "cocoon", git: "https://github.com/vtamara/cocoon.git", branch: "new_id_with_ajax" # Formularios anidados (algunos con ajax)

gem "coffee-rails" # CoffeeScript para recuersos .js.coffee y vistas

gem "devise" # Autenticación

gem "devise-i18n"

gem "execjs"

gem "jbuilder"

gem "jsbundling-rails"

gem "kt-paperclip", # Anexos
  git: "https://github.com/kreeti/kt-paperclip.git"

gem "libxml-ruby"

gem "net-smtp"

gem "nokogiri", ">=1.11.1"

gem "odf-report" # Genera ODT

gem "parslet"

gem "pg" # Postgresql

gem "puma"

gem "prawn" # Generación de PDF

gem "prawnto_2", require: "prawnto"

gem "prawn-table"

gem "rack", "~> 2"

gem "rails", "~> 7.2"

gem "rails-i18n"

gem "redcarpet"

gem "rspreadsheet"

gem "rubyzip", ">= 2.0.0"

gem "sassc-rails" # CSS

gem "simple_form" # Formularios simples

gem "sprockets-rails"

gem "stimulus-rails"

gem "turbo-rails", "~> 1.0"

gem "twitter_cldr" # ICU con CLDR

gem "tzinfo" # Zonas horarias

gem "will_paginate" # Pagina listados

#####
# Motores sobre msip de los que se sobrecargan vistas (deben ponerse en orden
# de apilamiento lógico y no alfabético como las gemas anteriores)

gem "msip", # Motor generico
  git: "https://gitlab.com/pasosdeJesus/msip.git",
  branch: "main"
# path: "../msip"

gem "mr519_gen", # Motor de gestion de formularios y encuestas
  git: "https://gitlab.com/pasosdeJesus/mr519_gen.git",
  branch: "main"
# path: "../mr519_gen"

gem "heb412_gen", # Motor de nube y llenado de plantillas
  git: "https://gitlab.com/pasosdeJesus/heb412_gen.git",
  branch: "main"
# path: "../heb412_gen"

gem "sivel2_gen", # Motor de casos de VPS
  git: "https://gitlab.com/pasosdeJesus/sivel2_gen.git",
  branch: "main"
# path: "../heb412_gen"

gem "cor1440_gen", # Motor de proyectos y actividades
  git: "https://gitlab.com/pasosdeJesus/cor1440_gen.git",
  branch: "main"
# path: "../cor1440_gen"

group :development do
  gem "thor" # Requerido por rake

  gem "web-console" # ConSola irb en páginas
end

group :development, :test do
  gem "brakeman"

  gem "bundler-audit"

  gem "code-scanning-rubocop"

  gem "colorize"

  gem "debug", ">= 1.0.0", platforms: [:mri, :mingw, :x64_mingw]

  gem "dotenv-rails"

  gem "rails-erd"

  gem "rubocop-minitest"

  gem "rubocop-rails"

  gem "rubocop-shopify"
end

group :test do
  gem "cuprite"

  gem "connection_pool"

  gem "minitest"

  gem "minitest-reporters"

  gem "rails-controller-testing"

  gem "simplecov"
end

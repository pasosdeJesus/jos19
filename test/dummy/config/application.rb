# frozen_string_literal: true

require_relative "boot"

require "rails"
# Elige los marcos de trabajo que necesitas:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"


Bundler.require(*Rails.groups)
require "jos19"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f


    config.time_zone = "America/Bogota"

    config.i18n.default_locale = :es

    config.colorize_logging = true

    config.active_record.schema_format = :sql

    puts "CONFIG_HOSTS=" + ENV.fetch("CONFIG_HOSTS", "defensor.info").to_s
    config.hosts.concat(
      ENV.fetch("CONFIG_HOSTS", "defensor.info").downcase.split(";"),
    )

    # config.web_console.whitelisted_ips = ['186.154.35.237']

    # msip
    config.x.formato_fecha = ENV.fetch("MSIP_FORMATO_FECHA", "dd/M/yyyy")
    # En el momento soporta 3 formatos: yyyy-mm-dd, dd-mm-yyyy y dd/M/yyyy

    # heb412
    config.x.heb412_ruta = Pathname(ENV.fetch(
      "HEB412_RUTA", Rails.public_path.join("heb412").to_s
    ))

    # cor1440
    config.x.cor1440_permisos_por_oficina =
      (ENV["COR1440_PERMISOS_POR_OFICINA"] && 
       ENV["COR1440_PERMISOS_POR_OFICINA"] != "")

    config.x.cor1440_pf_comunes =
      ENV.fetch("COR1440_PF_COMUNES", 0).to_i

    config.x.cor1440_pf_todaact =
      ENV.fetch("COR1440_PF_TODAACT", 0).to_i

    config.x.cor1440_pf_calidad =
      ENV.fetch("COR1440_PF_CALIDAD", 0).to_i

    config.x.jos19_etiquetaunificadas = "PERSONAS UNIFICADAS"

  end
end

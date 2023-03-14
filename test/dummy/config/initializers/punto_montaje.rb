# frozen_string_literal: true

Dummy::Application.config.relative_url_root = ENV.fetch(
  "RUTA_RELATIVA", "/jos19"
)
Dummy::Application.config.assets.prefix = ENV.fetch(
  'RUTA_RELATIVA', '/jos19') == '/' ?
 '/assets' : (ENV.fetch('RUTA_RELATIVA', '/jos19') + '/assets')

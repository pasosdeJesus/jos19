# frozen_string_literal: true

require "jos19/version"

Msip.setup do |config|
  config.ruta_anexos = "#{Rails.root}/archivos/anexos"
  config.ruta_volcados = "#{Rails.root}/archivos/bd"
  config.titulo = "Jos19 " + Jos19::VERSION

  config.descripcion = "Seguimiento con cor1440 a casos de sivel2_gen"
  config.codigofuente = "https://gitlab.com/pasosdeJesus/cor1440_gen"
  config.urlcontribuyentes = "https://gitlab.com/pasosdeJesus/cor1440_gen/graphs/contributors"
  config.urlcreditos = "https://gitlab.com/pasosdeJesus/cor1440_gen/blob/master/CREDITOS.md"
  config.agradecimientoDios = "
<blockquote>
<p>
Mira que te mando que te esfuerces y seas valiente;
no temas ni desmayes porque Jehová tu Dios
estará contigo dondequiera que vayas.
</p>
<p>Josué 1:9</p>
</blockquote>".html_safe
end

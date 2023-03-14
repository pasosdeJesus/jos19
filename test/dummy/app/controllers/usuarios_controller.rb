require "msip/concerns/controllers/usuarios_controller"

class UsuariosController < Msip::ModelosController
  include Msip::Concerns::Controllers::UsuariosController

  def index
    super
  end
end

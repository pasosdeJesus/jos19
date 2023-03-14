# frozen_string_literal: true

class Ability < Cor1440Gen::Ability
  # Autorizacion con CanCanCan
  def initialize_jos19(habilidades, usuario = nil)
    Sivel2Gen::Ability.initialize_sivel2_gen(habilidades, usuario)
    Cor1440Gen::Ability.initialize_cor1440_gen(habilidades, usuario)
  end

  def initialize(usuario = nil)
    initialize_jos19(self, usuario)
  end
end

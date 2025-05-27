# frozen_string_literal: true

require "jos19/concerns/controllers/personas_controller"

module Msip
  class PersonasController < Heb412Gen::ModelosController
    before_action :set_persona, only: [:show, :edit, :update, :destroy]
    load_and_authorize_resource class: Msip::Persona

    include Jos19::Concerns::Controllers::PersonasController
  end
end

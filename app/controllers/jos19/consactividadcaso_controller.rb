# frozen_string_literal: true

require "jos19/concerns/controllers/consactividadcaso_controller"

module Jos19
  class ConsactividadcasoController < Heb412Gen::ModelosController
    load_and_authorize_resource class: Jos19::Consactividadcaso

    include Jos19::Concerns::Controllers::ConsactividadcasoController
  end
end

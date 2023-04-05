# frozen_string_literal: true

require "cor1440_gen/concerns/controllers/personas_controller"
require "sivel2_gen/concerns/controllers/personas_controller"

module Jos19
  module Concerns
    module Controllers
      module PersonasController
        extend ActiveSupport::Concern

        included do
          include Sivel2Gen::Concerns::Controllers::PersonasController
          include Cor1440Gen::Concerns::Controllers::PersonasController

          def atributos_show_jos19
            atributos_show_cor1440_gen + [
              :caso_ids,
            ]
          end

          def atributos_show
            atributos_show_jos19
          end

          def atributos_form_jos19
            atributos_form_cor1440_gen - 
              [:caso_ids, :familiar_ids, :familiarvictima_ids]
          end

          def atributos_form
            atributos_form_jos19
          end


        end  # included

        class_methods do
        end

      end
    end
  end
end

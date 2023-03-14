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
        end  # included

        class_methods do
        end
      end
    end
  end
end

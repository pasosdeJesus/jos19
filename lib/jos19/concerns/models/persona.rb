# frozen_string_literal: true

require "cor1440_gen/concerns/models/persona"
require "sivel2_gen/concerns/models/persona"

module Jos19
  module Concerns
    module Models
      module Persona
        extend ActiveSupport::Concern

        included do
          include Sivel2Gen::Concerns::Models::Persona
          include Cor1440Gen::Concerns::Models::Persona
        end # included

        class_methods do
        end
      end
    end
  end
end

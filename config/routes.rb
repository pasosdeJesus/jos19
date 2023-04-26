# frozen_string_literal: true

Jos19::Engine.routes.draw do

  post '/personas/unificar' => 'msip/personas#unificar',
    as: :personas_unificar
  get '/personas/unificar' => 'msip/personas#unificar',
    as: :personas_unificar_get

  namespace :admin do
    ab=::Ability.new
    ab.tablasbasicas.each do |t|
      if (t[0] == "Jos19") 
        c = t[1].pluralize
        resources c.to_sym, 
          path_names: { new: 'nueva', edit: 'edita' }
      end
    end
  end

end

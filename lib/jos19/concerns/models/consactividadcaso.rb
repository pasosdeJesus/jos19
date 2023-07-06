module Jos19
  module Concerns
    module Models
      module Consactividadcaso 
        extend ActiveSupport::Concern

        included do
          include Msip::Modelo

          belongs_to :actividad, 
            class_name: 'Cor1440Gen::Actividad', foreign_key: 'actividad_id', 
            optional: false

          belongs_to :caso, 
            class_name: 'Sivel2Gen::Caso', foreign_key: 'caso_id', 
            optional: false

          belongs_to :persona,
            class_name: 'Msip::Persona', foreign_key: 'persona_id', 
            optional: false

          belongs_to :victima,
            class_name: 'Sivel2Gen::Victima', foreign_key: 'victima_id', 
            optional: false

          scope :filtro_caso_id, lambda { |f|
            where(caso_id: f)
          }

          scope :filtro_actividad_id, lambda { |f|
            where(actividad_id: f)
          }

          scope :filtro_persona_nombres, lambda { |d|
            where("persona_nombres ILIKE '%" + 
                  ActiveRecord::Base.connection.quote_string(d) + "%'")
          }

          scope :filtro_persona_apellidos, lambda { |d|
            where("persona_apellidos ILIKE '%" + 
                  ActiveRecord::Base.connection.quote_string(d) + "%'")
          }
          scope :filtro_actividad_fechaini, lambda { |f|
            where('actividad_fecha >= ?', f)
          }

          scope :filtro_actividad_fechafin, lambda { |f|
            where('actividad_fecha <= ?', f)
          }

          scope :filtro_actividad_proyectofinanciero, lambda { |pf|
            where('actividad_id IN (SELECT actividad_id ' +
                  'FROM  cor1440_gen_actividad_proyectofinanciero WHERE ' +
                  'proyectofinanciero_id=?)', pf)
          }

          scope :filtro_persona_tipodocumento, lambda { |f|
            where(persona_tipodocumento: f)
          }


          def presenta(atr)
            puts atr
            m =/^edad_([^_]*)_r_(.*)/.match(atr.to_s)
            if (m && ((m[1] == 'mujer' && self.persona.sexo == Msip::Persona::convencion_sexo[:sexo_femenino].to_s) ||
                (m[1] == 'hombre' && self.persona.sexo == Msip::Persona::convencion_sexo[:sexo_masculino].to_s) ||
                (m[1] == 'sin' && self.persona.sexo == Msip::Persona::convencion_sexo[:sexo_sininformacion].to_s) || 
                (m[1] == 'intersexual' && self.persona.sexo == Msip::Persona::convencion_sexo[:sexo_intersexual].to_s))) then
              edad = Sivel2Gen::RangoedadHelper::edad_de_fechanac_fecha(
                self.persona.anionac,
                self.persona.mesnac,
                self.persona.dianac,
                self.actividad.fecha.year,
                self.actividad.fecha.month,
                self.actividad.fecha.day
              )
              if (m[2] == '0_5' && 0 <= edad && edad <= 5) ||
                  (m[2] == '6_12' && 6 <= edad && edad <= 12) ||
                  (m[2] == '13_17' && 13 <= edad && edad <= 17) ||
                  (m[2] == '18_26' && 18 <= edad && edad <= 26) ||
                  (m[2] == '27_59' && 27 <= edad && edad <= 59) ||
                  (m[2] == '60_' && 60 <= edad) ||
                  (m[2] == 'SIN' && edad == -1) then
                1
              else
                ''
              end
            else
              case atr.to_sym
              when :actividad_nombre
                self.actividad.nombre
              when :actividad_id
                self.actividad_id
              when :actividad_fecha_mes
                self.actividad.fecha ? self.actividad.fecha.month : ''
              when :actividad_proyectofinanciero
                self.actividad.proyectofinanciero ? 
                  self.actividad.proyectofinanciero.map(&:nombre).join('; ') : ''

              when :persona_edad_en_atencion
                Sivel2Gen::RangoedadHelper::edad_de_fechanac_fecha(
                  self.persona.anionac,
                  self.persona.mesnac,
                  self.persona.dianac,
                  self.actividad.fecha.year,
                  self.actividad.fecha.month,
                  self.actividad.fecha.day
                )
              when :persona_etnia
                self.victima.etnia ? self.victima.etnia.nombre : ''
              when :persona_id
                self.persona.id
              when :persona_numerodocumento
                self.persona.numerodocumento
              when :persona_sexo
                Msip::Persona.find(self.persona_id).sexo
              when :persona_tipodocumento
                self.persona.tdocumento ? self.persona.tdocumento.sigla : ''
              when :victima_maternidad
                self.victimasjr.maternidad ? self.victimasjr.maternidad.nombre :
                  ''
              else
                presenta_gen(atr)
              end
            end
          end

        end

        module ClassMethods

          def consulta
            "SELECT row_number() over () AS id,
        caso.id AS caso_id, 
        actividad_id,
        victima.id AS victima_id,
        CASE WHEN casosjr.contacto_id=persona.id THEN 1 ELSE 0 END 
          AS es_contacto,
        actividad.fecha AS actividad_fecha,
        (SELECT nombre FROM msip_oficina 
          WHERE msip_oficina.id=actividad.oficina_id LIMIT 1) 
          AS actividad_oficina,
        (SELECT nusuario FROM usuario 
          WHERE usuario.id=actividad.usuario_id LIMIT 1)
          AS actividad_responsable,
        ARRAY_TO_STRING(ARRAY(SELECT nombre FROM cor1440_gen_proyectofinanciero
          WHERE cor1440_gen_proyectofinanciero.id IN
          (SELECT proyectofinanciero_id 
            FROM cor1440_gen_actividad_proyectofinanciero AS apf 
            WHERE apf.actividad_id=actividad.id)), ',') 
          AS actividad_convenios,
        persona.id AS persona_id,
        persona.nombres AS persona_nombres,
        persona.apellidos AS persona_apellidos,
        persona.tdocumento_id AS persona_tipodocumento,
        caso.memo AS caso_memo,
        casosjr.fecharec AS caso_fecharec
        FROM public.cor1440_gen_asistencia AS asi
        INNER JOIN msip_persona AS persona ON persona.id=asi.persona_id 
        INNER JOIN cor1440_gen_actividad AS actividad 
          ON actividad_id=actividad.id
        INNER JOIN msip_oficina AS oficinaac 
          ON oficinaac.id=actividad.oficina_id
        INNER JOIN sivel2_gen_victima AS victima 
          ON victima.persona_id=persona.id
        INNER JOIN sivel2_gen_caso AS caso ON victima.caso_id=caso.id
        INNER JOIN sivel2_sjr_casosjr AS casosjr ON caso.id=casosjr.caso_id
            "
          end

          def crea_consulta(ordenar_por = nil)
            if ARGV.include?("db:migrate")
              return
            end
            if ActiveRecord::Base.connection.data_source_exists?(
                'jos19_consactividadcaso')
              ActiveRecord::Base.connection.execute(
                "DROP MATERIALIZED VIEW IF EXISTS jos19_consactividadcaso")
            end
            if ordenar_por
              w += ' ORDER BY ' + self.interpreta_ordenar_por(ordenar_por)
            end
            c = "CREATE 
              MATERIALIZED VIEW jos19_consactividadcaso AS
              #{self.consulta}
              #{w} ;"
            ActiveRecord::Base.connection.execute(c)
          end #def crea_consulta


          def refresca_consulta(ordenar_por = nil)
            if !ActiveRecord::Base.connection.data_source_exists?(
                'jos19_consactividadcaso')
              crea_consulta(ordenar_por = nil)
            else
              ActiveRecord::Base.connection.execute(
                "REFRESH MATERIALIZED VIEW jos19_consactividadcaso")
            end
          end


          def interpreta_ordenar_por(campo)
            critord = ""
            case campo.to_s
            when /^fechadesc/
              critord = "conscaso.fecha desc"
            when /^fecha/
              critord = "conscaso.fecha asc"
            when /^ubicaciondesc/
              critord = "conscaso.ubicaciones desc"
            when /^ubicacion/
              critord = "conscaso.ubicaciones asc"
            when /^codigodesc/
              critord = "conscaso.caso_id desc"
            when /^codigo/
              critord = "conscaso.caso_id asc"
            else
              raise(ArgumentError, "Ordenamiento invalido: #{ campo.inspect }")
            end
            critord += ", conscaso.caso_id"
            return critord
          end


        end # module ClassMethods

      end
    end
  end
end
